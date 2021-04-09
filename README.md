Based on FCOS 33/Fedora 33, RHCOS 8.2, RHCOS 8.3 runtime for drivercontainer is ubi8.

This repository contains the kvc pattern, kmods via containers.
* https://github.com/kmods-via-containers/kmods-via-containers

## TODO:
* Convert the MachineConfig to MachineConfigPool so the labels/annotations created by NFD will be used.

## Default Makefile values
* FCOS_VERSIONS = 5.10.12-200.fc33.x86_64
* BUILDTOOL = podman
* REPOS = quay.io/ryan_raasch

## MachineConfig yaml
Remove master/role from MachineConfig.

```REPOS=docker.io/kvc INSTALL_ON_MASTER=no make```

example: docker.io/kvc/dfl-kmod:eea9cbc-4.18.0-193.el8.x86_64

Results in a MachineConfig : 99-kvc-kmod.yaml

Finally (once KUBECONFIG is defined, this uses oc):

```make apply```

```make delete```

## drivercontainer

``make all-drivercontainers``
``make rhel82``
``make rhel83``

Override the Makefile settings for the drivercontainer

example: docker.io/kvc/dfl-kmod:eea9cbc-4.18.0-193.el8.x86_64

``BUILDTOOL=docker REPOS=docker.io/kvc make push-rhel82``
