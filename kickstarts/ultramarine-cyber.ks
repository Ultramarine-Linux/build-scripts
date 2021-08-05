#base fedora stuff

%include additional-repos.ks
%include cyber-base.ks

#cyber-desktop repo
repo --name "copr:copr.fedorainfracloud.org:cappyishihara:cyber-desktop" --install --baseurl https://download.copr.fedorainfracloud.org/results/cappyishihara/cyber-desktop/fedora-$releasever-$basearch/

%packages
#x server
@base-x

#install cyber desktop
cyber-desktop
meuikit-devel

#SDDM
sddm

#app groups because currently shit is empty
@firefox
@libreoffice
@admin-tools

fuse

# Office
libreoffice-kf5

-gnome-session
-@ GNOME Desktop Environment 

%end
%post

#enable SDDM
systemctl enable sddm



%end