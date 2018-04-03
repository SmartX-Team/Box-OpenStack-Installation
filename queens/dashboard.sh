#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


source env-setup.sh

#1.Install the packages:
apt install -y openstack-dashboard

#2.Edit the /etc/openstack-dashboard/local_settings.py file and complete the following actions:
sed -i 's/OPENSTACK_HOST = "127.0.0.1"/OPENSTACK_HOST = "'$CH_C_INTERFACE_ADDRESS'"/g' /etc/openstack-dashboard/local_settings.py

#◦In the Dashboard configuration section, allow your hosts to access Dashboard:
sed -i "s/ALLOWED_HOSTS = '\*'/ALLOWED_HOSTS = \['\*', \]/g" /etc/openstack-dashboard/local_settings.py
#ALLOWED_HOSTS can also be ['*'] to accept all hosts. This may be useful for development work, but is potentially insecure and should not be used in production. See the Django documentation for further information.


#◦Configure the memcached session storage service:
sed -i "s/# memcached set CACHES to something like/# memcached set CACHES to something like\n\
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'/g" /etc/openstack-dashboard/local_settings.py

sed -i "s/'LOCATION': '127.0.0.1:11211'/'LOCATION': '$CH_C_INTERFACE_ADDRESS:11211'/g" /etc/openstack-dashboard/local_settings.py

#◦Enable the Identity API version 3:
#sed -i "s/http:\/\/%s:5000\/v2.0/http:\/\/%s:5000\/v3/g" /etc/openstack-dashboard/local_settings.py

#◦Enable support for domains:
sed -i "s/#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True/g" /etc/openstack-dashboard/local_settings.py


#◦Configure API versions:
sed -i 's/#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/g' /etc/openstack-dashboard/local_settings.py
sed -i 's/#    "data-processing": 1.1,/"identity": 3,/g' /etc/openstack-dashboard/local_settings.py
sed -i 's/#    "identity": 3,/"image": 2,/g' /etc/openstack-dashboard/local_settings.py
sed -i 's/#    "volume": 2,/"volume": 2,/g' /etc/openstack-dashboard/local_settings.py
sed -i 's/#    "compute": 2,/}/g' /etc/openstack-dashboard/local_settings.py


#◦Configure Default as the default domain for users that you create via the dashboard:
sed -i "s/#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'default'/g" /etc/openstack-dashboard/local_settings.py

#◦Configure user as the default role for users that you create via the dashboard:
sed -i 's/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "_member_"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"/g' /etc/openstack-dashboard/local_settings.py


sed -i "s/'enable_distributed_router': False,/'enable_distributed_router': True,/g" /etc/openstack-dashboard/local_settings.py



#permission Error Issue
#chown www-data /var/lib/openstack-dashboard/secret_key

#•Reload the web server configuration:
systemctl reload apache2.service

