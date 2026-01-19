#!/bin/bash
#
# Arch Linux Installer for MacBook Air Mid 2012
# BASE INSTALL (from Arch ISO) + drops a POST-INSTALL script in the new user home
#
# Base installs:
# - MATE Desktop
# - LightDM + **Slick Greeter** (nice-looking greeter)  0
# - Intel HD4000 stack + modesetting TearFree
# - MacBook trackpad (libinput tap + natural scroll)
# - Broadcom WiFi DKMS + bluetooth
# - TLP + thermald
# - **GRUB2 traditional menu** + Mac-safe EFI fallback (BOOTX64.EFI)
#
# Post-install (run AFTER first boot, as your normal user):
# - Microsoft Edge, mbpfan, VS Code, GitHub Desktop, Android Studio, Flutter
# - VirtualBox, QEMU/KVM, Wine, Docker
# - Fonts (MS + others), LibreOffice, VLC, Spotify, WhatsApp, Viber, Teams, etc.
#
# Continues on errors - won't exit on missing packages
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
TIMEZONE_DEFAULT="Europe/Skopje"

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║   Arch Linux Installer - MacBook Air Mid 2012           ║
║   MATE + LightDM (Slick) + GRUB + HD4000 + Trackpad     ║
║   Creates: ~/postinstall.sh (Edge + mbpfan + Dev + VM)  ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if [ "$EUID" -ne 0 ]; then
  print_error "Please run as root: sudo -i"
  exit 1
fi

print_info "Checking internet..."
if ! ping -c 1 archlinux.org &> /dev/null; then
  print_error "No internet! Connect WiFi first:"
  echo ""
  echo "  iwctl"
  echo "  station wlan0 scan"
  echo "  station wlan0 get-networks"
  echo "  station wlan0 connect \"YourWiFi\""
  echo "  exit"
  echo ""
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
print_info "Select your region/timezone:"
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
  8) read -p "Enter timezone (example: Europe/Paris): " TIMEZONE ;;
  *) TIMEZONE="$TIMEZONE_DEFAULT" ;;
esac
print_msg "Timezone set: $TIMEZONE"

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
print_info "[1/7] Partitioning $DISK (UEFI: EFI + root)..."
wipefs -af "$DISK" || true
sgdisk --zap-all "$DISK" || true
sgdisk -o "$DISK" || true
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK" || true
sgdisk -n 2:0:0     -t 2:8300 -c 2:"LinuxRoot" "$DISK" || true
sleep 2
partprobe "$DISK" || true
sleep 2
print_msg "Disk partitioned!"

print_info "[2/7] Formatting partitions..."
mkfs.fat -F32 "$PART_EFI" || true
mkfs.ext4 -F "$PART_ROOT" || true
print_msg "Partitions formatted!"

print_info "[3/7] Mounting partitions (EFI -> /boot/efi)..."
mount "$PART_ROOT" /mnt || true
mkdir -p /mnt/boot/efi
mount "$PART_EFI" /mnt/boot/efi || true
print_msg "Partitions mounted!"

print_info "[4/7] Updating mirrors..."
if command -v reflector &> /dev/null; then
  reflector --country Germany,France,Netherlands --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
fi
print_msg "Mirrors updated!"

print_info "[5/7] Installing base + desktop + MacBook essentials..."
pacstrap -K /mnt \
  base base-devel \
  linux linux-headers linux-firmware intel-ucode \
  nano vim git wget curl \
  networkmanager network-manager-applet \
  sudo efibootmgr grub os-prober \
  dosfstools mtools htop \
  xorg-server xorg-xinit xorg-xrandr \
  xf86-input-libinput libinput \
  mesa vulkan-intel intel-media-driver libva-intel-driver libva-utils \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  mate mate-extra \
  lightdm lightdm-slick-greeter \
  gvfs gvfs-mtp file-roller \
  broadcom-wl-dkms dkms \
  tlp tlp-rdw powertop \
  lm_sensors acpi thermald smartmontools ethtool \
  bluez bluez-utils \
  firefox \
  ntfs-3g unzip zip p7zip unrar \
  okular poppler-data || true
print_msg "Base system installed!"

print_info "[6/7] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || true
print_msg "fstab generated!"

print_info "[7/7] Creating and running chroot configuration script..."
cat > /mnt/root/setup.sh << SETUP_SCRIPT
#!/bin/bash
set +e

USERNAME="${USERNAME}"
HOSTNAME="${HOSTNAME}"
TIMEZONE="${TIMEZONE}"
ROOT_PASS="${ROOT_PASS}"
USER_PASS="${USER_PASS}"

echo "[A] Timezone & clock..."
ln -sf "/usr/share/zoneinfo/\${TIMEZONE}" /etc/localtime || true
hwclock --systohc || true

echo "[B] Locale..."
grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "[C] Hostname & hosts..."
echo "\${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   \${HOSTNAME}.localdomain \${HOSTNAME}
EOF

echo "[D] Pacman tweaks + multilib..."
sed -i 's/^#Color/Color/' /etc/pacman.conf || true
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || true
sed -i '/^\[multilib\]/,/^Include/s/^#//' /etc/pacman.conf || true
pacman -Sy || true

echo "[E] Users + sudo..."
echo "root:\${ROOT_PASS}" | chpasswd || true
id -u "\${USERNAME}" &>/dev/null || useradd -m -G wheel,audio,video,input,storage,optical -s /bin/bash "\${USERNAME}"
echo "\${USERNAME}:\${USER_PASS}" | chpasswd || true

# Temporary NOPASSWD for postinstall convenience (we revert in postinstall)
grep -q '^%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers || echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "[F] Enable services..."
systemctl enable NetworkManager || true
systemctl enable bluetooth || true
systemctl enable tlp || true
systemctl enable thermald || true

echo "[G] LightDM + Slick Greeter config..."
# Set slick greeter as default  1
sed -i 's/^#greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf 2>/dev/null || true
grep -q '^greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf 2>/dev/null || \
  echo 'greeter-session=lightdm-slick-greeter' >> /etc/lightdm/lightdm.conf
systemctl enable lightdm || true

# Nice slick greeter defaults (simple + clean). You can change background later.
cat > /etc/lightdm/slick-greeter.conf << 'SLICK'
[Greeter]
background=/usr/share/backgrounds/mate/desktop/Stripes.png
theme-name=Adwaita
icon-theme-name=Adwaita
font-name=Sans 11
draw-user-backgrounds=false
show-a11y=false
show-keyboard=false
show-hostname=true
show-power=true
show-clock=true
clock-format=%a %d %b %H:%M
SLICK

echo "[H] Intel HD4000 + 'if missing then install' safety..."
# Always ensure these are present (pacman --needed is safe)
pacman -S --noconfirm --needed \
  mesa lib32-mesa \
  vulkan-intel lib32-vulkan-intel \
  intel-media-driver libva-intel-driver libva-utils \
  xf86-video-intel || true

# Recommended: modesetting (stable) + TearFree
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-intel.conf << 'INTELCONF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "modesetting"
    Option "TearFree" "true"
EndSection
INTELCONF

echo "[I] MacBook trackpad (libinput tap-to-click + natural scroll)..."
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

echo "[J] Broadcom blacklist + Apple SMC..."
cat > /etc/modprobe.d/macbook-broadcom.conf << 'MOD'
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcm43xx
blacklist brcm80211
blacklist brcmfmac
blacklist brcmsmac
blacklist bcma
MOD

echo "applesmc" > /etc/modules-load.d/applesmc.conf

echo "[K] GRUB2 (traditional selectable menu) + Mac-safe fallback..."
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# EFI is mounted at /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck || true

# Traditional menu
grep -q '^GRUB_TIMEOUT=' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub || echo 'GRUB_TIMEOUT=5' >> /etc/default/grub
grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub && sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub && sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"/' /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg || true

# Mac firmware can ignore NVRAM entries -> fallback path helps boot reliably
if [ -f /boot/efi/EFI/GRUB/grubx64.efi ]; then
  mkdir -p /boot/efi/EFI/BOOT
  cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI || true
fi

echo "[L] Done."
SETUP_SCRIPT

chmod +x /mnt/root/setup.sh || true
arch-chroot /mnt /root/setup.sh || true
rm -f /mnt/root/setup.sh || true

# ----------------------------
# Create POST-INSTALL script
# ----------------------------
print_info "Writing post-install script to /home/${USERNAME}/postinstall.sh ..."

cat > "/mnt/home/${USERNAME}/postinstall.sh" << 'POSTINSTALL'
#!/bin/bash
#
# Post-Install Extras for MacBook Air 2012 (run as NORMAL USER)
# Installs: Edge, mbpfan, VS Code, GitHub Desktop, Android Studio, Flutter,
#           VirtualBox, QEMU/KVM, Wine, Docker, Fonts, Office, Media, Messaging
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

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║   Post-Install (Extras) - MacBook Air Mid 2012          ║
║   Edge • mbpfan • Dev • Virtualization • Fonts • Media  ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if [ "$EUID" -eq 0 ]; then
  print_error "Don't run as root! Run as your normal user."
  exit 1
fi

print_info "Checking internet..."
ping -c 1 archlinux.org &> /dev/null || { print_error "No internet connection!"; exit 1; }
print_msg "Internet connected!"

print_info "Ensuring multilib enabled..."
sudo sed -i '/^\[multilib\]/,/^Include/s/^#//' /etc/pacman.conf || true
sudo pacman -Sy || true
print_msg "multilib ready"

print_info "Installing yay (AUR helper) if needed..."
if ! command -v yay &> /dev/null; then
  cd /tmp || true
  git clone https://aur.archlinux.org/yay-bin.git || true
  cd yay-bin || true
  makepkg -si --noconfirm || true
  cd ~ || true
fi
print_msg "yay ready"

echo ""
print_info "[1/9] Microsoft Edge + mbpfan..."
yay -S --noconfirm --needed microsoft-edge-stable-bin || true
yay -S --noconfirm --needed mbpfan-git || true

sudo tee /etc/mbpfan.conf >/dev/null << 'MBP'
[general]
min_fan_speed = 2000
max_fan_speed = 6200
low_temp = 55
high_temp = 80
max_temp = 95
polling_interval = 1
MBP
sudo systemctl enable mbpfan 2>/dev/null || true
print_msg "Edge + mbpfan installed"

echo ""
print_info "[2/9] VirtualBox..."
sudo pacman -S --noconfirm --needed virtualbox virtualbox-host-dkms virtualbox-guest-iso linux-headers dkms || true
sudo usermod -aG vboxusers "$USER" || true
sudo systemctl enable dkms.service || true
print_msg "VirtualBox installed"

echo ""
print_info "[3/9] QEMU/KVM + libvirt..."
sudo pacman -S --noconfirm --needed qemu-full libvirt virt-manager virt-viewer dnsmasq bridge-utils openbsd-netcat ebtables iptables-nft dmidecode || true
sudo usermod -aG libvirt,kvm "$USER" || true
sudo systemctl enable libvirtd.service || true
sudo systemctl start libvirtd.service || true
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true
print_msg "QEMU/KVM installed"

echo ""
print_info "[4/9] Wine..."
sudo pacman -S --noconfirm --needed \
  wine wine-mono wine-gecko winetricks \
  lib32-mesa lib32-vulkan-intel \
  lib32-pipewire lib32-libpulse lib32-alsa-plugins lib32-gnutls lib32-sdl2 || true
print_msg "Wine installed"

echo ""
print_info "[5/9] Dev tools + Docker..."
sudo pacman -S --noconfirm --needed \
  gcc clang cmake make ninja autoconf automake pkg-config \
  gdb lldb valgrind \
  git git-lfs \
  nodejs npm \
  python python-pip python-virtualenv \
  jdk-openjdk jre-openjdk \
  go rust \
  docker docker-compose \
  android-tools android-udev \
  arduino-ide meld || true

sudo systemctl enable docker.service || true
sudo usermod -aG docker "$USER" || true
print_msg "Dev tools + Docker installed"

echo ""
print_info "[6/9] VS Code + GitHub Desktop..."
yay -S --noconfirm --needed visual-studio-code-bin github-desktop-bin || true
print_msg "VS Code + GitHub Desktop installed"

echo ""
print_info "[7/9] Android Studio + Flutter..."
yay -S --noconfirm --needed android-studio flutter || true
grep -q 'export PATH="\$PATH:/opt/flutter/bin"' ~/.bashrc 2>/dev/null || {
  echo "" >> ~/.bashrc
  echo "# Flutter" >> ~/.bashrc
  echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
}
print_warning "After reboot run: flutter doctor --android-licenses"
print_msg "Android Studio + Flutter installed"

echo ""
print_info "[8/9] Fonts + Office + Media..."
yay -S --noconfirm --needed ttf-ms-fonts ttf-vista-fonts ttf-tahoma-fonts || true
sudo pacman -S --noconfirm --needed \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
  ttf-liberation ttf-dejavu ttf-roboto ttf-roboto-mono \
  ttf-ubuntu-font-family ttf-fira-code ttf-fira-sans ttf-fira-mono \
  ttf-jetbrains-mono ttf-hack ttf-cascadia-code ttf-droid ttf-inconsolata ttf-opensans \
  libreoffice-fresh libreoffice-fresh-en-us hunspell hunspell-en_us hyphen hyphen-en \
  okular poppler-data vlc || true
print_msg "Fonts + Office + Media installed"

echo ""
print_info "[9/9] Messaging..."
sudo pacman -S --noconfirm --needed telegram-desktop || true
yay -S --noconfirm --needed spotify whatsapp-for-linux viber teams teams-for-linux-bin || true
print_msg "Messaging installed"

echo ""
print_info "Restoring normal sudo policy..."
sudo sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || true

echo ""
print_msg "╔════════════════════════════════════════════════════╗"
print_msg "║      POST-INSTALL COMPLETE!                        ║"
print_msg "╚════════════════════════════════════════════════════╝"
echo ""
print_warning "Reboot recommended!"
echo ""
print_info "After reboot run:"
echo "  flutter doctor --android-licenses"
echo "  flutter doctor"
echo ""

read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo reboot
fi
POSTINSTALL

chmod +x "/mnt/home/${USERNAME}/postinstall.sh" || true
chown "${USERNAME}:${USERNAME}" "/mnt/home/${USERNAME}/postinstall.sh" || true

# Small README
cat > "/mnt/home/${USERNAME}/README-FIRST-BOOT.txt" << EOF
After first boot:
  1) Log in (MATE)
  2) Open Terminal
  3) Run:
       chmod +x ~/postinstall.sh
       ~/postinstall.sh

This will install: Edge, mbpfan, VS Code, Android Studio, Flutter, VirtualBox, etc.
EOF
chown "${USERNAME}:${USERNAME}" "/mnt/home/${USERNAME}/README-FIRST-BOOT.txt" || true

echo ""
print_msg "╔════════════════════════════════════════════════════╗"
print_msg "║      BASE INSTALL COMPLETE                         ║"
print_msg "╚════════════════════════════════════════════════════╝"
echo ""
print_msg "Desktop: MATE + LightDM (Slick Greeter)"
print_msg "Bootloader: GRUB2 menu + Mac-safe BOOTX64.EFI"
print_msg "User: ${USERNAME}"
print_msg "Timezone: ${TIMEZONE}"
echo ""
print_info "After reboot, run:  ~/postinstall.sh"
echo ""

read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  umount -R /mnt || true
  print_msg "Rebooting... REMOVE USB DRIVE!"
  sleep 2
  reboot
else
  print_info "Run: umount -R /mnt && reboot"
fi
```2
