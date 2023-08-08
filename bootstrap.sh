#!/bin/sh

sudo apt update
sudo apt install python3 python3-pip ansible
ansible-galaxy collection install community.general

