#!/bin/bash


# Edit /etc/gdm/custom.conf at [daemon], to enable initial-setup

sed '/[daemon]/a InitialSetupEnable=True' /etc/gdm/custom.conf

# Now get GDM to actually run it

systemctl disable initial-setup || true

touch /var/lib/gdm/run-initial-setup
