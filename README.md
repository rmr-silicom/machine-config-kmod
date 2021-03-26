Based on FCOS 33/Fedora 33, runtime for drivercontainer is ubi8.

This repository contains the kvc pattern, kmods via containers.
* https://github.com/kmods-via-containers/kmods-via-containers

TODO:
* Convert the MachineConfig to MachineConfigPool so the labels/annotations created by NFD will be used.

== MachineConfig
Change where daemonset for MachineConfig to be installed.

edit file: files/mc-base.yaml
change/remove:
    node-role.kubernetes.io/master: ""
    node-role.kubernetes.io/worker: ""

The MachineConfig will be created as such

``REPOS=docker.io/kvc make``

example: docker.io/kvc/dfl-kmod-eea9cbc:5.10.12-200.fc33.x86_64

Results in a MachineConfig : 99-silicom-kmod.yaml

Make the drivercontainer

``make all-drivercontainers``

Override the Makefile settings for the drivercontainer

example: docker.io/kvc/dfl-kmod-eea9cbc:5.10.12-200.fc33.x86_64

``BUILDTOOL=docker REPOS=docker.io/kvc fcos_versions=5.10.12-200.fc33.x86_64 make -n all-drivercontainers``
