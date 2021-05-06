#!/bin/sh

source /dfl-kmod.conf

for driver in $KMOD_NAMES ; do
    modprobe -S ${KVC_KVER} ${module}
done
