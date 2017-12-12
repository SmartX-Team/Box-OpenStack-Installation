#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


# CH_M_INTERFACE_ADDRESS=210.125.84.51
# CH_C_INTERFACE_ADDRESS=192.168.88.51
# CH_D_INTERFACE_ADDRESS=10.10.20.51
#RABBIT_PASS=secrete
PASSWORD=fn!xo!ska!
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr


# Install and Configure Glance Service


#1.To create the database, complete these steps:
cat << EOF | mysql -uroot -p$MYSQL_ROOT_PASSWORD
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DB_PASSWORD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DB_PASSWORD';
quit
EOF

#2.Source the admin credentials to gain access to admin-only CLI commands:
source admin-openrc.sh

#3.To create the service credentials, complete these steps:
#◦Create the glance user:
openstack user create --domain default --password $OPENSTACK_GLANCE_USER_PASSWORD glance

#◦Add the admin role to the glance user and service project:
openstack role add --project service --user glance admin

#◦Create the glance service entity:
openstack service create --name glance \
  --description "OpenStack Image" image

#4.Create the Image service API endpoints:
openstack endpoint create --region $REGION_NAME \
  image public http://$CH_C_INTERFACE_ADDRESS:9292

openstack endpoint create --region $REGION_NAME \
  image internal http://$CH_C_INTERFACE_ADDRESS:9292

openstack endpoint create --region $REGION_NAME \
  image admin http://$CH_C_INTERFACE_ADDRESS:9292



#Install and configure components

#1.Install the packages:
apt install -y glance

#2.Edit the /etc/glance/glance-api.conf file and complete the following actions:
#◦In the [database] section, configure database access:
sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/glance:$GLANCE_DB_PASSWORD@$CH_C_INTERFACE_ADDRESS\/glance/g" /etc/glance/glance-api.conf

#◦In the [keystone_authtoken] and [paste_deploy] sections, configure Identity service access:
sed -i "s/#auth_uri = <None>/auth_uri = http:\/\/$CH_C_INTERFACE_ADDRESS:5000\n\
auth_url = http:\/\/$CH_C_INTERFACE_ADDRESS:35357\n\
memcached_servers = $CH_C_INTERFACE_ADDRESS:11211\n\
auth_type = password\n\
project_domain_name = default\n\
user_domain_name = default\n\
project_name = service\n\
username = glance\n\
password = $OPENSTACK_GLANCE_USER_PASSWORD\n/g" /etc/glance/glance-api.conf

sed -i "s/#flavor = keystone/flavor = keystone/g" /etc/glance/glance-api.conf

#◦In the [glance_store] section, configure the local file system store and location of image files:
sed -i "s/#stores = file,http/stores = file,http/g" /etc/glance/glance-api.conf
sed -i "s/#default_store = file/default_store = file/g" /etc/glance/glance-api.conf
sed -i "s/#filesystem_store_datadir = \/var\/lib\/glance\/images/filesystem_store_datadir = \/var\/lib\/glance\/images/g" /etc/glance/glance-api.conf


#3.Edit the /etc/glance/glance-registry.conf file and complete the following actions:
#◦In the [database] section, configure database access:
sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/glance:$GLANCE_DB_PASSWORD@$CH_C_INTERFACE_ADDRESS\/glance/g" /etc/glance/glance-registry.conf

#◦In the [keystone_authtoken] and [paste_deploy] sections, configure Identity service access:
sed -i "s/#auth_uri = <None>/auth_uri = http:\/\/$CH_C_INTERFACE_ADDRESS:5000\n\
auth_url = http:\/\/$CH_C_INTERFACE_ADDRESS:35357\n\
memcached_servers = $CH_C_INTERFACE_ADDRESS:11211\n\
auth_type = password\n\
project_domain_name = default\n\
user_domain_name = default\n\
project_name = service\n\
username = glance\n\
password = $OPENSTACK_GLANCE_USER_PASSWORD\n/g" /etc/glance/glance-registry.conf

sed -i "s/#flavor = keystone/flavor = keystone/g" /etc/glance/glance-registry.conf


#4.Populate the Image service database:
su -s /bin/sh -c "glance-manage db_sync" glance

# Restart the Image services:
systemctl restart glance-registry.service
systemctl restart glance-api.service



# Download the source image:
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img

# Upload the image to the Image service using the QCOW2 disk format, bare container format, and public visibility so all projects can access it:
openstack image create "cirros" \
  --file cirros-0.3.5-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public





