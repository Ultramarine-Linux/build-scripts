# Maintained by the Fedora Workstation WG:
# http://fedoraproject.org/wiki/Workstation
# mailto:desktop@lists.fedoraproject.org

%include ../../base/base.ks
%include gnome-packages.ks

%post

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="gnome"/' /etc/sysconfig/livesys
sed -i 's/Fedora/Ultramarine/g' /usr/share/anaconda/gnome/fedora-welcome
sed -i 's/Fedora/Ultramarine/g' /usr/share/applications/org.fedoraproject.welcome-screen.desktop
sed -i 's/Fedora/Ultramarine/g' /usr/share/anaconda/gnome/org.fedoraproject.welcome-screen.desktop

%end
