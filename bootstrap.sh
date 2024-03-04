#!/bin/sh

set -ex

# On Ubuntu 22, e.g. WSL 2 distro, might need this:
# sudo apt-add-repository ppa:ansible/ansible
# To get an updated version

echo "----- Installing Python3 and Ansible -------------"
sudo apt update
sudo apt install python3 python3-pip ansible
echo "--------------------------------------------------"
echo "----- Installing Ansible collections -------------"
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
echo "--------------------------------------------------"
