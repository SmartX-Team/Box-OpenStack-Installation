#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi




sed -i "/#kernel.domainname = example.com/a\
net.ipv4.ip_forward=1\n\
net.ipv4.conf.all.rp_filter=0\n\
net.ipv4.conf.default.rp_filter=0\n\
net.bridge.bridge-nf-call-iptables=1\n\
net.bridge.bridge-nf-call-ip6tables=1" /etc/sysctl.conf




# Install and Configure Neutron Compute Node

#Install and configure components

#1.Install the packages:
apt install -y neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent



source env-setup.sh

#•Edit the /etc/neutron/neutron.conf file and complete the following actions:
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT transport_url=rabbit://openstack:$RABBITMQ_PASSWORD@$CH_C_INTERFACE_ADDRESS

./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT auth_strategy=keystone


./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_uri=http://$CH_C_INTERFACE_ADDRESS:5000
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_url=http://$CH_C_INTERFACE_ADDRESS:5000
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken memcached_servers=$CH_C_INTERFACE_ADDRESS:11211
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_type=password
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken project_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken user_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken project_name=service
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken username=neutron
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken password=$OPENSTACK_NEUTRON_USER_PASSWORD



#•Edit the /etc/nova/nova.conf file and complete the following actions:
#◦In the [neutron] section, configure access parameters:

./conf_feeder.sh /etc/nova/nova.conf set neutron url=http://$CH_C_INTERFACE_ADDRESS:9696
./conf_feeder.sh /etc/nova/nova.conf set neutron auth_url=http://$CH_C_INTERFACE_ADDRESS:5000
./conf_feeder.sh /etc/nova/nova.conf set neutron auth_type=password
./conf_feeder.sh /etc/nova/nova.conf set neutron project_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set neutron user_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set neutron region_name=$REGION_NAME
./conf_feeder.sh /etc/nova/nova.conf set neutron project_name=service
./conf_feeder.sh /etc/nova/nova.conf set neutron username=neutron
./conf_feeder.sh /etc/nova/nova.conf set neutron password=$OPENSTACK_NEUTRON_USER_PASSWORD
./conf_feeder.sh /etc/nova/nova.conf set neutron service_metadata_proxy=true
./conf_feeder.sh /etc/nova/nova.conf set neutron metadata_proxy_shared_secret=METADATA_SECRET





#.In the l3_agent.ini file, configure the L3 agent:
./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT interface_driver=openvswitch
./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT external_network_bridge=

#DVR enabled
./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT agent_mode=dvr



#.In the metadata_agent.ini file, configure the metadata agent:
./conf_feeder.sh /etc/neutron/metadata_agent.ini set DEFAULT nova_metadata_host=$CH_C_INTERFACE_ADDRESS
./conf_feeder.sh /etc/neutron/metadata_agent.ini set DEFAULT metadata_proxy_shared_secret=METADATA_SECRET





#•Edit the /etc/neutron/plugins/ml2/ml2_conf.ini file and complete the following actions:
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 type_drivers=flat,vlan,vxlan
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 tenant_network_types=vxlan

./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 mechanism_drivers=openvswitch,l2population
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 extension_drivers=port_security

./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2_type_vxlan vni_ranges=1:1000
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2_type_flat flat_networks=external


./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set securitygroup firewall_driver=iptables_hybrid
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set securitygroup enable_ipset=true




#.In the openvswitch_agent.ini file, configure the Open vSwitch agent:
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set ovs bridge_mappings=external:br-ex
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set ovs local_ip=$COMPUTE_NODE_CH_D_INTERFACE_ADDRESS

./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent tunnel_types=vxlan
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent l2_population=True

./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set securitygroup firewall_driver=iptables_hybrid
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set securitygroup enable_security_group=true


./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent arp_responder=True
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent enable_distributed_routing=True






#Restart the Neutron service:
systemctl restart nova-compute.service
systemctl restart neutron-openvswitch-agent.service
systemctl restart neutron-l3-agent.service
systemctl restart neutron-metadata-agent.service
