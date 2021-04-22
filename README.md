Based on FCOS 33/Fedora 33, RHCOS 8.2, RHCOS 8.3 runtime for drivercontainer is ubi8.

This repository contains the kvc pattern, kmods via containers.
* https://github.com/kmods-via-containers/kmods-via-containers

## Apply nfd daemonset to tag the nodes correctly.
oc apply -f https://raw.githubusercontent.com/rmr-silicom/clustermgr/main/ansible/files/nfd-daemonset.yaml

## Apply MachineConfig yaml directly
oc apply -f https://raw.githubusercontent.com/rmr-silicom/machine-config-kmod/main/99-kvc-kmod.yaml

## TODO:
* Convert the MachineConfig to MachineConfigPool so the labels/annotations created by NFD will be used.

## Others
https://github.com/open-ness/openshift-operator
https://catalog.redhat.com/software/operators/detail/5ffd640a2808e868018797c9

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


## FW update on FPGA card
echo -n /root > /sys/module/firmware_class/parameters/path
echo -n ofs_fim_page1_unsigned.bin > /sys/class/fpga_sec_mgr/fpga_sec0/update/filename
cat /sys/class/fpga_sec_mgr/fpga_sec0/update/status
