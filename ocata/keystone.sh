#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


# CH_M_INTERFACE_ADDRESS=210.125.84.51
# CH_C_INTERFACE_ADDRESS=192.168.88.51
# CH_D_INTERFACE_ADDRESS=10.10.20.51
#RABBIT_PASS=secrete
# PASSWORD=fn!xo!ska!
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr



# Install & Configure Keystone


# Configure Mysql DB

cat << EOF | mysql -uroot -p$MYSQL_ROOT_PASSWORD
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DB_PASSWORD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DB_PASSWORD';
quit
EOF


#2.Run the following command to install the packages
apt -y install keystone

#3.Edit the /etc/keystone/keystone.conf file and complete the following actions

#◦In the [database] section, configure database access:
sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/keystone:$KEYSTONE_DB_PASSWORD@$CH_C_INTERFACE_ADDRESS\/keystone/g" /etc/keystone/keystone.conf

#◦In the [token] section, configure the Fernet token provider:
sed -i "s/#provider = fernet/provider = fernet/g" /etc/keystone/keystone.conf


#4.Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone

#5.Initialize Fernet keys:

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

#5.Bootstrap the Identity service:
keystone-manage bootstrap --bootstrap-password $OPENSTACK_ADMIN_USER_PASSWORD \
  --bootstrap-admin-url http://$CH_C_INTERFACE_ADDRESS:35357/v3/ \
  --bootstrap-internal-url http://$CH_C_INTERFACE_ADDRESS:35357/v3/ \
  --bootstrap-public-url http://$CH_C_INTERFACE_ADDRESS:5000/v3/ \
  --bootstrap-region-id $REGION_NAME

#1.Restart the Apache service and remove the default SQLite database:
systemctl restart apache2.service
rm -f /var/lib/keystone/keystone.db

#2.Configure the administrative account
export OS_USERNAME=admin
export OS_PASSWORD=$OPENSTACK_ADMIN_USER_PASSWORD
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$CH_C_INTERFACE_ADDRESS:35357/v3
export OS_IDENTITY_API_VERSION=3




#3.This guide uses a service project that contains a unique user for each service that you add to your environment. Create the service project:
openstack project create --domain default \
  --description "Service Project" service

#4.Regular (non-admin) tasks should use an unprivileged project and user. As an example, this guide creates the demo project and user.
#◦Create the demo project:
openstack project create --domain default \
  --description "Demo Project" demo

#◦Create the demo user:
openstack user create --domain default \
  --password $OPENSTACK_DEMO_USER_PASSWORD demo

#◦Create the user role:
openstack role create user

#◦Add the user role to the demo project and user:
openstack role add --project demo --user demo user


#Unset the temporary OS_TOKEN and OS_URL environment variables:
unset OS_URL

#1.Edit the admin-openrc file and add the following content:
touch admin-openrc.sh
echo "export OS_PROJECT_DOMAIN_NAME=default" >> admin-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> admin-openrc.sh
echo "export OS_USERNAME=admin" >> admin-openrc.sh
echo "export OS_PASSWORD=$OPENSTACK_ADMIN_USER_PASSWORD" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$CH_C_INTERFACE_ADDRESS:35357/v3" >> admin-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> admin-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> admin-openrc.sh

#2.Edit the demo-openrc file and add the following content:
touch demo-openrc.sh
echo "export OS_PROJECT_DOMAIN_NAME=default" >> demo-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> demo-openrc.sh
echo "export OS_PROJECT_NAME=demo" >> demo-openrc.sh
echo "export OS_USERNAME=demo" >> demo-openrc.sh
echo "export OS_PASSWORD=$OPENSTACK_DEMO_USER_PASSWORD" >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$CH_C_INTERFACE_ADDRESS:5000/v3" >> demo-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> demo-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> demo-openrc.sh




