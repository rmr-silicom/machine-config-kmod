#!/bin/sh

source /dfl-kmod.conf

echo ${KVC_KVER}
for driver in $KMOD_NAMES ; do
    echo ${driver}
    modprobe -S ${KVC_KVER} ${driver}
done

sleep infinity
