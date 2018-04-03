#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


# COMPUTE_NODE_CH_M_INTERFACE_ADDRESS=210.114.90.170
# COMPUTE_NODE_CH_C_INTERFACE_ADDRESS=172.20.90.170
# COMPUTE_NODE_CH_D_INTERFACE_ADDRESS=172.30.90.170
# CH_M_INTERFACE_ADDRESS=210.114.90.172
# CH_C_INTERFACE_ADDRESS=172.20.90.172
#RABBIT_PASS=secrete
PASSWORD=PASS
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr

source env-setup.sh

# Install and Configure Nova Controller Node

#Install and configure components

#1.Install the packages:
apt install -y nova-compute


#2.Edit the /etc/nova/nova.conf file and complete the following actions:

#◦In the [DEFAULT] section, configure RabbitMQ message queue access
./conf_feeder.sh /etc/nova/nova.conf set DEFAULT transport_url=rabbit://openstack:$RABBITMQ_PASSWORD@$CH_C_INTERFACE_ADDRESS


#◦In the [api] and [keystone_authtoken] sections, configure Identity service access:
./conf_feeder.sh /etc/nova/nova.conf set api auth_strategy=keystone


./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken auth_uri=http://$CH_C_INTERFACE_ADDRESS:5000
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken auth_url=http://$CH_C_INTERFACE_ADDRESS:5000
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken memcached_servers=$CH_C_INTERFACE_ADDRESS:11211
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken auth_type=password
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken project_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken user_domain_name=default
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken project_name=service
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken username=nova
./conf_feeder.sh /etc/nova/nova.conf set keystone_authtoken password=$OPENSTACK_NOVA_USER_PASSWORD


#◦In the [DEFAULT] section, configure the my_ip option:
./conf_feeder.sh /etc/nova/nova.conf set DEFAULT my_ip=$COMPUTE_NODE_CH_C_INTERFACE_ADDRESS

#◦In the [DEFAULT] section, enable support for the Networking service:
./conf_feeder.sh /etc/nova/nova.conf set DEFAULT use_neutron=True
./conf_feeder.sh /etc/nova/nova.conf set DEFAULT firewall_driver=nova.virt.firewall.NoopFirewallDriver

#◦In the [vnc] section, enable and configure remote console access:
./conf_feeder.sh /etc/nova/nova.conf set vnc enabled=True
./conf_feeder.sh /etc/nova/nova.conf set vnc server_listen=0.0.0.0
./conf_feeder.sh /etc/nova/nova.conf set vnc server_proxyclient_address=$COMPUTE_NODE_CH_C_INTERFACE_ADDRESS
./conf_feeder.sh /etc/nova/nova.conf set vnc novncproxy_base_url=http://$CH_M_INTERFACE_ADDRESS:6080/vnc_auto.html


#◦In the [glance] section, configure the location of the Image service API:
./conf_feeder.sh /etc/nova/nova.conf set glance api_servers=http://$CH_C_INTERFACE_ADDRESS:9292


#◦In the [oslo_concurrency] section, configure the lock path:
./conf_feeder.sh /etc/nova/nova.conf set oslo_concurrency lock_path=/var/lib/nova/tmp

#•Due to a packaging bug, remove the log_dir option from the [DEFAULT] section.
./conf_feeder.sh /etc/nova/nova.conf unset DEFAULT log_dir

#◦In the [placement] section, configure the Placement API:
./conf_feeder.sh /etc/nova/nova.conf set placement os_region_name=$REGION_NAME
./conf_feeder.sh /etc/nova/nova.conf set placement project_domain_name=Default
./conf_feeder.sh /etc/nova/nova.conf set placement project_name=service
./conf_feeder.sh /etc/nova/nova.conf set placement auth_type=password
./conf_feeder.sh /etc/nova/nova.conf set placement user_domain_name=Default
./conf_feeder.sh /etc/nova/nova.conf set placement auth_url=http://$CH_C_INTERFACE_ADDRESS:5000/v3
./conf_feeder.sh /etc/nova/nova.conf set placement username=placement
./conf_feeder.sh /etc/nova/nova.conf set placement password=$OPENSTACK_PLACEMENT_USER_PASSWORD


#Finalize installation

#1.Determine whether your compute node supports hardware acceleration for virtual machines:
NUM=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $NUM = 0 ]
then
 echo "here"
 sed -i "s/virt_type=kvm/virt_type=qemu/g" /etc/nova/nova-compute.conf
fi

#2.Restart the Compute service:
systemctl restart nova-compute.service

#Permission 
chown -R nova:nova /var/lib/nova

