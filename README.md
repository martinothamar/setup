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
# Setup everything
ansible-playbook setup.yml -K # K for sudo prompt

# ---------------------------------

# Setup only aliases
ansible-playbook playbooks/alias.yml
```
