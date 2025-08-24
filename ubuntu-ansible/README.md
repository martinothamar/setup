# Setup

Setup of my developer machine, developed against 

```bash
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Pop
Description:	Pop!_OS 22.04 LTS
Release:	22.04
Codename:	jammy

$ uname -a
Linux laptop 6.2.6-76060206-generic #202303130630~1689015125~22.04~ab2190e SMP PREEMPT_DYNAMIC Mon J x86_64 x86_64 x86_64 GNU/Linux
```

Probably only works for Ubuntu/Pop OS >= 22.04

## Run

```bash
# Init
./bootstrap.sh

# Don't have to setup everything like below,
# but should probably have ansible-lint from pip playbook under pkgs

# Setup everything
ansible-playbook setup.yml -K # K for sudo prompt

# ---------------------------------

# Setup only aliases
ansible-playbook playbooks/alias.yml
```

### Nix

https://github.com/DeterminateSystems/nix-installer


### LLVM

https://apt.llvm.org/

```bash
# sudo ./llvm.sh <version number> all
sudo ./llvm.sh 17 all
clang++-17 --version
```

### WSL

Use Ubuntu

Updated Ansible
```sh
sudo apt-add-repository ppa:ansible/ansible
```

Make sure systemd is enabled
```toml
[boot]
systemd=true
```

Then

```
ansible-playbook playbooks/pkgs/pip.yml -K
ansible-playbook playbooks/pkgs/apt.yml -K # Comment out what's not necessary
ansible-playbook playbooks/docker.yml -K
ansible-playbook playbooks/brew-install.yml -K # May need to run as sudo/root first
```
