#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


M_IP=10.10.1.53
C_IP=10.10.10.53
D_IP=10.10.20.53
#RABBIT_PASS=secrete
PASSWORD=PASS
#ADMIN_TOKEN=ADMIN
#MAIL=jshan@nm.gist.ac.kr


# Install and Configure Workflow Service

apt-get install python-dev python-setuptools libffi-dev \
  libxslt1-dev libxml2-dev libyaml-dev libssl-dev

apt-get install python-tox

#Download source code
git clone https://git.openstack.org/openstack/mistral.git

#go to the directory
cd mistral

# compile  
pip install -e .

pip install --upgrade oslo.serialization

oslo-config-generator --config-file tools/config/config-generator.mistral.conf --output-file etc/mistral.conf




#1.To create the database, complete these steps:
cat << EOF | mysql -uroot -p$PASSWORD
CREATE DATABASE mistral;
GRANT ALL PRIVILEGES ON mistral.* TO 'mistral'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON mistral.* TO 'mistral'@'%' IDENTIFIED BY '$PASSWORD';
quit
EOF


source admin-openrc.sh

#◦Create the heat user:
openstack user create --domain default --password $PASSWORD mistral

#◦Add the admin role to the heat user:
openstack role add --project service --user mistral admin

#◦Create the heat and heat-cfn service entities:
openstack service create --name mistral \
  --description "Workflow Service" workflowv2


#4.Create the Orchestration service API endpoints:
openstack endpoint create --region RegionOne \
  workflowv2 public http://$C_IP:8989/v2

openstack endpoint create --region RegionOne \
  workflowv2 internal http://$C_IP:8989/v2

 openstack endpoint create --region RegionOne \
  workflowv2 admin http://$C_IP:8989/v2



mistral-db-manage --config-file etc/mistral.conf upgrade head

python tools/sync_db.py --config-file etc/mistral.conf

mistral-server --config-file etc/mistral.conf --server engine,api,executor



