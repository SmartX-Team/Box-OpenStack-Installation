#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=210.114.90.172
C_IP=172.20.90.172
D_IP=172.30.90.172
#RABBIT_PASS=secrete
PASSWORD=PASS
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr


# Install and Configure Nova Controller Node

#Prerequisites

#1.To create the database, complete these steps:
cat << EOF | mysql -uroot -p$PASSWORD
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$PASSWORD';
quit
EOF



#2.Source the admin credentials to gain access to admin-only CLI commands:
source admin-openrc.sh

#3.To create the service credentials, complete these steps:
#◦Create the nova user:
openstack user create --domain default \
  --password $PASSWORD nova

#◦Add the admin role to the nova user:
openstack role add --project service --user nova admin

#◦Create the nova service entity:
openstack service create --name nova \
  --description "OpenStack Compute" compute


#4.Create the Compute service API endpoints:
openstack endpoint create --region RegionOne \
  compute public http://$M_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute internal http://$C_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute admin http://$C_IP:8774/v2.1/%\(tenant_id\)s

#5.Create a Placement service user using your chosen PLACEMENT_PASS:
openstack user create --domain default \
  --password $PASSWORD placement

#6.Add the Placement user to the service project with the admin role:
openstack role add --project service --user placement admin

#7.Create the Placement API entry in the service catalog:
openstack service create --name placement --description "Placement API" placement

#8.Create the Placement API service endpoints:
openstack endpoint create --region RegionOne placement public http://$M_IP:8778

openstack endpoint create --region RegionOne placement public http://$C_IP:8778

openstack endpoint create --region RegionOne placement public http://$C_IP:8778





#Install and configure components

#1.Install the packages:
sudo apt-get install -y nova-api nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler nova-placement-api


#2.Edit the /etc/nova/nova.conf file and complete the following actions:
#◦In the [api_database] and [database] sections, configure database access:

sed -i "s/connection=sqlite:\/\/\/\/var\/lib\/nova\/nova.sqlite/connection = mysql+pymysql:\/\/nova:$PASSWORD@$C_IP\/nova_api/g" /etc/nova/nova.conf

sed -i "s/#connection=<None>/connection = mysql+pymysql:\/\/nova:$PASSWORD@$C_IP\/nova/g" /etc/nova/nova.conf


#◦In the [DEFAULT] section, configure RabbitMQ message queue access:
sed -i "s/#transport_url=<None>/transport_url = rabbit:\/\/openstack:$PASSWORD@$C_IP/g" /etc/nova/nova.conf


#◦In the [api] and [keystone_authtoken] sections, configure Identity service access:
sed -i "s/#auth_strategy=keystone/auth_strategy=keystone/g" /etc/nova/nova.conf


#2.Edit the /etc/nova/nova.conf file and complete the following actions:
sed -i "s/enabled_apis=osapi_compute,metadata/enabled_apis=osapi_compute,metadata\n\
my_ip = $C_IP\n\
use_neutron = True \n\
firewall_driver = nova.virt.firewall.NoopFirewallDriver\n\
rpc_backend = rabbit\n\
auth_strategy = keystone/g" /etc/nova/nova.conf


sed -i "s/#auth_uri=<None>/auth_uri = http:\/\/$C_IP:5000\n\
auth_url = http:\/\/$C_IP:35357\n\
memcached_servers = $C_IP:11211\n\
auth_type = password\n\
project_domain_name = default\n\
user_domain_name = default\n\
project_name = service\n\
username = nova\n\
password = $PASSWORD/g" /etc/nova/nova.conf


#◦In the [DEFAULT] section, configure the my_ip option to use the management interface IP address of the controller node:
sed -i "s/#my_ip=10.89.104.70/my_ip= $C_IP/g" /etc/nova/nova.conf

#•In the [DEFAULT] section, enable support for the Networking service:
sed -i "s/#use_neutron=true/use_neutron=true/g" /etc/nova/nova.conf
sed -i "s/#firewall_driver=<None>/firewall_driver = nova.virt.firewall.NoopFirewallDriver/g" /etc/nova/nova.conf

#•In the [vnc] section, configure the VNC proxy to use the management interface IP address of the controller node:
sed -i "s/#vncserver_listen=127.0.0.1/vncserver_listen = $C_IP/g" /etc/nova/nova.conf
sed -i "s/#vncserver_proxyclient_address=127.0.0.1/vncserver_proxyclient_address = $C_IP/g" /etc/nova/nova.conf
sed -i "s/#enabled=true/enabled = true/g" /etc/nova/nova.conf

#•In the [glance] section, configure the location of the Image service API:
sed -i "s/#api_servers=<None>/api_servers = http:\/\/$C_IP:9292/g" /etc/nova/nova.conf

#•In the [oslo_concurrency] section, configure the lock path:
sed -i "s/lock_path=\/var\/lock\/nova/lock_path= \/var\/lib\/nova\/tmp/g" /etc/nova/nova.conf

sed -i "s/log_dir=\/var\/log\/nova/#log_dir=<None>/g" /etc/nova/nova.conf

#•In the [placement] section, configure the Placement API:
sed -i "s/os_region_name = openstack/os_region_name = RegionOne\n\
project_domain_name = Default\n\
project_name = service\n\
auth_type = password\n\
user_domain_name = Default\n\
auth_url = http:\/\/$C_IP:35357\/v3\n\
username = placement\n\
password = $PASSWORD/g" /etc/nova/nova.conf



#3.Populate the nova-api database:
su -s /bin/sh -c "nova-manage api_db sync" nova

#4.Register the cell0 database:
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova

#5.Create the cell1 cell:
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova

#6.Populate the nova database:
su -s /bin/sh -c "nova-manage db sync" nova


#•Restart the Compute services:
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart




