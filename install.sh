#!/usr/bin/env bash
# install.sh – Full Arch setup script

set -o pipefail

# -------------------------------------------------
# 0) Script must run with sudo
# -------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Run with: sudo ./install.sh"
  exit 1
fi

SUDO_USER="${SUDO_USER:-root}"
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

if [ -z "$USER_HOME" ]; then
  echo "ERROR: Could not find home directory for $SUDO_USER"
  exit 1
fi

SCRIPT_PATH="$(readlink -f "$0")"
DIR="$(dirname "$SCRIPT_PATH")"
BASENAME="$(basename "$DIR")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

echo "Running as root for user: $SUDO_USER"
echo "User home: $USER_HOME"
echo "Script folder: $DIR"

# -------------------------------------------------
# Helper: Backup files with timestamp
# -------------------------------------------------
backup_file() {
  local f="$1"
  if [ -e "$f" ]; then
    cp -a "$f" "$f.backup.$(date +%Y%m%d%H%M%S)"
  fi
}

# -------------------------------------------------
# 1) Copy config files to ~/.config (user)
# -------------------------------------------------
echo "==> Copying files to $USER_HOME/.config"

sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config"

rsync -av \
  --exclude="$SCRIPT_NAME" \
  --exclude="mirrorlist" \
  --exclude="mkinitcpio.conf" \
  "$DIR/" "$USER_HOME/.config/"

chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"

# -------------------------------------------------
# 2) Autologin for iceol8ed
# -------------------------------------------------
echo "==> Enabling autologin for user iceol8ed on tty1"

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin iceol8ed --noclear %I \$TERM
EOF

systemctl daemon-reload

# -------------------------------------------------
# 3) Replace mirrorlist
# -------------------------------------------------
if [ -f "$DIR/mirrorlist" ]; then
  echo "==> Replacing /etc/pacman.d/mirrorlist"
  backup_file /etc/pacman.d/mirrorlist
  cp "$DIR/mirrorlist" /etc/pacman.d/mirrorlist
else
  echo "mirrorlist not found, skipping."
fi

# -------------------------------------------------
# 4) Full system refresh
# -------------------------------------------------
echo "==> pacman -Syyu"
pacman -Syyu --noconfirm --needed

# -------------------------------------------------
# 5) Replace mkinitcpio.conf and rebuild
# -------------------------------------------------
if [ -f "$DIR/mkinitcpio.conf" ]; then
  echo "==> Replacing /etc/mkinitcpio.conf & rebuilding"
  backup_file /etc/mkinitcpio.conf
  cp "$DIR/mkinitcpio.conf" /etc/mkinitcpio.conf
  mkinitcpio -P
else
  echo "mkinitcpio.conf not found, skipping."
fi

# -------------------------------------------------
# 6) Install paru dependencies
# -------------------------------------------------
echo "==> Installing paru prerequisites"
pacman -S --noconfirm --needed base-devel git rust

# -------------------------------------------------
# 7) Install paru (AUR)
# -------------------------------------------------
echo "==> Installing paru AUR helper"

PARU_TMP="/tmp/paru-build-$SUDO_USER"
sudo -u "$SUDO_USER" rm -rf "$PARU_TMP"
sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/paru.git "$PARU_TMP"
sudo -u "$SUDO_USER" bash -c "cd '$PARU_TMP' && makepkg -si --noconfirm"

# -------------------------------------------------
# 8) Install pacman packages
# -------------------------------------------------
PAC_PKGS=(
  hyprland
  xdg-desktop-portal
  hyprshot
  wl-clipboard
  mpv
  bemenu
  nvim
  foot
  swaybg
  polkit-kde-agent
  cliphist
  base-devel
  curl
  wget
  yazi
  fastfetch
  btop
  zip
  unzip
  zsh
  ttf-jetbrains-mono
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  noto-fonts-cjk
)

echo "==> Installing pacman packages"
for pkg in "${PAC_PKGS[@]}"; do
  pacman -S --noconfirm --needed "$pkg"
done

# -------------------------------------------------
# 9) Refresh font cache
# -------------------------------------------------
echo "==> Updating font cache"
fc-cache -fv

# -------------------------------------------------
# 10) Install AUR packages with paru
# -------------------------------------------------
AUR_PKGS=(
  ungoogled-chromium-bin
  localsend-bin
  bibata-cursor-theme-bin
  curd
)

echo "==> Installing AUR packages"
sudo -u "$SUDO_USER" paru -S --noconfirm --needed "${AUR_PKGS[@]}"

# -------------------------------------------------
# 11) Insecure sudoers NOPASSWD for ALL users
# -------------------------------------------------
echo "==> Adding NOPASSWD sudoers entry (INSECURE, as requested)"

cat >/etc/sudoers.d/99_nopasswd_all <<EOF
ALL ALL=(ALL) NOPASSWD: ALL
EOF

chmod 0440 /etc/sudoers.d/99_nopasswd_all
visudo -cf /etc/sudoers.d/99_nopasswd_all

# -------------------------------------------------
# 12) Change default shell to zsh
# -------------------------------------------------
echo "==> Changing shell to zsh for $SUDO_USER"
chsh -s "$(command -v zsh)" "$SUDO_USER"

# -------------------------------------------------
# 13) Delete the folder "archy"
# -------------------------------------------------
echo "==> Cleanup"

if [ "$BASENAME" = "archy" ]; then
  echo "Deleting directory: $DIR"
  cd /tmp
  rm -rf "$DIR"
else
  echo "Directory is not named archy, not deleting."
fi

echo "==> DONE!"
