# LFS chapter 10.4: GRUB on the MBR of the LFS disk. Run in the chroot.
LOGIN=myousaf
VER=6.16.1
DISK=/dev/sdb

grub-install --target=i386-pc $DISK
cat > /boot/grub/grub.cfg << EOF
set default=0
set timeout=3

insmod part_msdos
insmod ext2
search --no-floppy --label boot --set=root

menuentry "ft_linux, Linux $VER-$LOGIN" {
        linux /vmlinuz-$VER-$LOGIN root=PARTUUID=$(blkid -s PARTUUID -o value ${DISK}3) ro net.ifnames=0
}
EOF
