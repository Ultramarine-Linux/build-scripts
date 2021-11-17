#Custom Anaconda Configuration

%post
# show logs please
chvt
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

echo "Adding Anaconda configuration..."

#heredoc
cat << EOF > /etc/anaconda/profile.d/ultramarine.conf
# Anaconda configuration file for Ultramarine Linux
[Anaconda]
addons_enabled = True
# List of enabled kickstart modules.
kickstart_modules =
    org.fedoraproject.Anaconda.Modules.Timezone
    org.fedoraproject.Anaconda.Modules.Network
    org.fedoraproject.Anaconda.Modules.Localization
    org.fedoraproject.Anaconda.Modules.Users
    org.fedoraproject.Anaconda.Modules.Payloads
    org.fedoraproject.Anaconda.Modules.Storage
    org.fedoraproject.Anaconda.Modules.Services


[Profile]
# Define the profile.
profile_id = ultramarine

[Profile Detection]
# Match os-release values.
os_id = ultramarine

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1

[User Interface]
default_help_pages =
    FedoraPlaceholder.txt
    FedoraPlaceholder.html
    FedoraPlaceholderWithLinks.html

custom_stylesheet = /usr/share/anaconda/pixmaps/ultramarine.css
hidden_spokes =
    PasswordSpoke


[Payload]
default_source = CLOSEST_MIRROR

default_rpm_gpg_keys =
    /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch

updates_repositories =
    updates
    updates-modular
    ultramarine

EOF

%end