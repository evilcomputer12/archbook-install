#!/bin/bash
#
# Arch Linux Installer for MacBook Air Mid 2012 (ALL-IN-ONE)
# - MATE desktop + LightDM
# - Intel HD4000 stack + TearFree
# - MacBook trackpad (libinput tap + natural scroll)
# - GRUB2 (traditional menu) + Mac-safe EFI fallback (BOOTX64.EFI)
# - Continues on errors (won't exit on missing packages)
#
# Run from Arch ISO:
#   chmod +x install.sh
#   sudo ./install.sh
#

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_msg() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

HOSTNAME_DEFAULT="macbook-arch"

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║   Arch Linux Installer - MacBook Air Mid 2012           ║
║   MATE + LightDM + GRUB2 (UEFI) + HD4000 + Trackpad     ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if [ "$EUID" -ne 0 ]; then
  print_error "Please run as root: sudo -i"
  exit 1
fi

print_info "Checking internet..."
if ! ping -c 1 archlinux.org &> /dev/null; then
  print_error "No internet! Connect WiFi first (iwctl) and retry."
  exit 1
fi
print_msg "Internet connected!"

print_info "Syncing clock..."
timedatectl set-ntp true || true
print_msg "Clock synced!"

echo ""
read -p "Enter hostname [${HOSTNAME_DEFAULT}]: " HOSTNAME
HOSTNAME="${HOSTNAME:-$HOSTNAME_DEFAULT}"

while true; do
  read -p "Enter username (lowercase recommended): " USERNAME
  [[ -n "$USERNAME" ]] && break
done

echo ""
print_info "Set passwords now:"
read -s -p "Enter ROOT password: " ROOT_PASS; echo
read -s -p "Confirm ROOT password: " ROOT_PASS2; echo
if [ "$ROOT_PASS" != "$ROOT_PASS2" ]; then
  print_error "Root passwords don't match!"
  exit 1
fi

echo ""
read -s -p "Enter password for user '${USERNAME}': " USER_PASS; echo
read -s -p "Confirm password for '${USERNAME}': " USER_PASS2; echo
if [ "$USER_PASS" != "$USER_PASS2" ]; then
  print_error "User passwords don't match!"
  exit 1
fi
print_msg "Passwords set!"

echo ""
print_info "Select your region (timezone):"
echo "1) Europe/Skopje"
echo "2) Europe/London"
echo "3) Europe/Berlin"
echo "4) America/New_York"
echo "5) America/Los_Angeles"
echo "6) Asia/Tokyo"
echo "7) UTC"
echo "8) Custom (type it)"
read -p "Choose [1-8]: " TZ_CHOICE

case "$TZ_CHOICE" in
  1) TIMEZONE="Europe/Skopje" ;;
  2) TIMEZONE="Europe/London" ;;
  3) TIMEZONE="Europe/Berlin" ;;
  4) TIMEZONE="America/New_York" ;;
  5) TIMEZONE="America/Los_Angeles" ;;
  6) TIMEZONE="Asia/Tokyo" ;;
  7) TIMEZONE="UTC" ;;
  8)
     read -p "Enter timezone (example: Europe/Paris): " TIMEZONE
     ;;
  *) TIMEZONE="Europe/Skopje" ;;
esac
print_msg "Timezone: $TIMEZONE"

echo ""
print_info "Available disks:"
lsblk -d -o NAME,SIZE,MODEL
echo ""

read -p "Enter disk to install on (e.g., sda): " DISK_NAME
DISK="/dev/${DISK_NAME}"

if [ ! -b "$DISK" ]; then
  print_error "Disk $DISK not found!"
  exit 1
fi

echo ""
print_warning "This will ERASE ALL DATA on $DISK!"
read -p "Type 'YES' to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  print_error "Cancelled."
  exit 1
fi

# Partition naming
if [[ "$DISK" == *"nvme"* ]]; then
  PART_EFI="${DISK}p1"
  PART_ROOT="${DISK}p2"
else
  PART_EFI="${DISK}1"
  PART_ROOT="${DISK}2"
fi

umount -R /mnt 2>/dev/null || true

echo ""
print_info "[1/9] Partitioning (UEFI: EFI + root)..."
wipefs -af "$DISK" || true
sgdisk --zap-all "$DISK" || true
sgdisk -o "$DISK" || true
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK" || true
sgdisk -n 2:0:0     -t 2:8300 -c 2:"LinuxRoot" "$DISK" || true
sleep 2
partprobe "$DISK" || true
sleep 2
print_msg "Disk partitioned!"

echo ""
print_info "[2/9] Formatting partitions..."
mkfs.fat -F32 "$PART_EFI" || true
mkfs.ext4 -F "$PART_ROOT" || true
print_msg "Partitions formatted!"

echo ""
print_info "[3/9] Mounting partitions (EFI at /boot/efi — recommended)..."
mount "$PART_ROOT" /mnt || true
mkdir -p /mnt/boot/efi
mount "$PART_EFI" /mnt/boot/efi || true
print_msg "Mounted root at /mnt and EFI at /mnt/boot/efi"

echo ""
print_info "[4/9] Installing base system..."
pacstrap -K /mnt \
  base base-devel \
  linux linux-headers linux-firmware \
  intel-ucode \
  nano vim git wget curl \
  networkmanager \
  sudo efibootmgr \
  dosfstools mtools \
  htop || true
print_msg "Base installed!"

echo ""
print_info "[5/9] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || true
print_msg "fstab generated!"

print_info "[6/9] Creating chroot setup script..."
cat > /mnt/root/setup.sh << SETUP_SCRIPT
#!/bin/bash
set +e

USERNAME="${USERNAME}"
HOSTNAME="${HOSTNAME}"
TIMEZONE="${TIMEZONE}"
ROOT_PASS="${ROOT_PASS}"
USER_PASS="${USER_PASS}"
DISK_NAME="${DISK_NAME}"

echo "[A] Timezone + clock..."
ln -sf "/usr/share/zoneinfo/\${TIMEZONE}" /etc/localtime || true
hwclock --systohc || true

echo "[B] Locale..."
grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "[C] Hostname..."
echo "\${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   \${HOSTNAME}.localdomain \${HOSTNAME}
EOF

echo "[D] Pacman tweaks + multilib..."
sed -i 's/^#Color/Color/' /etc/pacman.conf || true
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || true
# Enable multilib (Wine/32-bit libs)
sed -i '/^\[multilib\]/,/^Include/s/^#//' /etc/pacman.conf || true
pacman -Sy || true

echo "[E] Users + sudo..."
echo "root:\${ROOT_PASS}" | chpasswd || true
id -u "\${USERNAME}" &>/dev/null || useradd -m -G wheel,audio,video,input,storage,optical -s /bin/bash "\${USERNAME}"
echo "\${USERNAME}:\${USER_PASS}" | chpasswd || true
# Temporary NOPASSWD for installs, reverted at end
grep -q '^%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers || echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "[F] Enable NetworkManager..."
systemctl enable NetworkManager || true

echo "[G] Desktop + display manager (MATE + LightDM)..."
pacman -S --noconfirm --needed \
  xorg-server xorg-xinit xorg-xrandr \
  xf86-input-libinput libinput \
  mate mate-extra \
  lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  gvfs gvfs-mtp file-roller \
  network-manager-applet || true

# LightDM greeter
sed -i 's/^#greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf 2>/dev/null || true
systemctl enable lightdm || true

echo "[H] Audio (PipeWire)..."
pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-pulse wireplumber || true

echo "[I] Intel HD4000 graphics stack (safe defaults)..."
# modesetting is the recommended Xorg driver for HD4000; intel ddx kept as optional fallback
pacman -S --noconfirm --needed \
  mesa lib32-mesa \
  vulkan-intel lib32-vulkan-intel \
  intel-media-driver libva-intel-driver libva-utils \
  xf86-video-intel || true

mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-intel.conf << 'INTELCONF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "modesetting"
    Option "TearFree" "true"
EndSection
INTELCONF

echo "[J] Trackpad config (tap-to-click + natural scroll)..."
cat > /etc/X11/xorg.conf.d/30-touchpad.conf << 'TP'
Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection
TP

echo "[K] MacBook hardware support (WiFi, power, sensors, bluetooth)..."
pacman -S --noconfirm --needed \
  broadcom-wl-dkms dkms linux-headers \
  tlp tlp-rdw powertop \
  lm_sensors acpi thermald smartmontools ethtool \
  bluez bluez-utils || true

cat > /etc/modprobe.d/macbook-broadcom.conf << 'MODCONF'
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcm43xx
blacklist brcm80211
blacklist brcmfmac
blacklist brcmsmac
blacklist bcma
MODCONF

echo "applesmc" > /etc/modules-load.d/applesmc.conf

systemctl enable bluetooth || true
systemctl enable tlp || true
systemctl enable thermald || true

echo "[L] Base apps..."
pacman -S --noconfirm --needed firefox ntfs-3g unzip zip p7zip unrar okular poppler-data || true

echo "[M] GRUB2 (UEFI) + Mac-safe fallback..."
pacman -S --noconfirm --needed grub efibootmgr os-prober || true

# Ensure EFI vars are available (sometimes needed in chroot)
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# EFI is mounted at /boot/efi (from the installer)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck || true

# Make a visible, selectable menu
grep -q '^GRUB_TIMEOUT=' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub || echo 'GRUB_TIMEOUT=5' >> /etc/default/grub
grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub && sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub && sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"/' /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg || true

# Mac firmware sometimes ignores NVRAM entries -> add fallback BOOTX64.EFI
# This makes the bootloader discoverable even if the GRUB entry doesn't stick.
if [ -f /boot/efi/EFI/GRUB/grubx64.efi ]; then
  mkdir -p /boot/efi/EFI/BOOT
  cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI || true
fi

echo "[N] Restore normal sudo behavior..."
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || true

echo "[O] Done."
SETUP_SCRIPT

chmod +x /mnt/root/setup.sh || true

print_info "[7/9] Running configuration in chroot..."
arch-chroot /mnt /root/setup.sh || true
rm -f /mnt/root/setup.sh || true
print_msg "Chroot configuration finished!"

echo ""
print_msg "╔════════════════════════════════════════════════════╗"
print_msg "║      INSTALLATION COMPLETE                          ║"
print_msg "╚════════════════════════════════════════════════════╝"
echo ""
print_msg "Desktop: MATE + LightDM"
print_msg "Bootloader: GRUB2 (UEFI) + fallback BOOTX64.EFI (Mac-safe)"
print_msg "User: $USERNAME"
print_msg "Timezone: $TIMEZONE"
echo ""

print_warning "Reboot required. Remove USB when it restarts."
read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  umount -R /mnt || true
  reboot
else
  print_info "When ready: umount -R /mnt && reboot"
fi
