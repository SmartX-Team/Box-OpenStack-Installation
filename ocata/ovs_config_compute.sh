#!/bin/bash

# COMPUTE_NODE_CH_M_INTERFACE=eno1

apt update && apt install -y openvswitch-switch

ovs-vsctl add-br br-ex
ifconfig $COMPUTE_NODE_CH_M_INTERFACE 0
ovs-vsctl add-port br-ex $COMPUTE_NODE_CH_M_INTERFACE

sed -i "s/$COMPUTE_NODE_CH_M_INTERFACE/br-ex/g" /etc/network/interfaces
# sed -i "s/loopback/loopback\n\n\
# auto $COMPUTE_NODE_CH_M_INTERFACE\niface $COMPUTE_NODE_CH_M_INTERFACE inet manual/g" /etc/network/interfaces
cat <<EOT >> /etc/network/interfaces

auto $COMPUTE_NODE_CH_M_INTERFACE
iface $COMPUTE_NODE_CH_M_INTERFACE inet manual
EOT


echo "this is end for ethernet setting"

ifdown br-ex
ifup br-ex
ip link set $COMPUTE_NODE_CH_M_INTERFACE up
