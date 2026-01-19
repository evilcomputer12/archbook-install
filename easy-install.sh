#!/bin/bash
set +e

# =======================
# COLORS
# =======================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

msg() { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Arch Linux MacBook Air 2012 Installer                ║
║   MATE • LightDM • GRUB • Intel HD4000                 ║
╚══════════════════════════════════════════════════════════╝
EOF

# =======================
# ROOT CHECK
# =======================
if [[ $EUID -ne 0 ]]; then
  err "Run as root (sudo -i)"
  exit 1
fi

# =======================
# INTERNET
# =======================
info "Checking internet..."
ping -c 1 archlinux.org >/dev/null || {
  err "No internet connection"
  exit 1
}
msg "Internet OK"

# =======================
# USER INPUT
# =======================
read -p "Enter username: " USERNAME
while [[ -z "$USERNAME" ]]; do
  read -p "Username cannot be empty. Enter username: " USERNAME
done

read -s -p "Enter password for $USERNAME: " USER_PASS
echo
read -s -p "Confirm password: " USER_PASS2
echo
[[ "$USER_PASS" != "$USER_PASS2" ]] && err "Passwords do not match!" && exit 1

read -s -p "Enter ROOT password: " ROOT_PASS
echo
read -s -p "Confirm ROOT password: " ROOT_PASS2
echo
[[ "$ROOT_PASS" != "$ROOT_PASS2" ]] && err "Passwords do not match!" && exit 1

# =======================
# REGION SELECTION
# =======================
echo ""
echo "Select your region:"
select REGION in Europe America Asia Africa Australia UTC; do
  case $REGION in
    Europe) TIMEZONE="Europe/Skopje"; break ;;
    America) TIMEZONE="America/New_York"; break ;;
    Asia) TIMEZONE="Asia/Tokyo"; break ;;
    Africa) TIMEZONE="Africa/Cairo"; break ;;
    Australia) TIMEZONE="Australia/Sydney"; break ;;
    UTC) TIMEZONE="UTC"; break ;;
  esac
done

msg "Timezone set to $TIMEZONE"

# =======================
# DISK
# =======================
lsblk -d -o NAME,SIZE,MODEL
read -p "Disk to install on (e.g. sda): " DISK
DISK="/dev/$DISK"

warn "ALL DATA ON $DISK WILL BE ERASED!"
read -p "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && exit 1

# =======================
# PARTITION
# =======================
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux" "$DISK"

PART1="${DISK}1"
PART2="${DISK}2"

mkfs.fat -F32 "$PART1"
mkfs.ext4 -F "$PART2"

mount "$PART2" /mnt
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot

# =======================
# BASE INSTALL
# =======================
pacstrap /mnt \
  base base-devel linux linux-headers linux-firmware \
  nano vim git sudo networkmanager \
  intel-ucode efibootmgr grub \
  xorg-server xorg-xinit \
  mesa vulkan-intel \
  pipewire pipewire-pulse wireplumber \
  mate mate-extra \
  lightdm lightdm-gtk-greeter \
  broadcom-wl-dkms dkms \
  tlp powertop lm_sensors \
  firefox htop

genfstab -U /mnt >> /mnt/etc/fstab

# =======================
# CHROOT CONFIG
# =======================
arch-chroot /mnt /bin/bash << EOF

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "arch-macbook" > /etc/hostname

echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,audio,video,input,storage -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable tlp

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Intel graphics
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-intel.conf << INTEL
Section "Device"
    Identifier "Intel Graphics"
    Driver "modesetting"
    Option "TearFree" "true"
EndSection
INTEL

# Trackpad
cat > /etc/X11/xorg.conf.d/30-touchpad.conf << TOUCH
Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
TOUCH

# mbpfan
echo "applesmc" > /etc/modules-load.d/applesmc.conf

EOF

# =======================
# FINISH
# =======================
msg "Installation complete!"
msg "Desktop: MATE"
msg "Bootloader: GRUB"
msg "User: $USERNAME"
msg "Timezone: $TIMEZONE"

echo ""
warn "Remove USB and reboot"
read -p "Reboot now? (y/n): " R
[[ "$R" =~ ^[Yy]$ ]] && reboot
