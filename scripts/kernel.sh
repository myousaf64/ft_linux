# LFS chapter 10.3: Linux kernel. Run in the chroot.
LOGIN=myousaf
VER=6.16.1

cd /usr/src
rm -rf kernel-$VER linux-$VER
tar -xf /sources/linux-$VER.tar.xz
mv linux-$VER kernel-$VER
cd kernel-$VER

make mrproper
make defconfig
scripts/config --set-str LOCALVERSION "-$LOGIN" --disable LOCALVERSION_AUTO \
    --disable WERROR --disable UEVENT_HELPER \
    --enable DEVTMPFS --enable DEVTMPFS_MOUNT \
    --enable EXT4_FS --enable SATA_AHCI --enable ATA_PIIX \
    --enable E1000 --enable VIRTIO_PCI --enable VIRTIO_NET --enable VIRTIO_BLK \
    --enable FB --enable FRAMEBUFFER_CONSOLE --enable FB_VESA \
    --module SND_INTEL8X0 --module I2C_PIIX4 --module VBOXGUEST \
    --module BLK_DEV_LOOP --module FUSE_FS
make olddefconfig
make
make modules_install

cp -v arch/x86/boot/bzImage /boot/vmlinuz-$VER-$LOGIN
cp -v System.map /boot/System.map-$VER-$LOGIN
cp -v .config /boot/config-$VER-$LOGIN

install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true
EOF
