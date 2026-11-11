#!/bin/bash
# Run as root in a fresh Arch WSL distribution, by bootstrap.ps1: creates the default user with
# sudo, sets the locale and makes the user WSL's default. Safe to run again.
set -euo pipefail

user="${1:?usage: arch-init.sh <user>}"

if [ ! -f /etc/pacman.d/gnupg/trustdb.gpg ]; then
  pacman-key --init
  pacman-key --populate archlinux
fi
pacman -Syu --needed --noconfirm sudo

id "$user" >/dev/null 2>&1 || useradd -m -G wheel "$user"
# A run cut short may have created the user without a password ("L" or "NP", not "P").
if [ "$(passwd -S "$user" | awk '{print $2}')" != P ]; then
  echo "Set a password for $user (used for sudo):"
  passwd "$user"
fi
echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf

printf '[user]\ndefault=%s\n' "$user" >/etc/wsl.conf
