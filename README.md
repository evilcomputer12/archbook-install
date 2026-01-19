# 📱 Arch Linux Installation Guide for MacBook Air Mid 2012
## Using archinstall (Easy Method)

---

## 🚀 QUICK START - 5 STEPS

1. **Boot from USB** → Hold Option (⌥) key during startup
2. **Connect WiFi** → Follow commands below
3. **Run installer** → `./easy-install.sh`
4. **Answer prompts** → Choose disk and set passwords
5. **Reboot** → Remove USB and enjoy!

---

## 📋 PART 1: CREATING THE USB INSTALLER

### On Windows:

1. Download **Arch Linux ISO**: https://archlinux.org/download/
2. Download **Rufus**: https://rufus.ie/
3. Insert USB drive (8GB+)
4. Run Rufus:
   - Select your USB device
   - Select Arch Linux ISO
   - Partition scheme: **GPT**
   - Target system: **UEFI**
   - Click **START**

### On macOS:

```bash
# Download ISO
cd ~/Downloads
curl -O https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Find USB device (usually disk2 or disk3)
diskutil list

# CAREFUL! Replace diskN with your USB device
sudo dd if=archlinux-x86_64.iso of=/dev/rdiskN bs=1m

# Eject when done
diskutil eject /dev/diskN
```

### On Linux:

```bash
# Download ISO
wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Find USB device
lsblk

# CAREFUL! Replace sdX with your USB device
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

---

## 📋 PART 2: BOOTING THE MACBOOK

### 1. Backup Your Data!
⚠️ **THIS WILL ERASE EVERYTHING ON YOUR MACBOOK!**

### 2. Insert USB Drive

### 3. Restart MacBook and Boot from USB

**Hold Option (⌥) key immediately after power on**

You'll see a boot menu. Select:
- **"EFI Boot"** or
- **"USB Drive"** or
- The orange/yellow USB icon

Press Enter to boot.

### 4. Wait for Boot

You'll see a lot of text scrolling. This is normal.
Eventually you'll get to a prompt that looks like:

```
root@archiso ~ #
```

---

## 📋 PART 3: CONNECTING TO WIFI (MOST IMPORTANT!)

### Method 1: Using iwctl (Recommended)

**Step 1: Start iwctl**
```bash
iwctl
```

Your prompt will change to:
```
[iwd]#
```

**Step 2: List your WiFi device**
```bash
device list
```

You'll see something like:
```
Name    Address             Powered
wlan0   12:34:56:78:9a:bc   on
```

**Step 3: Scan for networks**
```bash
station wlan0 scan
```

(No output is normal)

**Step 4: List available networks**
```bash
station wlan0 get-networks
```

You'll see:
```
Network name              Security
MyHomeWiFi                psk
NeighborWiFi              psk
Guest-Network             open
```

**Step 5: Connect to your network**

For secured network (most common):
```bash
station wlan0 connect "MyHomeWiFi"
```

It will ask for password. Type it carefully (you won't see it as you type).

For open network:
```bash
station wlan0 connect "Guest-Network"
```

**Step 6: Exit iwctl**
```bash
exit
```

**Step 7: Test internet**
```bash
ping -c 3 google.com
```

Should see:
```
64 bytes from google.com...
```

✅ **If you see this, WiFi is working!**

❌ **If you see "Network unreachable", try again from Step 1.**

---

### Method 2: Alternative WiFi Setup

If iwctl doesn't work:

```bash
# Check WiFi device name
ip link

# Bring interface up
ip link set wlan0 up

# Connect using wpa_supplicant
wpa_passphrase "YourNetworkName" "YourPassword" > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf

# Get IP address
dhcpcd wlan0

# Test
ping google.com
```

---

### Method 3: Using Ethernet (Easiest!)

If you have a USB-to-Ethernet adapter:

1. Plug it in
2. Plug in ethernet cable
3. Wait 5 seconds
4. Test: `ping google.com`

That's it! Ethernet usually works immediately.

---

## 📋 PART 4: RUNNING THE INSTALLER

### Step 1: Download Installation Scripts

**Option A: Using the USB (if you saved files on it)**

```bash
# Mount USB (find device first)
lsblk
mkdir /mnt/usb
mount /dev/sdb1 /mnt/usb  # Adjust device name

# Copy files
cp /mnt/usb/easy-install.sh .
chmod +x easy-install.sh
```

**Option B: Download from internet**

```bash
# If you uploaded to GitHub/server
curl -O https://your-server.com/easy-install.sh
chmod +x easy-install.sh
```

**Option C: Type it manually (embedded in script)**

The script has the config embedded, so you just need to copy the easy-install.sh file!

### Step 2: Run Installer

```bash
./easy-install.sh
```

### Step 3: Follow the Prompts

The `archinstall` tool will start. Here's what you'll see:

#### 📺 Screen 1: Language & Mirrors
- **Keyboard Layout**: Press Enter (keeps "us")
- **Mirror Region**: Select your country or nearby (use arrow keys, Space to select, Enter to confirm)

#### 💾 Screen 2: Disk Configuration
- **Select disk**: Choose your MacBook's disk (usually `/dev/sda`)
- **Disk layout**: Choose "Ext4" (simplest)
- **Erase disk**: Confirm "Yes"

#### 👤 Screen 3: User Setup
- **Root password**: Type a secure password (you won't see it)
- **Create user**: Should already be "martin"
- **User password**: Type a secure password for martin
- **Sudo access**: Should already be "yes"

#### 🖥️ Screen 4: Desktop Environment
- Should already be set to "Deepin"
- Press Enter to continue

#### 🎵 Screen 5: Audio
- Should be "pipewire"
- Press Enter

#### ✅ Screen 6: Confirm
- Review everything
- Select "Install"
- Confirm one more time

### Step 4: Wait

Installation takes **15-30 minutes** depending on internet speed.

You'll see:
```
[#################] 45%
```

☕ This is a good time for coffee!

---

## 📋 PART 5: FIRST BOOT

### 1. Remove USB Drive

When installation finishes:
- Remove USB drive
- Type: `reboot`

### 2. Boot into New System

MacBook will restart. You'll see:
- GRUB bootloader (black screen with "Arch Linux")
- Press Enter or wait 3 seconds
- Deepin loading screen

### 3. Login

**Deepin Login Screen appears!**

- Username: `martin`
- Password: (what you set during installation)

### 4. First Time Setup

Deepin will ask a few questions:
- Language: English
- Keyboard: US
- Time zone: Europe/Skopje (should be set)

---

## 📋 PART 6: POST-INSTALLATION

### 1. Check Welcome File

Open Terminal (Ctrl + Alt + T) and:

```bash
cat WELCOME.txt
```

### 2. Change Your Password

```bash
passwd
```

Type new password twice.

### 3. Update System

```bash
sudo pacman -Syu
```

Enter your password when asked.

### 4. Install Microsoft Edge

```bash
./install-edge.sh
```

This takes about **10 minutes**. It will:
- Install `yay` (AUR helper)
- Download and build Microsoft Edge
- Install Edge

Once done, you'll find Edge in the application menu!

### 5. Test WiFi

WiFi should connect automatically. To manage WiFi:

- Click the network icon in top bar
- Select your network
- Enter password if needed

Or from terminal:
```bash
nmtui
```

---

## 🔧 TROUBLESHOOTING

### WiFi Not Working After Installation

```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
```

Or manually:
```bash
sudo modprobe -r b43
sudo modprobe wl
sudo systemctl restart NetworkManager
```

### Screen Brightness Not Working

```bash
# Add kernel parameter
sudo vim /boot/loader/entries/arch.conf
# Add: acpi_backlight=vendor
```

### Keyboard Backlight Not Working

```bash
sudo pacman -S kbdlight
```

### Trackpad Too Fast/Slow

1. Open **Control Center**
2. Go to **Devices** → **Mouse**
3. Adjust pointer speed

### Sound Not Working

```bash
alsamixer  # Press F6 to select sound card, unmute with 'M'
```

---

## 📚 USEFUL COMMANDS

### Package Management

```bash
# Install package
sudo pacman -S package-name

# Remove package
sudo pacman -R package-name

# Search for package
pacman -Ss keyword

# Update everything
sudo pacman -Syu

# Install from AUR
yay -S package-name
```

### System Information

```bash
neofetch              # System info
htop                  # Task manager
df -h                 # Disk space
free -h               # RAM usage
ip addr               # IP address
```

### Network

```bash
nmtui                 # Network manager TUI
nmcli device wifi     # List WiFi networks
iwctl                 # WiFi configuration tool
```

---

## 📦 RECOMMENDED SOFTWARE

### After Installation:

```bash
# Development
yay -S visual-studio-code-bin

# Communication
sudo pacman -S telegram-desktop discord

# Media
sudo pacman -S vlc mpv

# Office
sudo pacman -S libreoffice-fresh

# Utilities
yay -S google-chrome
yay -S slack-desktop
yay -S zoom
```

---

## 🆘 GETTING HELP

- **Arch Wiki**: https://wiki.archlinux.org
- **MacBook Arch**: https://wiki.archlinux.org/title/MacBook
- **Forum**: https://bbs.archlinux.org/

---

## ✅ CHECKLIST

Before installation:
- [ ] Backup all important data
- [ ] Created Arch Linux USB
- [ ] MacBook plugged in or >50% battery
- [ ] Know your WiFi password

After installation:
- [ ] Changed user password
- [ ] Updated system (`sudo pacman -Syu`)
- [ ] Installed Microsoft Edge
- [ ] WiFi working
- [ ] Configured Deepin settings

---

## 📝 NOTES FOR MACBOOK AIR MID 2012

### What Works:
✅ WiFi (Broadcom BCM4360)
✅ Bluetooth
✅ Graphics (Intel HD 4000)
✅ Trackpad (multi-touch)
✅ Keyboard + backlight
✅ Screen brightness
✅ Audio (speakers + headphones)
✅ USB ports
✅ Thunderbolt (as USB)
✅ Battery indicator
✅ FaceTime camera

### What Needs Tweaking:
⚠️ Battery life (install TLP for better life)
⚠️ Sleep/suspend (may need tweaking)
⚠️ Fan control (install mbpfan)

### To Improve Battery Life:

```bash
sudo pacman -S tlp tlp-rdw
sudo systemctl enable tlp
sudo systemctl start tlp
```

### To Control Fans:

```bash
yay -S mbpfan-git
sudo systemctl enable mbpfan
sudo systemctl start mbpfan
```

---

**Good luck! You're going to love Arch Linux! 🎉**
