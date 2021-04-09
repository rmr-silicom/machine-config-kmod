#!/bin/bash

# The MIT License

# Copyright (c) 2019 Dusty Mabe

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -eu

# This library is to be sourced in as part of the kmods-via-containers
# framework. There are some environment variables that are used in this
# file that are expected to be defined by the framework already:
# - KVC_CONTAINER_RUNTIME
#   - The container runtime to use (example: podman|docker)
# - KVC_SOFTWARE_NAME
#   - The name of this module software bundle
# - KVC_KVER
#   - The kernel version we are targeting

# There are other environment variables that come from the config file
# delivered alongside this library. The expected variables are:
# - KMOD_CONTAINER_BUILD_CONTEXT
#   - A string representing the location of the build context
# - KMOD_CONTAINER_BUILD_FILE
#   - The name of the file in the context with the build definition
#     (i.e. Dockerfile)
# - KMODVER
#   - The version of the software bundle
# - KMOD_NAMES
#   - A space separated list kernel module names that are part of the
#     module software bundle and are to be checked/loaded/unloaded
source "/etc/kvc/${KVC_SOFTWARE_NAME}.conf"

# The name of the container image to consider. It will be a unique
# combination of the module software name/version and the targeted
# kernel version.
# IMAGE="${KMOD_REPOS}/${KVC_SOFTWARE_NAME}:${KMODVER}-${KVC_KVER}"

build_kmod_container() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

 --build-arg RPM_URL=$(RHEL82_RPM) --build-arg KMODVER=$(KMODVER) --build-arg KVER=$(KVER_RHEL82)
    echo "Building ${IMAGE} kernel module container..."
    kvc_c_build --tls-verify=false -t ${KMOD_REPOS}/${IMAGE}   \
        --file ${KMOD_CONTAINER_BUILD_FILE}          \
        --label="name=${KVC_SOFTWARE_NAME}"          \
        --build-arg CENTOS_VER=${CENTOS_VER}         \
        --build-arg KVER=${KVC_KVER}                 \
        --build-arg KMODVER=${KMODVER} \
        ${KMOD_CONTAINER_BUILD_CONTEXT}

    # get rid of any dangling containers if they exist
    echo "Checking for old kernel module images that need to be recycled"
    rmi1=$(kvc_c_images -q -f label="name=${KVC_SOFTWARE_NAME}" -f dangling=true)
    # keep around any non-dangling images for only the most recent 3 kernels
    rmi2=$(kvc_c_images -q -f label="name=${KVC_SOFTWARE_NAME}" -f dangling=false | tail -n +4)
    if [ ! -z "${rmi1}" -o ! -z "${rmi2}" ]; then
        echo "Cleaning up old kernel module container builds"
        kvc_c_rmi -f $rmi1 $rmi2
    fi
}

is_kmod_loaded() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

    module=${1//-/_} # replace any dashes with underscore
    if lsmod | grep "${module}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

build_kmods() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

    # Check to see if it's already pulled
    if [ -z "$(kvc_c_images ${KMOD_REPOS}/$IMAGE --quiet 2>/dev/null)" ]; then
        echo "The ${KMOD_REPOS}/${IMAGE} kernel module container has not been built/pulled"
        podman pull ${KMOD_REPOS}/${IMAGE}
    fi

    # Sanity checks for each module to load
    for module in ${KMOD_NAMES}; do
        module=${module//_/-} # replace any underscores with dash
        # Sanity check to make sure the built kernel modules were really
        # built against the correct module software version
        # Note the tr to delete the trailing carriage return
        x=$(kvc_c_run ${KMOD_REPOS}/$IMAGE modinfo -F version "/lib/modules/${KVC_KVER}/extra/${module}.ko" | \
                                                                            tr -d '\r')
        if [ "${x}" != "${KMODVER}" ]; then
            echo "Module version mismatch within container. rebuilding ${KMOD_REPOS}/${IMAGE}"
            echo "${x}, ${KMODVER}"
            build_kmod_container
        fi
        # Sanity check to make sure the built kernel modules were really
        # built against the desired kernel version
        x=$(kvc_c_run ${KMOD_REPOS}/$IMAGE modinfo -F vermagic "/lib/modules/${KVC_KVER}/extra/${module}.ko" | \
                                                                        cut -d ' ' -f 1)
        if [ "${x}" != "${KVC_KVER}" ]; then
            echo "Module not built against ${KMODVER}. rebuilding ${KMOD_REPOS}/${IMAGE}"
            echo "${x}, ${KVC_KVER}"
            build_kmod_container
        fi
    done
}

load_kmods() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

    echo "Loading kernel modules using the kernel module container..."
    for module in ${KMOD_NAMES}; do
        if is_kmod_loaded ${module}; then
            echo "Kernel module ${module} already loaded"
        else
            module=${module//-/_} # replace any dashes with underscore
            kvc_c_run --privileged ${KMOD_REPOS}/$IMAGE modprobe -S ${KVC_KVER} ${module}
        fi
    done
}

unload_kmods() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

    echo "Unloading kernel modules..."
    for module in ${KMOD_NAMES}; do
        if is_kmod_loaded ${module}; then
            module=${module//-/_} # replace any dashes with underscore
            rmmod "${module}"
        else
            echo "Kernel module ${module} already unloaded"
        fi
    done
}

wrapper() {
    if ! $(lspci -d 1c2c: | grep -q Silicom) ; then
        echo "No Silicom FPGA card on this node"
        return
    fi

    echo "Running userspace wrapper using the kernel module container..."
    kvc_c_run --privileged ${KMOD_REPOS}/$IMAGE $@
}
