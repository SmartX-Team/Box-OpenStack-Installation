#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=10.10.1.107
C_IP=10.10.10.107
D_IP=10.10.20.107
#RABBIT_PASS=secrete
PASSWORD=PASS
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr



# Install & Configure Keystone


# Install & Configrue Memcached
sudo apt-get install -y memcached python-memcache
sed -i "s/-l 127.0.0.1/-l $C_IP/g" /etc/memcached.conf
service memcached restart


# Configure Mysql DB

cat << EOF | mysql -uroot -p$PASSWORD
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$PASSWORD';
quit
EOF

TOKEN=`openssl rand -hex 10`

#1.Disable the keystone service from starting automatically after installation
echo "manual" > /etc/init/keystone.override

#2.Run the following command to install the packages
sudo apt-get -y install keystone apache2 libapache2-mod-wsgi

#3.Edit the /etc/keystone/keystone.conf file and complete the following actions

#◦In the [DEFAULT] section, define the value of the initial administration token
sed -i "s/#admin_token = <None>/admin_token=$TOKEN/g" /etc/keystone/keystone.conf

#◦In the [database] section, configure database access:
sed -i "s/connection = sqlite:\/\/\/\/var\/lib\/keystone\/keystone.db/connection = mysql+pymysql:\/\/keystone:$PASSWORD@$C_IP\/keystone/g" /etc/keystone/keystone.conf

#◦In the [token] section, configure the Fernet token provider:
sed -i "s/#provider = uuid/provider = fernet/g" /etc/keystone/keystone.conf

sed -i "s/#verbose = True/verbose = True/g" /etc/keystone/keystone.conf

#4.Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone

#5.Initialize Fernet keys:
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone


#Configure the Apache HTTP server


#2.Create the /etc/apache2/sites-available/wsgi-keystone.conf file with the following content
echo "Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat \"%{cu}t %M\"
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat \"%{cu}t %M\"
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost> " > wsgi-keystone.conf
cp wsgi-keystone.conf /etc/apache2/sites-available/
rm wsgi-keystone.conf

#3.Enable the Identity service virtual hosts
ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled


#1.Restart the Apache HTTP server:
service apache2 restart

#2.By default, the Ubuntu packages create an SQLite database.
#Because this configuration uses an SQL database server, you can remove the SQLite database file:
rm -f /var/lib/keystone/keystone.db




#1.Configure the authentication token:
export OS_TOKEN=$TOKEN

#2.Configure the endpoint URL:
export OS_URL=http://$C_IP:35357/v3

#3.Configure the Identity API version:
export OS_IDENTITY_API_VERSION=3


# Create the service entity and API endpoints

#1.The Identity service manages a catalog of services in your OpenStack environment.
#Services use this catalog to determine the other services available in your environment.
#Create the service entity for the Identity service:
openstack service create \
  --name keystone --description "OpenStack Identity" identity

#Create the Identity service API endpoints:
openstack endpoint create --region RegionOne \
  identity public http://$C_IP:5000/v3

openstack endpoint create --region RegionOne \
  identity internal http://$C_IP:5000/v3

openstack endpoint create --region RegionOne \
  identity admin http://$C_IP:35357/v3



#1.Create the default domain:
openstack domain create --description "Default Domain" default

#2.Create an administrative project, user, and role for administrative operations in your environment:
#◦Create the admin project:
openstack project create --domain default \
  --description "Admin Project" admin

#◦Create the admin user:
openstack user create --domain default \
  --password $PASSWORD admin

#◦Create the admin role:
openstack role create admin

#◦Add the admin role to the admin project and user:
openstack role add --project admin --user admin admin

#3.This guide uses a service project that contains a unique user for each service that you add to your environment. Create the service project:
openstack project create --domain default \
  --description "Service Project" service

#4.Regular (non-admin) tasks should use an unprivileged project and user. As an example, this guide creates the demo project and user.
#◦Create the demo project:
openstack project create --domain default \
  --description "Demo Project" demo

#◦Create the demo user:
openstack user create --domain default \
  --password $PASSWORD demo

#◦Create the user role:
openstack role create user

#◦Add the user role to the demo project and user:
openstack role add --project demo --user demo user


#Unset the temporary OS_TOKEN and OS_URL environment variables:
unset OS_TOKEN OS_URL

#1.Edit the admin-openrc file and add the following content:
touch admin-openrc.sh
echo "export OS_PROJECT_DOMAIN_NAME=default" >> admin-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> admin-openrc.sh
echo "export OS_USERNAME=admin" >> admin-openrc.sh
echo "export OS_PASSWORD=$PASSWORD" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$C_IP:35357/v3" >> admin-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> admin-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> admin-openrc.sh

#2.Edit the demo-openrc file and add the following content:
touch demo-openrc.sh
echo "export OS_PROJECT_DOMAIN_NAME=default" >> demo-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> demo-openrc.sh
echo "export OS_PROJECT_NAME=demo" >> demo-openrc.sh
echo "export OS_USERNAME=demo" >> demo-openrc.sh
echo "export OS_PASSWORD=$PASSWORD" >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$C_IP:5000/v3" >> demo-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> demo-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> demo-openrc.sh


