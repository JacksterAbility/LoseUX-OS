#!/bin/bash
# ==========================================
# Loseux OS ISO Builder Script
# ==========================================

set -e
echo "=== Starting Loseux OS ISO Build Process ==="

# 1. Install required dependencies
sudo apt update
sudo apt install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

# 2. Set up workspace directories
BUILD_DIR="$HOME/loseux_iso_build"
mkdir -p "$BUILD_DIR/chroot" "$BUILD_DIR/iso/boot/grub"

cd "$BUILD_DIR"

# 3. Bootstrap a minimal Debian/Linux root filesystem
echo ">>> Bootstrapping Linux rootfs..."
sudo debootstrap --arch=amd64 bookworm ./chroot http://deb.debian.org/debian/

# 4. Inject your Loseux Web UI & Startup App into the rootfs
echo ">>> Injecting Loseux UI..."
sudo mkdir -p ./chroot/opt/loseux
# (Assuming your html file is named loseux_ultimate.html in the current dir)
sudo cp /path/to/loseux_ultimate.html ./chroot/opt/loseux/index.html

# Create an auto-start service to launch a browser or server on boot
sudo bash -c 'cat << "EOF" > ./chroot/etc/systemd/system/loseux.service
[Unit]
Description=Loseux OS Web Desktop
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 80 --directory /opt/loseux
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo chroot ./chroot systemctl enable loseux.service

# 5. Build the SquashFS compressed filesystem
echo ">>> Compressing filesystem into squashfs..."
sudo mksquashfs ./chroot iso/live/filesystem.squashfs -noappend

# 6. Extract Linux Kernel and Initrd from chroot
KERNEL_VERSION=$(ls chroot/boot/ | grep vmlinuz | head -n 1)
sudo cp chroot/boot/$KERNEL_VERSION iso/boot/vmlinuz
INITRD_VERSION=$(ls chroot/boot/ | grep initrd.img | head -n 1)
sudo cp chroot/boot/$INITRD_VERSION iso/boot/initrd.img

# 7. Create GRUB Bootloader Configuration
echo ">>> Configuring GRUB bootloader..."
cat << 'EOF' > iso/boot/grub/grub.cfg
set timeout=5
set default=0

menuentry "Loseux OS 1.0 (Live Linux Kernel)" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}
EOF

# 8. Generate the Final Bootable ISO Image
echo ">>> Packaging into loseux_v1.iso..."
grub-mkrescue -o loseux_v1.iso iso/

echo "=== SUCCESS! ISO file generated: $BUILD_DIR/loseux_v1.iso ==="