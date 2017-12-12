#!/bin/bash

#This is installation for OpenStack Mitaka Release.


#Add Repository and update
apt install -y software-properties-common
add-apt-repository -y cloud-archive:ocata
apt update && apt -y upgrade

#openstack client 
apt -y install python-openstackclient

#reboot 



