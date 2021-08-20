# Default postinstall kickstart config in Ultramarine
firstboot --enable
halt
network --hostname=ultramarine
%packages
initial-setup
initial-setup-gui
gnome-initial-setup
repo --name=ultramarine --baseurl=https://download.copr.fedorainfracloud.org/results/cappyishihara/ultramarine/fedora-$releasever-$basearch/
%end
%post
systemctl enable firstboot-text.service
systemctl enable firstboot-graphical.service
systemctl start firstboot-text.service
systemctl start firstboot-graphical.service
chkconfig livesys off
chkconfig livesys-late off 

%end
