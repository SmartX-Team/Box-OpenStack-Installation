#!/bin/bash

INTERFACE=br-ex

ovs-vsctl add-br br-ex
ifconfig $INTERFACE 0
ovs-vsctl add-port br-ex $INTERFACE

sed -i "s/$INTERFACE/br-ex/g" /etc/network/interfaces
sed -i "s/loopback/loopback\n\n\
auto $INTERFACE/g" /etc/network/interfaces

echo "this is end for ethernet setting"

ifdown br-ex
ifup br-ex
ifconfig $INTERFACE up
