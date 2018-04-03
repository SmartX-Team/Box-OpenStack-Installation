#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=210.125.84.61
C_IP=172.25.0.51
D_IP=10.0.0.1
#RABBIT_PASS=secrete
PASSWORD=
MTU=1400

#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr


sed -i "/#kernel.domainname = example.com/a\
net.ipv4.ip_forward=1\n\
net.ipv4.conf.all.rp_filter=0\n\
net.ipv4.conf.default.rp_filter=0" /etc/sysctl.conf





#1.To create the database, complete these steps:
cat << EOF | mysql -uroot -p$PASSWORD
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$PASSWORD';
quit
EOF

#2.Source the admin credentials to gain access to admin-only CLI commands:
source admin-openrc.sh

#3.To create the service credentials, complete these steps:
#◦Create the neutron user:
openstack user create --domain default --password $PASSWORD neutron

#◦Add the admin role to the neutron user:
openstack role add --project service --user neutron admin

#◦Create the neutron service entity:
openstack service create --name neutron \
  --description "OpenStack Networking" network



#4.Create the Networking service API endpoints:
openstack endpoint create --region RegionOne \
  network public http://$M_IP:9696

openstack endpoint create --region RegionOne \
  network internal http://$C_IP:9696

openstack endpoint create --region RegionOne \
  network admin http://$C_IP:9696


#Install the components
sudo apt-get install -y neutron-server neutron-plugin-ml2 \
  neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent


source env-setup.sh


##•Edit the /etc/neutron/neutron.conf file and complete the following actions:
./conf_feeder.sh /etc/neutron/neutron.conf set database connection=mysql+pymysql://neutron:$PASSWORD@$C_IP/neutron

./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT service_plugins=router
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT core_plugin=ml2
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT allow_overlapping_ips=True
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT transport_url=rabbit://openstack:$PASSWORD@$C_IP

#◦In the [DEFAULT] and [keystone_authtoken] sections, configure Identity service access:
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT auth_strategy=keystone

./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_uri=http://$C_IP:5000
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_url=http://$C_IP:5000
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken memcached_servers=$C_IP:11211
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken auth_type=password
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken project_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken user_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken project_name=service
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken username=neutron
./conf_feeder.sh /etc/neutron/neutron.conf set keystone_authtoken password=$PASSWORD

#◦In the [DEFAULT] and [nova] sections, configure Networking to notify Compute of network topology changes:
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT notify_nova_on_port_status_changes=True
./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT notify_nova_on_port_data_changes=True

./conf_feeder.sh /etc/neutron/neutron.conf set nova auth_url=http://$C_IP:5000
./conf_feeder.sh /etc/neutron/neutron.conf set nova auth_type=password
./conf_feeder.sh /etc/neutron/neutron.conf set nova project_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set nova user_domain_name=default
./conf_feeder.sh /etc/neutron/neutron.conf set nova region_name=RegionOne
./conf_feeder.sh /etc/neutron/neutron.conf set nova project_name=service
./conf_feeder.sh /etc/neutron/neutron.conf set nova username=nova
./conf_feeder.sh /etc/neutron/neutron.conf set nova password=$PASSWORD


#DVR enable

./conf_feeder.sh /etc/neutron/neutron.conf set DEFAULT router_distributed=True
#router_distributed = True/g" /etc/neutron/neutron.conf



#Configure the Modular Layer 2 (ML2) plug-in¶
#◦Add vxlan to type drivers and project network types.
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 type_drivers=flat,vlan,vxlan
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 tenant_network_types=vxlan

#◦Enable the layer-2 population mechanism driver.
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 mechanism_drivers=openvswitch,l2population

#◦Configure the VXLAN network ID (VNI) range.
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2_type_vxlan vni_ranges=1:1000


#•Edit the /etc/neutron/plugins/ml2/ml2_conf.ini file and complete the following actions:
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2 extension_drivers=port_security

#◦In the [ml2_type_flat] section, configure the provider virtual network as a flat network:
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set ml2_type_flat flat_networks=external

#◦In the [securitygroup] section, enable ipset to increase efficiency of security group rules:
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set securitygroup firewall_driver=iptables_hybrid
./conf_feeder.sh /etc/neutron/plugins/ml2/ml2_conf.ini set securitygroup enable_ipset=true






#.In the openvswitch_agent.ini file, configure the Open vSwitch agent:
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set ovs bridge_mappings=external:br-ex
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set ovs local_ip=$D_IP

./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent tunnel_types=vxlan
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent l2_population=True

./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set securitygroup firewall_driver=iptables_hybrid
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set securitygroup enable_security_group=true


./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent arp_responder=True
./conf_feeder.sh /etc/neutron/plugins/ml2/openvswitch_agent.ini set agent enable_distributed_routing=True



#.In the l3_agent.ini file, configure the L3 agent:

./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT interface_driver=openvswitch
./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT external_network_bridge=

#DVR enabled
./conf_feeder.sh /etc/neutron/l3_agent.ini set DEFAULT agent_mode=dvr_snat




#.In the dhcp_agent.ini file, configure the DHCP agent:
./conf_feeder.sh /etc/neutron/dhcp_agent.ini set DEFAULT interface_driver=openvswitch
./conf_feeder.sh /etc/neutron/dhcp_agent.ini set DEFAULT enable_isolated_metadata=True


touch /etc/neutron/dnsmasq-neutron.conf
echo "dhcp-option-force=26,1400" >> /etc/neutron/dnsmasq-neutron.conf

./conf_feeder.sh /etc/neutron/dhcp_agent.ini set DEFAULT dnsmasq_config_file=/etc/neutron/dnsmasq-neutron.conf


pkill dnsmasq




#.In the metadata_agent.ini file, configure the metadata agent:
./conf_feeder.sh /etc/neutron/metadata_agent.ini set DEFAULT nova_metadata_host=$C_IP
./conf_feeder.sh /etc/neutron/metadata_agent.ini set DEFAULT metadata_proxy_shared_secret=METADATA_SECRET



###### for compute service!!!

#•Edit the /etc/nova/nova.conf file and complete the following actions:
#◦In the [neutron] section, configure access parameters:

./conf_feeder.sh /etc/nova/nova.conf set neutron url=http://$C_IP:9696
./conf_feeder.sh /etc/nova/nova.conf set neutron auth_url=http://$C_IP:5000
./conf_feeder.sh /etc/nova/nova.conf set neutron auth_type=password
./conf_feeder.sh /etc/nova/nova.conf set neutron project_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set neutron user_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set neutron region_name=RegionOne
./conf_feeder.sh /etc/nova/nova.conf set neutron project_name=service
./conf_feeder.sh /etc/nova/nova.conf set neutron username=neutron
./conf_feeder.sh /etc/nova/nova.conf set neutron password=$PASSWORD
./conf_feeder.sh /etc/nova/nova.conf set neutron service_metadata_proxy=true
./conf_feeder.sh /etc/nova/nova.conf set neutron metadata_proxy_shared_secret=METADATA_SECRET




#Finalize installation
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron


#Restart the Compute service:
service nova-api restart
service neutron-server restart
service openvswitch-switch restart
service neutron-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart





