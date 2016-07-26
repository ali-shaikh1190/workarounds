#!/bin/bash

echo "Installing Grub"
/usr/sbin/grub-install /dev/xvdf
echo "Rechecking Installation of Grub"
/usr/sbin/grub-install --recheck /dev/xvdf
echo "updating Grub"
/usr/sbin/update-grub
echo "exiting chroot"
exit
