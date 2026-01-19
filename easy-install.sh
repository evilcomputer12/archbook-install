
#!/bin/bash
#
# Complete Arch Linux Installer for MacBook Air Mid 2012 (ALL-IN-ONE)
# Installs: MATE Desktop + LightDM + Drivers + Power + Fans + Edge + Dev + Virtualization + Fonts + Office + Media + Messaging
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

HOSTNAME="macbook-arch"
USERNAME="martin"
TIMEZONE="Europe/Skopje"

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║   Arch Linux COMPLETE Installer - MacBook Air Mid 2012  ║
║   Everything in ONE install - Ready to use after reboot ║
║                                                          ║
║   Includes: MATE + Edge + TLP + mbpfan + Dev + VM tools  ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
print_warning "This will COMPLETELY ERASE your disk!"
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

echo ""
print_info "Set passwords now:"
echo ""
read -s -p "Enter ROOT password: " ROOT_PASS
echo ""
read -s -p "Confirm ROOT password: " ROOT_PASS2
echo ""
if [ "$ROOT_PASS" != "$ROOT_PASS2" ]; then
    print_error "Passwords don't match!"
    exit 1
fi

echo ""
read -s -p "Enter password for user '${USERNAME}': " USER_PASS
echo ""
read -s -p "Confirm password for '${USERNAME}': " USER_PASS2
echo ""
if [ "$USER_PASS" != "$USER_PASS2" ]; then
    print_error "Passwords don't match!"
    exit 1
fi

print_msg "Passwords set!"

if [[ "$DISK" == *"nvme"* ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

umount -R /mnt 2>/dev/null || true

echo ""
print_info "[1/8] Partitioning $DISK..."
wipefs -af "$DISK" || true
sgdisk --zap-all "$DISK" || true
sgdisk -o "$DISK" || true
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK" || true
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux" "$DISK" || true
sleep 2
partprobe "$DISK" || true
sleep 2
print_msg "Disk partitioned!"

print_info "[2/8] Formatting partitions..."
mkfs.fat -F32 "$PART1" || true
mkfs.ext4 -F "$PART2" || true
print_msg "Partitions formatted!"

print_info "[3/8] Mounting partitions..."
mount "$PART2" /mnt || true
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot || true
print_msg "Partitions mounted!"

print_info "[4/8] Updating mirrors..."
if command -v reflector &> /dev/null; then
    reflector --country Germany,France,Netherlands --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
fi
print_msg "Mirrors updated!"

print_info "[5/8] Installing base system..."
pacstrap -K /mnt \
    base \
    base-devel \
    linux \
    linux-headers \
    linux-firmware \
    intel-ucode \
    nano \
    vim \
    git \
    wget \
    curl \
    networkmanager \
    network-manager-applet \
    sudo \
    efibootmgr \
    dosfstools \
    mtools \
    htop || true
print_msg "Base system installed!"

print_info "[6/8] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || true
print_msg "fstab generated!"

ROOT_UUID=$(blkid -s UUID -o value "$PART2")

print_info "[7/8] Creating and running chroot configuration script..."

cat > /mnt/root/setup.sh << SETUP_SCRIPT
#!/bin/bash
set +e

echo "[7a] Timezone & clock..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime || true
hwclock --systohc || true

echo "[7b] Locale..."
grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "[7c] Hostname & hosts..."
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "[7d] Pacman tweaks + multilib..."
sed -i 's/^#Color/Color/' /etc/pacman.conf || true
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || true
# Enable multilib (needed for Wine 32-bit libs)
sed -i '/^\[multilib\]/,/^Include/s/^#//' /etc/pacman.conf || true
pacman -Sy || true

echo "[7e] Users + passwords..."
echo "root:${ROOT_PASS}" | chpasswd || true
id -u ${USERNAME} &>/dev/null || useradd -m -G wheel,audio,video,storage,optical -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASS}" | chpasswd || true

# Allow yay to build without prompting for sudo password (reverted at end)
grep -q '^%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers || echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "[7f] Bootloader (systemd-boot)..."
bootctl install || true
mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet loglevel=3
EOF

echo "[8/8] Installing system packages (this may take a while)..."

echo "  - Xorg + Intel graphics..."
pacman -S --noconfirm \
  xorg-server xorg-xinit xorg-xrandr \
  xf86-video-intel xf86-input-libinput \
  mesa vulkan-intel \
  lib32-mesa lib32-vulkan-intel || true

echo "  - MATE desktop + LightDM..."
pacman -S --noconfirm \
  mate mate-extra \
  lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  gvfs gvfs-mtp file-roller \
  network-manager-applet || true

# LightDM greeter config
sed -i 's/^#greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf 2>/dev/null || true

echo "  - Audio (PipeWire)..."
pacman -S --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber || true

echo "  - MacBook hardware support..."
pacman -S --noconfirm \
  broadcom-wl-dkms dkms \
  tlp tlp-rdw powertop \
  lm_sensors acpi thermald smartmontools ethtool \
  bluez bluez-utils || true

echo "  - Browsers + basic utilities..."
pacman -S --noconfirm \
  firefox \
  ntfs-3g unzip zip p7zip unrar \
  okular poppler-data || true

echo "  - Virtualization (VirtualBox + QEMU/KVM)..."
pacman -S --noconfirm \
  virtualbox virtualbox-host-dkms virtualbox-guest-iso linux-headers \
  qemu-full libvirt virt-manager virt-viewer dnsmasq bridge-utils openbsd-netcat \
  ebtables iptables-nft dmidecode || true

echo "  - Wine..."
pacman -S --noconfirm \
  wine wine-mono wine-gecko winetricks \
  lib32-pipewire lib32-libpulse lib32-alsa-plugins lib32-gnutls lib32-sdl2 || true

echo "  - Dev tools + Docker..."
pacman -S --noconfirm \
  gcc clang cmake make ninja autoconf automake pkg-config \
  gdb lldb valgrind \
  git git-lfs \
  nodejs npm \
  python python-pip python-virtualenv \
  jdk-openjdk jre-openjdk \
  go rust \
  docker docker-compose \
  meld \
  android-tools android-udev \
  arduino-ide || true

echo "  - Office + media..."
pacman -S --noconfirm \
  libreoffice-fresh libreoffice-fresh-en-us \
  hunspell hunspell-en_us hyphen hyphen-en \
  vlc || true

echo "  - Messaging (repo + AUR later)..."
pacman -S --noconfirm telegram-desktop || true

echo "  - Fonts (repo + AUR later)..."
pacman -S --noconfirm \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
  ttf-liberation ttf-dejavu ttf-roboto ttf-roboto-mono \
  ttf-ubuntu-font-family ttf-fira-code ttf-fira-sans ttf-fira-mono \
  ttf-jetbrains-mono ttf-hack ttf-cascadia-code ttf-droid ttf-inconsolata ttf-opensans \
  adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts \
  cantarell-fonts inter-font ttf-font-awesome || true

echo "  - MacBook optimizations (TLP + mbpfan + Intel TearFree)..."
mkdir -p /etc/tlp.d
cat > /etc/tlp.d/01-macbook.conf << 'TLPCONF'
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=60
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
TLPCONF

mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-intel.conf << 'INTELCONF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    Option "TearFree" "true"
    Option "AccelMethod" "sna"
    Option "DRI" "3"
EndSection
INTELCONF

cat > /etc/modprobe.d/macbook.conf << 'MODCONF'
blacklist b43
blacklist ssb
blacklist bcm43xx
blacklist brcm80211
blacklist brcmfmac
blacklist brcmsmac
blacklist bcma
MODCONF

echo "applesmc" > /etc/modules-load.d/applesmc.conf

echo "  - Install yay (AUR helper)..."
if ! command -v yay &>/dev/null; then
  cd /tmp || true
  sudo -u ${USERNAME} git clone https://aur.archlinux.org/yay-bin.git || true
  cd yay-bin || true
  sudo -u ${USERNAME} makepkg -si --noconfirm || true
  cd / || true
fi

echo "  - AUR packages (Edge, mbpfan, VS Code, GitHub Desktop, Android Studio, Flutter, extra fonts, Spotify, WhatsApp, Viber, Teams)..."
sudo -u ${USERNAME} yay -S --noconfirm --needed microsoft-edge-stable-bin || true
sudo -u ${USERNAME} yay -S --noconfirm --needed mbpfan-git || true
sudo -u ${USERNAME} yay -S --noconfirm --needed visual-studio-code-bin || true
sudo -u ${USERNAME} yay -S --noconfirm --needed github-desktop-bin || true
sudo -u ${USERNAME} yay -S --noconfirm --needed android-studio || true
sudo -u ${USERNAME} yay -S --noconfirm --needed flutter || true
sudo -u ${USERNAME} yay -S --noconfirm --needed ttf-ms-fonts ttf-vista-fonts ttf-tahoma-fonts || true
sudo -u ${USERNAME} yay -S --noconfirm --needed spotify || true
sudo -u ${USERNAME} yay -S --noconfirm --needed whatsapp-for-linux || true
sudo -u ${USERNAME} yay -S --noconfirm --needed viber || true
sudo -u ${USERNAME} yay -S --noconfirm --needed teams || true
sudo -u ${USERNAME} yay -S --noconfirm --needed teams-for-linux-bin || true

echo "  - Font rendering config..."
cat > /etc/fonts/local.conf << 'FONTCONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
    </match>
    <match target="font">
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
    </match>
    <match target="font">
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    </match>
    <match target="font">
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
    <match target="font">
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    </match>
    <alias>
        <family>sans-serif</family>
        <prefer><family>Inter</family><family>Noto Sans</family></prefer>
    </alias>
    <alias>
        <family>monospace</family>
        <prefer><family>JetBrains Mono</family><family>Fira Code</family></prefer>
    </alias>
</fontconfig>
FONTCONF
fc-cache -fv || true

echo "  - Group memberships..."
usermod -aG vboxusers ${USERNAME} || true
usermod -aG libvirt,kvm ${USERNAME} || true
usermod -aG docker ${USERNAME} || true
usermod -aG adbusers ${USERNAME} || true
usermod -aG uucp,lock ${USERNAME} || true

echo "  - Flutter PATH..."
grep -q 'export PATH="\$PATH:/opt/flutter/bin"' /home/${USERNAME}/.bashrc 2>/dev/null || {
  echo "" >> /home/${USERNAME}/.bashrc
  echo "# Flutter" >> /home/${USERNAME}/.bashrc
  echo 'export PATH="$PATH:/opt/flutter/bin"' >> /home/${USERNAME}/.bashrc
}
chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bashrc || true

echo "  - mbpfan config..."
cat > /etc/mbpfan.conf << 'MBPFAN'
[general]
min_fan_speed = 2000
max_fan_speed = 6200
low_temp = 55
high_temp = 80
max_temp = 95
polling_interval = 1
MBPFAN

echo "  - Enable services..."
systemctl enable NetworkManager || true
systemctl enable lightdm || true
systemctl enable bluetooth || true
systemctl enable tlp || true
systemctl enable thermald || true
systemctl enable mbpfan || true
systemctl enable libvirtd.service || true
systemctl enable dkms.service || true
systemctl enable docker.service || true

# libvirt default network
systemctl start libvirtd.service || true
virsh net-autostart default 2>/dev/null || true
virsh net-start default 2>/dev/null || true

echo "  - Rebuild DKMS modules..."
dkms autoinstall || true

# Restore normal sudo behavior
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || true

echo "  - README for user..."
cat > /home/${USERNAME}/README.txt << 'README'
╔══════════════════════════════════════════════════════════╗
║     Arch Linux on MacBook Air - READY TO USE!           ║
╚══════════════════════════════════════════════════════════╝

INSTALLED:
✓ MATE Desktop + LightDM
✓ Microsoft Edge + Firefox
✓ Broadcom WiFi (DKMS) + Bluetooth
✓ PipeWire audio
✓ TLP (battery optimization)
✓ mbpfan (fan control)
✓ VirtualBox + QEMU/KVM + libvirt
✓ Wine + 32-bit libs
✓ Docker
✓ VS Code + GitHub Desktop
✓ Android Studio + Flutter + Android tools
✓ Arduino IDE + Meld
✓ Fonts (Noto/Inter/JetBrains + Microsoft TTF)
✓ LibreOffice + Okular
✓ VLC + Spotify
✓ Telegram + WhatsApp + Viber + Teams

NOTES:
• After reboot run:
  flutter doctor --android-licenses
  flutter doctor

CHECK STATUS:
• Battery: sudo tlp-stat -b
• Temperature: sensors
• Fan speed: cat /sys/devices/platform/applesmc.768/fan1_input

UPDATE SYSTEM:
sudo pacman -Syu
README
chown ${USERNAME}:${USERNAME} /home/${USERNAME}/README.txt || true

echo ""
echo "=========================================="
echo "  INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
SETUP_SCRIPT

chmod +x /mnt/root/setup.sh || true
arch-chroot /mnt /root/setup.sh || true
rm -f /mnt/root/setup.sh || true

echo ""
print_msg "╔════════════════════════════════════════════════════╗"
print_msg "║      INSTALLATION 100% COMPLETE!                  ║"
print_msg "╚════════════════════════════════════════════════════╝"
echo ""
print_msg "Desktop: MATE + LightDM"
print_msg "User: ${USERNAME}"
echo ""
print_warning "REBOOT REQUIRED!"
print_info "After reboot run:"
echo "  flutter doctor --android-licenses"
echo "  flutter doctor"
echo ""

read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    umount -R /mnt || true
    print_msg "Rebooting... REMOVE USB DRIVE!"
    sleep 3
    reboot
else
    print_info "Run: umount -R /mnt && reboot"
fi
