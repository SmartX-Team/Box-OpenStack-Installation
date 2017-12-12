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



# Install & Configure MYSQL

debconf-set-selections <<< "mariadb-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
apt install -y mariadb-server python-pymysql

touch /etc/mysql/mariadb.conf.d/99-openstack.cnf

echo "[mysqld]" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "bind-address = $CH_C_INTERFACE_ADDRESS" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "default-storage-engine = innodb" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "innodb_file_per_table" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "max_connections  = 4096" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "collation-server = utf8_general_ci" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf
#echo "init-connect = 'SET NAMES utf8'" >> /etc/mysql/conf.d/mysqld_openstack.cnf
echo "character-set-server = utf8" >> /etc/mysql/mariadb.conf.d/99-openstack.cnf

service mysql restart

echo -e "$MYSQL_ROOT_PASSWORD\nn\ny\ny\ny\ny" | mysql_secure_installation


# Install & Configure MongoDB

#sudo apt-get install -y mongodb-server mongodb-clients python-pymongo

#sed -i "s/bind_ip = 127.0.0.1/bind_ip = $CH_C_INTERFACE_ADDRESS/g" /etc/mongodb.conf

# By default, MongoDB Crete serveral 1 GB journal files in the /var/lib/mongodb/journal directory.
# If you want to reduce the size of each journal file to 128 MB and limit total journal space consumption to 512 MB, assert the smallfiles key: 
# sed -i "s/journal=true/journal=true\n smallfiles=true/g" /etc/mongodb.conf

#service mongodb restart


# Intall & Configure RabbitMQ

apt install -y rabbitmq-server

rabbitmqctl add_user openstack $RABBITMQ_PASSWORD
rabbitmqctl set_permissions openstack ".*" ".*" ".*"


# Install & configure Memcached

apt install -y memcached python-memcache

sed -i "s/127.0.0.1/$CH_C_INTERFACE_ADDRESS/g" /etc/memcached.conf

systemctl restart memcached


