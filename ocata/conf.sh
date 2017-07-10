#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=210.114.90.172
C_IP=172.20.90.172
D_IP=172.30.90.172
#RABBIT_PASS=secrete
PASSWORD=fn!xo!ska!
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr




#sed -i "s/#admin_token = <None>/admin_token=$TOKEN/g" /etc/keystone/keystone.conf

#◦In the [database] section, configure database access:
sed -i "s/#connection = <None>/connection = mysql+pymysql:\/\/keystone:$PASSWORD@$C_IP\/keystone/g" /etc/keystone/keystone.conf

#◦In the [token] section, configure the Fernet token provider:
sed -i "s/#provider = fernet/provider = fernet/g" /etc/keystone/keystone.conf

#sed -i "s/#verbose = True/verbose = True/g" /etc/keystone/keystone.conf

