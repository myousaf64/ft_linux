# Network and download tools from BLFS 12.4: dhcpcd, wget, OpenSSH.
# Run in the chroot.
LOGIN=myousaf
cd /sources

tar -xf blfs-bootscripts-20250225.tar.xz

# dhcpcd
install -v -m700 -d /var/lib/dhcpcd
groupadd -g 52 dhcpcd
useradd -c 'dhcpcd PrivSep' -d /var/lib/dhcpcd -g dhcpcd -s /bin/false -u 52 dhcpcd
chown -v dhcpcd:dhcpcd /var/lib/dhcpcd
tar -xf dhcpcd-10.2.4.tar.xz
cd dhcpcd-10.2.4
./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib/dhcpcd \
    --dbdir=/var/lib/dhcpcd --runstatedir=/run --privsepuser=dhcpcd
make
make install
cd ..
rm -rf dhcpcd-10.2.4
make -C blfs-bootscripts-20250225 install-service-dhcpcd

# wget, with the Mozilla CA bundle
install -v -Dm644 cacert.pem /etc/ssl/certs/ca-certificates.crt
ln -sfv certs/ca-certificates.crt /etc/ssl/cert.pem
tar -xf wget-1.25.0.tar.gz
cd wget-1.25.0
./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl --without-libpsl
make
make install
cd ..
rm -rf wget-1.25.0

# OpenSSH
install -v -g sys -m700 -d /var/lib/sshd
groupadd -g 50 sshd
useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
tar -xf openssh-10.0p1.tar.gz
cd openssh-10.0p1
./configure --prefix=/usr --sysconfdir=/etc/ssh \
    --with-privsep-path=/var/lib/sshd --with-default-path=/usr/bin \
    --with-superuser-path=/usr/sbin:/usr/bin --with-pid-dir=/run
make
make install
cd ..
rm -rf openssh-10.0p1
make -C blfs-bootscripts-20250225 install-sshd
rm -rf blfs-bootscripts-20250225

# The keys of the build host give access to the new system.
for home in /root /home/$LOGIN; do
    install -d -m700 $home/.ssh
    install -m600 /sources/authorized_keys $home/.ssh/authorized_keys
done
chown -R $LOGIN:$LOGIN /home/$LOGIN/.ssh
