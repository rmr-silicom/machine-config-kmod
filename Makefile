.PHONY: clean apply transpile install clean-fakeroot $(FCOS_VERSIONS)

PWD=$(shell pwd)
FAKEROOT=$(PWD)/fakeroot

export DESTDIR=$(FAKEROOT)/usr/local
export CONFDIR=$(FAKEROOT)/etc
export GODEBUG=x509ignoreCN=0

FILES=$(PWD)/files
FCOS_VERSIONS?=5.10.12-200.fc33.x86_64
BUILDTOOL?=podman
KMOD_SOFTWARE_VERSION=eea9cbc
IMAGE_NAME=dfl-kmod
REPOS?=quay.io/ryan_raasch
OUTPUT_YAML=99-kvc-kmod.yaml

all: transpile

#
# From a 'fakeroot' folder, generate an yaml file to be applied to oc
#
filetranspiler:
	git clone https://github.com/ashcrow/filetranspiler.git
	$(BUILDTOOL) build filetranspiler -t filetranspiler:latest -f filetranspiler/Dockerfile

transpile: filetranspiler install kmods-via-containers
ifdef NOT_MASTER
	sed "/node-role.kubernetes.io\/master/d" $(FILES)/mc-base.yaml > $(PWD)/$(OUTPUT_YAML)
else
	cat $(FILES)/mc-base.yaml > $(PWD)/$(OUTPUT_YAML)
endif
	podman run --rm -ti --volume $(PWD):/srv:z localhost/filetranspiler:latest -i /srv/files/baseconfig.ign -f /srv/fakeroot --format=yaml --dereference-symlinks | sed 's/^/     /' >> $(PWD)/$(OUTPUT_YAML)

# The generic framework for KVC
# We provide a shell library to overwrite the functionality
kmods-via-containers:
	git clone https://github.com/kmods-via-containers/kmods-via-containers.git

kvc-simple-kmod:
	git clone https://github.com/kmods-via-containers/kvc-simple-kmod.git

install: clean-fakeroot
	make -C kmods-via-containers
	sed "s/^KMOD_REPOS=.*$$/KMOD_REPOS=$(subst /,\\/,$(REPOS))/g" $(FILES)/dfl-kmod.conf > $(FILES)/dfl-kmod.conf.tmp
	install -v -m 644 $(FILES)/dfl-kmod-wrapper.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(FILES)/dfl-kmod-lib.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(FILES)/dfl-kmod.conf.tmp $(CONFDIR)/kvc/dfl-kmod.conf
	install -v -m 644 $(PWD)/Dockerfile.fedora33 $(CONFDIR)/kvc/

install-debug: kmods-via-containers kvc-simple-kmod clean-fakeroot install
	make -C kvc-simple-kmod
	install -v -m 755 -d $(CONFDIR)/etc/containers/registries.conf.d
	install -v -m 755 -d $(CONFDIR)/etc/containers/registries
	install -v -m 644 $(FILES)/001-silicom.conf $(CONFDIR)/etc/containers/registries.conf.d/
	install -v -m 644 $(FILES)/registries.conf $(CONFDIR)/etc/containers/registries/

clean-fakeroot:
	- [ -e $(FAKEROOT) ] && rm -rf $(FAKEROOT)

all-drivercontainers: $(FCOS_VERSIONS)
$(FCOS_VERSIONS):
	$(BUILDTOOL) build . -f Dockerfile.fedora33 --build-arg KVER=$@ -t $(REPOS)/$(IMAGE_NAME)-$(KMOD_SOFTWARE_VERSION):$@

# Insecure registries
# https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html-single/images/index
#
push:
	$(buildtool) push $(REPOS)/$(IMAGE_NAME)-$(KMOD_SOFTWARE_VERSION):$@

clean:
	rm -rf filetranspiler kmods-via-containers fakeroot $(OUTPUT_YAML) kvc-simple-kmod

apply:
	KUBECONFIG=/disks/clustermgr/ansible/okd/install_dir/auth/kubeconfig oc apply -f $(OUTPUT_YAML)

delete:
	KUBECONFIG=/disks/clustermgr/ansible/okd/install_dir/auth/kubeconfig oc delete -f $(OUTPUT_YAML)
