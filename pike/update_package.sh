
#This is installation for OpenStack Mitaka Release.


#Add Repository and update
apt install -y software-properties-common
add-apt-repository -y cloud-archive:pike

apt-get update && apt-get -y upgrade

#openstack client 
apt-get -y install python-openstackclient

#reboot 



