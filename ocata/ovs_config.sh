#!/bin/bash

# CH_M_INTERFACE=eno1

apt update && apt install -y openvswitch-switch

ovs-vsctl add-br br-ex
ifconfig $CH_M_INTERFACE 0
ovs-vsctl add-port br-ex $CH_M_INTERFACE

sed -i "s/$CH_M_INTERFACE/br-ex/g" /etc/network/interfaces
# sed -i "s/loopback/loopback\n\n\
# auto $CH_M_INTERFACE\niface $CH_M_INTERFACE inet manual/g" /etc/network/interfaces
cat <<EOT >> /etc/network/interfaces

auto $CH_M_INTERFACE
iface $CH_M_INTERFACE inet manual
EOT

echo "this is end for ethernet setting"

ifdown br-ex
ifup br-ex
ip link set $CH_M_INTERFACE up
