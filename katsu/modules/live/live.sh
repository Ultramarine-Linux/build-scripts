#!/bin/sh -x

# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >>/etc/fstab <<EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
# rm -f /var/lib/rpm/__db*
echo "Packages within this LiveCD"
rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' | sort -rn
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb -c

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by katsu. See systemd-update-done.service(8).' |
    tee /etc/.updated >/var/.updated

# Set locales in chroot
cat >/etc/locale.conf <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network
systemctl disable systemd-networkd
systemctl disable systemd-networkd.socket
systemctl disable systemd-networkd-wait-online
systemctl disable openvpn-client@\*.service
systemctl disable openvpn-server@\*.service

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# make sure there aren't core files lying around
rm -f /core*

systemctl set-default graphical.target

cat >>/var/lib/livesys/livesys-session-extra <<EOF
# Remove the initial setup configs, we actually don't need them for now
rm -rf /.unconfigured
systemctl disable initial-setup || true
EOF

echo "Setting up some extra post scripts"

anaconda_dir=/usr/share/anaconda/post-scripts

mkdir -p "$anaconda_dir"

cat > "$anaconda_dir/01-selinux.ks" << EOF

%post
echo "Setting up SELinux..."
setfiles -F -e /proc -e /sys -e /dev -e /bin /etc/selinux/targeted/contexts/files/file_contexts / || true
setfiles -F -e /proc -e /sys -e /dev /etc/selinux/targeted/contexts/files/file_contexts.bin /bin || true

%end

EOF


# Delete the firefox redhat configs, debranding
rm -rf /usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js


# Disable sysroot.mount
systemctl disable sysroot.mount || true
