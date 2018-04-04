#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=
C_IP=
D_IP=
#RABBIT_PASS=secree
PASSWORD=
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr


# Install and Configure Glance Service


#1.To create the database, complete these steps:
cat << EOF | mysql -uroot -p$PASSWORD
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$PASSWORD';
quit
EOF

#2.Source the admin credentials to gain access to admin-only CLI commands:
source admin-openrc.sh

#3.To create the service credentials, complete these steps:
#◦Create the glance user:
openstack user create --domain default --password $PASSWORD glance

#◦Add the admin role to the glance user and service project:
openstack role add --project service --user glance admin

#◦Create the glance service entity:
openstack service create --name glance \
  --description "OpenStack Image" image

#4.Create the Image service API endpoints:
openstack endpoint create --region RegionOne \
  image public http://$M_IP:9292

openstack endpoint create --region RegionOne \
  image internal http://$C_IP:9292

openstack endpoint create --region RegionOne \
  image admin http://$C_IP:9292



#Install and configure components

#1.Install the packages:
sudo apt-get install -y glance

#2.Edit the /etc/glance/glance-api.conf file and complete the following actions:
#◦In the [database] section, configure database access:
#sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/glance:$PASSWORD@$C_IP\/glance/g" /etc/glance/glance-api.conf


./conf_feeder.sh /etc/glance/glance-api.conf set database connection=mysql+pymysql://glance:$PASSWORD@$C_IP/glance



#◦In the [keystone_authtoken] and [paste_deploy] sections, configure Identity service access:
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken auth_uri=http://$C_IP:5000
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken auth_url=http://$C_IP:5000
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken memcached_servers=$C_IP:11211
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken auth_type=password
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken project_domain_name=default
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken user_domain_name=default
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken project_name=service
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken username=glance
./conf_feeder.sh /etc/glance/glance-api.conf set keystone_authtoken password=$PASSWORD


./conf_feeder.sh /etc/glance/glance-api.conf set paste_deploy flavor=keystone
#sed -i "s/#flavor = keystone/flavor = keystone/g" /etc/glance/glance-api.conf


#◦In the [glance_store] section, configure the local file system store and location of image files:
./conf_feeder.sh /etc/glance/glance-api.conf set glance_store stores=file,http
./conf_feeder.sh /etc/glance/glance-api.conf set glance_store default_store=file
./conf_feeder.sh /etc/glance/glance-api.conf set glance_store filesystem_store_datadir=/var/lib/glance/images



#3.Edit the /etc/glance/glance-registry.conf file and complete the following actions:
#◦In the [database] section, configure database access:
#sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/glance:$PASSWORD@$C_IP\/glance/g" /etc/glance/glance-registry.conf
./conf_feeder.sh /etc/glance/glance-registry.conf set database connection=mysql+pymysql://glance:$PASSWORD@$C_IP/glance


#◦In the [keystone_authtoken] and [paste_deploy] sections, configure Identity service access:
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken auth_uri=http://$C_IP:5000
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken auth_url=http://$C_IP:5000
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken memcached_servers=$C_IP:11211
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken auth_type=password
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken project_domain_name=default
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken user_domain_name=default
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken project_name=service
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken username=glance
./conf_feeder.sh /etc/glance/glance-registry.conf set keystone_authtoken password=$PASSWORD


./conf_feeder.sh /etc/glance/glance-registry.conf set paste_deploy flavor=keystone
#sed -i "s/#flavor = keystone/flavor = keystone/g" /etc/glance/glance-registry.conf


#4.Populate the Image service database:
su -s /bin/sh -c "glance-manage db_sync" glance

# Restart the Image services:
service glance-registry restart
service glance-api restart



# Download the source image:
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img

# Upload the image to the Image service using the QCOW2 disk format, bare container format, and public visibility so all projects can access it:
openstack image create "cirros" \
  --file cirros-0.3.5-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public





