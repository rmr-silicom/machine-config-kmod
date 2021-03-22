.PHONY: clean apply transpile install clean-fakeroot

pwd=$(shell pwd)
include $(pwd)/files/dfl-kmod.conf
fakeroot=$(pwd)/fakeroot
files=$(pwd)/files
export DESTDIR=$(fakeroot)/usr/local
export CONFDIR=$(fakeroot)/etc

buildtool=podman

all: transpile

#
# From a 'fakeroot' folder, generate an yaml file to be applied to oc
#
filetranspiler:
	git clone https://github.com/ashcrow/filetranspiler.git
	$(buildtool) build filetranspiler -t filetranspiler:latest -f filetranspiler/Dockerfile

transpile: filetranspiler install kmods-via-containers
	cat $(files)/mc-base.yaml > $(pwd)/99-silicom-kmod.yaml
	podman run --rm -ti --volume $(pwd):/srv:z localhost/filetranspiler:latest -i /srv/files/baseconfig.ign -f /srv/fakeroot --format=yaml --dereference-symlinks | sed 's/^/     /' >> $(pwd)/99-silicom-kmod.yaml

# The generic framework for KVC
# We provide a shell library to overwrite the functionality
kmods-via-containers:
	git clone https://github.com/kmods-via-containers/kmods-via-containers.git

kvc-simple-kmod:
	git clone https://github.com/kmods-via-containers/kvc-simple-kmod.git

install: kmods-via-containers kvc-simple-kmod clean-fakeroot
	make -C kmods-via-containers
	make -C kvc-simple-kmod
	install -v -m 755 -d $(CONFDIR)/etc/containers/registries.conf.d
	install -v -m 755 -d $(CONFDIR)/etc/containers/registries
	install -v -m 644 $(files)/dfl-kmod-wrapper.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(files)/001-silicom.conf $(CONFDIR)/etc/containers/registries.conf.d/
	install -v -m 644 $(files)/registries.conf $(CONFDIR)/etc/containers/registries/
	install -v -m 644 $(files)/dfl-kmod-lib.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(files)/dfl-kmod.conf $(CONFDIR)/kvc/
	ln -sf ../lib/kvc/dfl-kmod-wrapper.sh $(DESTDIR)/bin/dflkut

clean-fakeroot:
	- [ -e $(fakeroot) ] && rm -rf $(fakeroot)

drivercontainer:
	$(buildtool) build . -f Dockerfile.fedora33 -t $(IMAGE)

# Insecure registries
# https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html-single/images/index
#
push:
	GODEBUG=x509ignoreCN=0 $(buildtool) push $(IMAGE)

clean:
	rm -rf filetranspiler kmods-via-containers fakeroot 99-silicom-kmod.yaml kvc-simple-kmod

apply:
	KUBECONFIG=/disks/clustermgr/ansible/okd/install_dir/auth/kubeconfig oc apply -f 99-silicom-kmod.yaml

delete:
	KUBECONFIG=/disks/clustermgr/ansible/okd/install_dir/auth/kubeconfig oc delete -f 99-silicom-kmod.yaml
