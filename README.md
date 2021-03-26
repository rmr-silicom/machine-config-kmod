Based on FCOS 33/Fedora 33, runtime for drivercontainer is ubi8.

This repository contains the kvc pattern, kmods via containers.
* https://github.com/kmods-via-containers/kmods-via-containers

## TODO:
* Convert the MachineConfig to MachineConfigPool so the labels/annotations created by NFD will be used.

## Default Makefile values
FCOS_VERSIONS?=5.10.12-200.fc33.x86_64
BUILDTOOL?=podman
KMOD_SOFTWARE_VERSION=eea9cbc
IMAGE_NAME=dfl-kmod
REPOS?=quay.io/ryan_raasch
OUTPUT_YAML=99-kvc-kmod.yaml

## MachineConfig yaml
Remove master/role from MachineConfig.

```REPOS=docker.io/kvc NOT_MASTER=true make```

example: docker.io/kvc/dfl-kmod-eea9cbc:5.10.12-200.fc33.x86_64

Results in a MachineConfig : 99-kvc-kmod.yaml

Finally (once KUBECONFIG is defined, this uses oc):

```make apply```

```make delete```

## drivercontainer

``make all-drivercontainers``

Override the Makefile settings for the drivercontainer

example: docker.io/kvc/dfl-kmod-eea9cbc:5.10.12-200.fc33.x86_64

``BUILDTOOL=docker REPOS=docker.io/kvc FCOS_VERSIONS=5.10.12-200.fc33.x86_64 make all-drivercontainers``
``BUILDTOOL=docker REPOS=docker.io/kvc make push``
