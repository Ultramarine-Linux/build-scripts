
#ksflatten is funny
%include cyber-packages.ks

%post
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager chronyd
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    continue
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
  fi
done

# enable swapfile if it exists
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  echo "Enabling swap file" && swapon /run/initramfs/live/\${livedir}/swap.img
fi


# support label/uuid
if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
  homedev=\`/sbin/blkid -o device -t "\$homedev"\`
fi
# if we're given a file rather than a blockdev, loopback it
if [ "\${homedev##mtd}" != "\${homedev}" ]; then
  # mtd devs don't have a block device but get magic-mounted with -t jffs2
  mountopts="-t jffs2"
elif [ ! -b "\$homedev" ]; then
  loopdev=\`losetup -f\`
  if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
    echo "Remounting live store r/w" && mount -o remount,rw /run/initramfs/live
  fi
  losetup \$loopdev \$homedev
  homedev=\$loopdev
fi
# if it's encrypted, we need to unlock it
if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
  echo
  echo "Setting up encrypted /home device"
  plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
  homedev=/dev/mapper/EncHome
fi

# and finally do the mount
mount \$mountopts \$homedev /home
# if we have /home under what's passed for persistent home, then
# we should make that the real /home.  useful for mtd device on olpc
if [ -d /home/home ]; then mount --bind /home/home /home ; fi
[ -x /sbin/restorecon ] && /sbin/restorecon /home
if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi

for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
    homedev=\${arg##persistenthome=}
  fi
done


if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  echo "Mounting persistent /home" && mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# add liveuser user with no passwd
echo "Adding live user" && useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Remove root password lock
passwd -d root > /dev/null

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# turn off abrtd on a live image
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
# the hostname must be something else than 'localhost'
# https://bugzilla.redhat.com/show_bug.cgi?id=1370222
hostnamectl set-hostname "localhost-live"

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# if liveinst or textinst is given, start anaconda
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
echo "Packages within this LiveCD"
rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' |sort -rn
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
/sbin/chkconfig network off

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id


# set default GTK+ theme for root (see #683855, #689070, #808062)
cat > /root/.gtkrc-2.0 << EOF
include "/usr/share/themes/Adwaita/gtk-2.0/gtkrc"
include "/etc/gtk-2.0/gtkrc"
gtk-theme-name="Adwaita"
EOF
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name = Adwaita
EOF

# add initscript
cat >> /etc/rc.d/init.d/livesys << EOF


# set up autologin for user liveuser

cat << 'EOF' > /etc/sddm.conf
[Autologin]
User=liveuser
Session=cyber-xsession.desktop
#this has been bugging us for a long time and we have no idea why
InputMethod=
Relogin=true
[Theme]
EOF

##Configuration
#Create Liveuser dir
mkdir -p /home/liveuser/.config/cyberos
mkdir -p /home/liveuser/.config/
mkdir -p /home/liveuser/Downloads
mkdir -p /home/liveuser/Documents
mkdir -p /home/liveuser/Pictures
mkdir -p /home/liveuser/Videos

#Edit Cyber Configuration
touch /home/liveuser/.config/cyberos/theme.conf
cat << 'EOF' > /home/liveuser/.config/cyberos/theme.conf
[General]
AccentColor=0
DarkMode=false
DarkModeDimsWallpaer=false
PixelRatio=1
Wallpaper=/usr/share/backgrounds/images/default-16_9.png
EOF

#Cyber Dock
touch /home/liveuser/.config/cyberos/dock_pinned.conf
cat << 'EOF' > /home/liveuser/.config/cyberos/dock_pinned.conf
[Anaconda]
DesktopPath=
Exec=
IconName=anaconda
Index=2
visibleName=Anaconda Installer
 
[Firefox]
DesktopPath=/usr/share/applications/firefox.desktop
Exec=firefox
IconName=firefox
Index=0
visibleName=Firefox
 
[cyber-fm]
DesktopPath=/usr/share/applications/cyber-fm.desktop
Exec=cyber-fm
IconName=file-system-manager
Index=3
visibleName=File Manager
 
[cyber-terminal]
DesktopPath=/usr/share/applications/cyber-terminal.desktop
Exec=cyber-terminal
IconName=utilities-terminal
Index=1
visibleName=Terminal
EOF

# "Disable plasma-discover-notifier"
mkdir -p /home/liveuser/.config/autostart
cp -a /etc/xdg/autostart/org.kde.discover.notifier.desktop /home/liveuser/.config/autostart/
echo 'Hidden=true' >> /home/liveuser/.config/autostart/org.kde.discover.notifier.desktop

#Autostart Installer
touch /home/liveuser/.config/autostart/liveinst.desktop
cat << 'EOF' > /home/liveuser/.config/autostart/liveinst.desktop
[Desktop Entry]
Type=Application
Exec=/usr/bin/liveinst
Hidden=false
NoDisplay=false
Name=Install Ultramarine Linux
X-GNOME-Autostart-enabled=true
EOF

#Set Text Editor for all users
touch /etc/gnome/defaults.list
cat << 'EOF' > /etc/gnome/defaults.list
[Default Applications]
text/plain=cyber-editor.desktop
EOF

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/



%end
