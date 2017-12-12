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


# Install and Configure Nova Controller Node

#Install and configure components

#1.Install the packages:
apt install -y nova-compute


#2.Edit the /etc/nova/nova.conf file and complete the following actions:

#◦In the [DEFAULT] section, configure RabbitMQ message queue access
sed -i "s/#transport_url=<None>/transport_url = rabbit:\/\/openstack:$RABBITMQ_PASSWORD@$CH_C_INTERFACE_ADDRESS/g" /etc/nova/nova.conf

#◦In the [api] and [keystone_authtoken] sections, configure Identity service access:
sed -i "s/#auth_strategy=keystone/auth_strategy=keystone/g" /etc/nova/nova.conf

sed -i "s/#auth_uri=<None>/auth_uri = http:\/\/$CH_C_INTERFACE_ADDRESS:5000\n\
auth_url = http:\/\/$CH_C_INTERFACE_ADDRESS:35357\n\
memcached_servers = $CH_C_INTERFACE_ADDRESS:11211\n\
auth_type = password\n\
project_domain_name = default\n\
user_domain_name = default\n\
project_name = service\n\
username = nova\n\
password = $OPENSTACK_NOVA_USER_PASSWORD/g" /etc/nova/nova.conf

#◦In the [DEFAULT] section, configure the my_ip option:
sed -i "s/#my_ip=10.222.99.93/my_ip=$COMPUTE_NODE_CH_C_INTERFACE_ADDRESS/g" /etc/nova/nova.conf

#◦In the [DEFAULT] section, enable support for the Networking service:
sed -i "s/#use_neutron=true/use_neutron = true/g" /etc/nova/nova.conf
sed -i "s/#firewall_driver=<None>/firewall_driver = nova.virt.firewall.NoopFirewallDriver/g" /etc/nova/nova.conf

#◦In the [vnc] section, enable and configure remote console access:
sed -i "s/#enabled=true/enabled = true/g" /etc/nova/nova.conf
sed -i "s/#vncserver_listen=127.0.0.1/vncserver_listen = 0.0.0.0/g" /etc/nova/nova.conf
sed -i "s/#vncserver_proxyclient_address=127.0.0.1/vncserver_proxyclient_address = $COMPUTE_NODE_CH_C_INTERFACE_ADDRESS/g" /etc/nova/nova.conf
sed -i "s/#novncproxy_base_url=http:\/\/127.0.0.1:6080\/vnc_auto.html/novncproxy_base_url=http:\/\/$CH_M_INTERFACE_ADDRESS:6080\/vnc_auto.html/g" /etc/nova/nova.conf

#◦In the [glance] section, configure the location of the Image service API:
sed -i "s/#api_servers=<None>/api_servers = http:\/\/$CH_C_INTERFACE_ADDRESS:9292/g" /etc/nova/nova.conf

#◦In the [oslo_concurrency] section, configure the lock path:
sed -i "s/lock_path=\/var\/lock\/nova/lock_path = \/var\/lib\/nova\/tmp/g" /etc/nova/nova.conf

sed -i "s/log_dir=\/var\/log\/nova/#log_dir/g" /etc/nova/nova.conf

#◦In the [placement] section, configure the Placement API:
sed -i "s/os_region_name = openstack/os_region_name = $REGION_NAME\n\
project_domain_name = Default\n\
project_name = service\n\
auth_type = password\n\
user_domain_name = Default\n\
auth_url = http:\/\/$CH_C_INTERFACE_ADDRESS:35357\/v3\n\
username = placement\n\
password = $OPENSTACK_PLACEMENT_USER_PASSWORD/g" /etc/nova/nova.conf



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

