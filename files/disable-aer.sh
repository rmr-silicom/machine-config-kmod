#!/bin/bash

# https://alexforencich.com/wiki/en/pcie/disable-fatal

# bash /root/disable-aer.sh
#   Disabling fatal error reporting on port 0000:00:04.0...
#   Command: 0446
#   Device control: 5932

dev=$(lspci -d1c2c: -n | awk '{print $1}')

if [ -z "$dev" ]; then
    echo "Error: no device specified"
    exit 1
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    dev="0000:$dev"
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    echo "Error: device $dev not found"
    exit 1
fi

port=$dev
# port="$(basename $(dirname $(readlink "/sys/bus/pci/devices/$dev")))"

if [ ! -e "/sys/bus/pci/devices/$port" ]; then
    echo "Error: device $port not found"
    exit 1
fi

echo "Disabling fatal error reporting on port $port..."

cmd=$(setpci -v -s $port COMMAND)

echo "Command:" $cmd

# clear SERR bit in command register
setpci -v -s $port COMMAND=$(printf "%04x" $(("0x$cmd" & ~0x0100)))

ctrl=$(setpci -v -s $port CAP_EXP+8.w)
 
echo "Device control:" $ctrl

# clear fatal error reporting enable bit in device control register
setpci -v -s $port CAP_EXP+8.w=$(printf "%04x" $(("0x$ctrl" & ~0x0004)))
