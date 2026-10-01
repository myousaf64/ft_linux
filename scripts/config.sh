# LFS chapter 9 and fstab. Run in the chroot.
LOGIN=myousaf
DISK=/dev/sdb
uuid() { blkid -s PARTUUID -o value $DISK$1; }

cd /sources
tar -xf lfs-bootscripts-20250827.tar.xz
make -C lfs-bootscripts-20250827 install
rm -rf lfs-bootscripts-20250827

echo $LOGIN > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1 localhost.localdomain localhost
127.0.1.1 $LOGIN.localdomain $LOGIN
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

# DHCP on eth0. The dhcpcd service comes from extras.sh.
cat > /etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT="yes"
IFACE="eth0"
SERVICE="dhcpcd"
DHCP_START="-b -q"
DHCP_STOP="-k"
EOF

cat > /etc/inittab << "EOF"
id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S06:once:/sbin/sulogin
s1:1:respawn:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600
EOF

cat > /etc/sysconfig/clock << "EOF"
UTC=1
CLOCKPARAMS=
EOF

cat > /etc/profile << "EOF"
for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  export LANG=en_US.UTF-8
fi
export PATH=$PATH:/usr/local/bin
export PS1='\u@\h:\w\$ '
EOF

cat > /etc/inputrc << "EOF"
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[3~": delete-char
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF

cat > /etc/shells << "EOF"
/bin/sh
/bin/bash
EOF

cat > /etc/fstab << EOF
# file system          mount-point    type     options             dump  fsck
PARTUUID=$(uuid 3)   /              ext4     defaults            1     1
PARTUUID=$(uuid 1)   /boot          ext2     defaults            1     2
PARTUUID=$(uuid 2)   swap           swap     pri=1               0     0
proc                   /proc          proc     nosuid,noexec,nodev 0     0
sysfs                  /sys           sysfs    nosuid,noexec,nodev 0     0
devpts                 /dev/pts       devpts   gid=5,mode=620      0     0
tmpfs                  /run           tmpfs    defaults            0     0
devtmpfs               /dev           devtmpfs mode=0755,nosuid    0     0
tmpfs                  /dev/shm       tmpfs    nosuid,nodev        0     0
cgroup2                /sys/fs/cgroup cgroup2  nosuid,noexec,nodev 0     0
EOF

echo 12.4 > /etc/lfs-release
cat > /etc/os-release << EOF
NAME="ft_linux"
VERSION="12.4"
ID=lfs
PRETTY_NAME="ft_linux ($LOGIN), Linux From Scratch 12.4"
VERSION_CODENAME="$LOGIN"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
EOF

useradd -m -G wheel $LOGIN
echo "$LOGIN:$LFS_PASSWORD" | chpasswd
