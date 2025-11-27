#!/bin/bash

set -e

# Retry function for commands that may fail
retry_cmd() {
  local attempts=5
  local delay=3
  local n=1

  while true; do
    "$@" && break || {
      if [[ $n -lt $attempts ]]; then
        echo "[!] Command failed. Retry $n/$attempts..."
        sleep $delay
        ((n++))
      else
        echo "[!] Command failed after $attempts attempts. Exiting."
        exit 1
      fi
    }
  done
}

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
USER="iceol8ed"

echo "[*] Copying dotfiles to ~/.config ..."
mkdir -p "/home/$USER/.config"

shopt -s dotglob
for item in "$SCRIPT_DIR"/*; do
  base="$(basename "$item")"
  # Skip the script and special files
  if [[ "$base" == "install.sh" ]] || [[ "$base" == "mirrorlist" ]] || [[ "$base" == "mkinitcpio.conf" ]]; then
    continue
  fi
  cp -r "$item" "/home/$USER/.config/"
done
shopt -u dotglob

chown -R "$USER:$USER" "/home/$USER/.config"

echo "[*] Enabling autologin for $USER ..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I 38400 linux
EOF

echo "[*] Replacing mirrorlist ..."
cp "$SCRIPT_DIR/mirrorlist" /etc/pacman.d/mirrorlist

echo "[*] Updating system ..."
pacman -Syyu --noconfirm

echo "[*] Replacing mkinitcpio.conf and rebuilding initramfs ..."
cp "$SCRIPT_DIR/mkinitcpio.conf" /etc/mkinitcpio.conf
mkinitcpio -P

echo "[*] Installing base packages ..."
retry_cmd pacman -S --noconfirm --needed \
  hyprland xdg-desktop-portal-hyprland hyprshot wl-clipboard mpv \
  bemenu nvim foot swaybg polkit-kde-agent cliphist fastfetch \
  btop zip unzip zsh ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
  noto-fonts noto-fonts-emoji noto-fonts-cjk curl wget base-devel yazi

echo "[*] Installing paru (AUR helper) ..."
cd /home/$USER
git clone https://aur.archlinux.org/paru.git
chown -R "$USER:$USER" paru
cd paru
sudo -u "$USER" makepkg -si --noconfirm
cd ..
rm -rf paru

echo "[*] Running fc-cache ..."
fc-cache -fv

echo "[*] Installing AUR packages with paru ..."
retry_cmd sudo -u "$USER" paru -S --noconfirm \
  ungoogled-chromium-bin localsend-bin bibata-cursor-theme-bin curd

echo "[*] Adding NOPASSWD to sudoers (insecure!) ..."
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >>/etc/sudoers

echo "[*] Changing default shell to zsh ..."
chsh -s /bin/zsh "$USER"

echo "[*] Installing Prezto framework ..."
sudo -u "$USER" zsh -c '
set -e
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/z*; do
    ln -sf "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done
'

echo "[*] Configuring auto-launch of Hyprland on login ..."
# Add to .zprofile to start Hyprland when a TTY is opened
sudo -u "$USER" bash -c 'echo "
if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then
    exec Hyprland
fi
" >> /home/'"$USER"'/.zprofile'

echo "[*] Cleaning up: deleting script folder ..."
cd /
rm -rf "$SCRIPT_DIR"

echo "[*] Done!"
