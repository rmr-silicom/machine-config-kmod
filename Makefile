.PHONY: clean apply transpile install clean-fakeroot $(FCOS_VERSIONS)

PWD=$(shell pwd)
FAKEROOT=$(PWD)/fakeroot

export DESTDIR=$(FAKEROOT)/usr/local
export CONFDIR=$(FAKEROOT)/etc
export GODEBUG=x509ignoreCN=0

INSTALL_ON_MASTER=no
FILES=$(PWD)/files

KMODVER := eea9cbc
KVER_RHEL82 = 4.18.0-193.el8.x86_64
KVER_RHEL83 = 4.18.0-305.3.1.el8.x86_64

RHEL82_RPM := https://vault.centos.org/8.2.2004/BaseOS/x86_64/os/Packages/kernel-devel-${KVER_RHEL82}.rpm
RHEL83_RPM := http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/kernel-devel-${KVER_RHEL83}.rpm

BUILD_ARGS_RHEL82 = --build-arg CENTOS_VER=docker.io/centos:8.2.2004 --build-arg RPM_URL=$(RHEL82_RPM) --build-arg KMODVER=$(KMODVER) --build-arg KVER=$(KVER_RHEL82)
BUILD_ARGS_RHEL83 = --build-arg CENTOS_VER=docker.io/centos:8.3.2011 --build-arg RPM_URL=$(RHEL83_RPM) --build-arg KMODVER=$(KMODVER) --build-arg KVER=$(KVER_RHEL83)

FCOS_VERSIONS?=5.10.12-200.fc33.x86_64
FCOS_VERSIONS_BUILDS := $(foreach target,$(FCOS_VERSIONS),$(addprefix build-,$(target)))
FCOS_VERSIONS_PUSHES := $(foreach target,$(FCOS_VERSIONS),$(addprefix push-,$(target)))

BUILDTOOL?=podman
IMAGE_NAME=dfl-drivers
IMAGE_NAME_DRIVER_CONTAINER=dfl-kmod-drivercontainer
REPOS?=quay.io/ryan_raasch
OUTPUT_YAML=99-kvc-kmod.yaml

all: transpile

$(FCOS_VERSIONS_BUILDS):

#
# From a 'fakeroot' folder, generate an yaml file to be applied to oc
#
filetranspiler:
	git clone https://github.com/ashcrow/filetranspiler.git
	$(BUILDTOOL) build filetranspiler -t filetranspiler:latest -f filetranspiler/Dockerfile

transpile: filetranspiler install kmods-via-containers
ifeq ($(INSTALL_ON_MASTER),yes)
	cat $(FILES)/mc-base.yaml > $(PWD)/$(OUTPUT_YAML)
else
	sed "/machineconfiguration.openshift.io\/role: master/d" $(FILES)/mc-base.yaml > $(PWD)/$(OUTPUT_YAML)
endif
	podman run --rm -ti --volume $(PWD):/srv:z localhost/filetranspiler:latest -i /srv/files/baseconfig.ign -f /srv/fakeroot --format=yaml --dereference-symlinks | sed 's/^/     /' >> $(PWD)/$(OUTPUT_YAML)

# The generic framework for KVC
# We provide a shell library to overwrite the functionality
kmods-via-containers:
	git clone https://github.com/kmods-via-containers/kmods-via-containers.git

kvc-simple-kmod:
	git clone https://github.com/kmods-via-containers/kvc-simple-kmod.git

install: clean-fakeroot kmods-via-containers
	make -C kmods-via-containers
	install -v -m 755 -d $(CONFDIR)/modprobe.d
	install -v -m 755 -d $(CONFDIR)/modules-load.d/
	install -v -m 644 $(FILES)/dfl-kmod-wrapper.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(FILES)/dfl-kmod-lib.sh $(DESTDIR)/lib/kvc/
	install -v -m 644 $(FILES)/dfl-kmod.conf $(CONFDIR)/kvc/
	sed -i "s/^KMOD_REPOS=.*$$/KMOD_REPOS=$(subst /,\\/,$(REPOS))/g" $(CONFDIR)/kvc/dfl-kmod.conf
	install -v -m 644 $(PWD)/Dockerfile.centos $(CONFDIR)/kvc/
	install -v -m 644 $(FILES)/blacklist/blacklist-spi.conf $(CONFDIR)/modprobe.d/
	install -v -m 644 $(FILES)/blacklist/blacklist-regmap.conf $(CONFDIR)/modprobe.d/
	install -v -m 644 $(FILES)/blacklist/blacklist-intel.conf $(CONFDIR)/modprobe.d/

install-debug: kmods-via-containers kvc-simple-kmod clean-fakeroot install
	make -C kvc-simple-kmod
	install -v -m 755 -d $(CONFDIR)/containers/registries.conf.d
	install -v -m 755 -d $(CONFDIR)/containers/registries
	install -v -m 644 $(FILES)/001-silicom.conf $(CONFDIR)/containers/registries.conf.d/
	install -v -m 644 $(FILES)/registries.conf $(CONFDIR)/containers/registries/

clean-fakeroot:
	- [ -e $(FAKEROOT) ] && rm -rf $(FAKEROOT)

rhel82:
	$(BUILDTOOL) build . -f Dockerfile.centos $(BUILD_ARGS_RHEL82) -t $(REPOS)/$(IMAGE_NAME):$(KMODVER)-$(KVER_RHEL82)

rhel83:
	$(BUILDTOOL) build . -f Dockerfile.centos $(BUILD_ARGS_RHEL83) -t $(REPOS)/$(IMAGE_NAME):$(KMODVER)-$(KVER_RHEL83)

drivercontainer-8.2:
	$(BUILDTOOL) build . -f Dockerfile.drivercontainer $(BUILD_ARGS_RHEL82) -t $(REPOS)/$(IMAGE_NAME_DRIVER_CONTAINER):$(KMODVER)-$(KVER_RHEL82)

drivercontainer-8.3:
	$(BUILDTOOL) build . -f Dockerfile.drivercontainer $(BUILD_ARGS_RHEL83) -t $(REPOS)/$(IMAGE_NAME_DRIVER_CONTAINER):$(KMODVER)-$(KVER_RHEL83)

build-drivercontainers: $(FCOS_VERSIONS_BUILDS)
$(FCOS_VERSIONS_BUILDS):
	$(BUILDTOOL) build . -f Dockerfile.fedora33 --build-arg KVER=$(subst build-,,$@) -t $(REPOS)/$(IMAGE_NAME):$(subst build-,,$@)

push-rhel82:
	$(BUILDTOOL) push $(REPOS)/$(IMAGE_NAME):$(KMODVER)-$(KVER_RHEL82)

push-rhel83:
	$(BUILDTOOL) push $(REPOS)/$(IMAGE_NAME):$(KMODVER)-$(KVER_RHEL83)

push-drivercontainers:
	$(BUILDTOOL) push $(REPOS)/$(IMAGE_NAME_DRIVER_CONTAINER):$(KMODVER)-$(KVER_RHEL82)
	$(BUILDTOOL) push $(REPOS)/$(IMAGE_NAME_DRIVER_CONTAINER):$(KMODVER)-$(KVER_RHEL83)

clean:
	rm -rf filetranspiler kmods-via-containers fakeroot $(OUTPUT_YAML) kvc-simple-kmod

apply:
	oc apply -f $(OUTPUT_YAML)

delete:
	oc delete -f $(OUTPUT_YAML)
