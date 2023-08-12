#!/bin/sh

set -ex

echo "----- Installing Python3 and Ansible -------------"
sudo apt update
sudo apt install python3 python3-pip ansible
echo "--------------------------------------------------"
echo "----- Installing Ansible collections -------------"
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
echo "--------------------------------------------------"
