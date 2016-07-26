#!/bin/bash
# Qamar |System Engg @ Webaroo
# Date -- 08/09/2015
# Stop the EC2 instance, Resize the EBS volume and reattch it.

export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=

if [[ ! $2 ]] || [[ ! $1 ]] ; then
  echo "Usage: $(basename $0) INSTANCE_IP SIZE"
  echo
  echo "      INSTANCE_IP - The EC2 instance whose EBS volume you wish to resize."
  echo "             SIZE - The new size for the EBS volume (In gigabytes)."
  exit 1
fi

# IP of the server
INSTANCE_IP=$1
#Get Instance ID from Instance-IP
INSTANCE_ID=$(ec2-describe-instances --filter "private-ip-address=$INSTANCE_IP"|tail -n1|awk '{print $3}')
#Fetch Instance_name
INSTANCE_NAME=$(ec2-describe-tags --filter "resource-id=$INSTANCE_ID" --filter "key=Name" | cut -f5)
# Get the availability zone for the remote EC2 instance
zone=$(ec2-describe-instances $INSTANCE_ID | egrep ^INSTANCE | cut -f12)
tag_old_volume="$INSTANCE_NAME-$INSTANCE_IP-/dev/sda1-OG"
size=$2

# Get the root EBS volume id for the remote EC2 instance
oldvolumeid=$(ec2-describe-instances $INSTANCE_ID | egrep "^BLOCKDEVICE./dev/sda1" | cut -f3)

#Tag Old Volume to identify.
echo "Creating Tag to identify Old Volume"
ec2-create-tags $oldvolumeid --tag Name="$tag_old_volume"

echo "Resing the Instance $INSTANCE_IP with Given size $size"

# Detach the original volume from the instance
echo "Detaching the EBS volume $oldvolumeid from the instance $INSTANCE_IP..."
while ! ec2-detach-volume $oldvolumeid; do sleep 1; done
echo
while ! ec2-describe-volumes $oldvolumeid|grep -q available;do echo "Detaching Volume...";sleep 1;done
echo

# Create a snapshot of the original volume
echo "Create a snapshot of the EBS volume $oldvolumeid for safety and sync operation.."
snapshotid=$(ec2-create-snapshot $oldvolumeid --description "Backup of $INSTANCE_IP before resizing the EBS volume to $size GB" | cut -f2)
while ec2-describe-snapshots $snapshotid | grep -q pending; do echo "Creating Snapshot...";sleep 30; done
echo

# Set the tags on the EBS snapshot
echo "Set tags on the EBS snapshot $snapshotid..."
ec2-create-tags $snapshotid --tag "Name=$INSTANCE_NAME-$INSTANCE_IP" --tag "Type=root"

#Create Volume from Snapshot to Perform Sync and Resize Operations.
echo "Creating volume from snapshot $snapshotid for replicating data from oldvolume to newvolume..."
snapshotvolumeid=$(ec2-create-volume --snapshot $snapshotid  --availability-zone $zone --type gp2 |cut -f2)
echo
while ! ec2-describe-volumes $snapshotvolumeid|grep -q available;do echo "Creating Volume...";sleep 1;done
echo

# Set the tags on the Snapshot EBS volume
echo "Set tags on the Snapshot EBS volume $snapshotvolumeid..."
ec2-create-tags $snapshotvolumeid --tag "Name=$INSTANCE_NAME-$INSTANCE_IP-/dev/sda1-500G-SNAPSHOT" --tag "Type=root"
echo

# create a new volume for shrinking
echo "Creating a new empty volume for replicating data from oldvolume..."
newvolumeid=$(ec2-create-volume --availability-zone $zone --size $size --type gp2 |cut -f2)
echo
while ! ec2-describe-volumes $newvolumeid|grep -q available;do echo "Creating Volume...";sleep 1;done
echo

# Set the tags on the EBS volume
echo "Set tags on the New EBS volume $newvolumeid..."
ec2-create-tags $newvolumeid --tag "Name=$INSTANCE_NAME-$INSTANCE_IP-/dev/sda1-$size" --tag "Type=root"
echo

# Attach the new volume to the instance
#running_instance=$(curl -sS http://169.254.169.254/latest/meta-data/instance-id)
running_instance=$(ec2-describe-instances --filter "private-ip-address=10.50.0.253"|tail -n1|awk '{print $3}')
echo "Attaching the new EBS volume $newvolumeid to the EC2 resizing server..."
ec2-attach-volume --instance $running_instance --device /dev/sdf $newvolumeid
while ! ec2-describe-volumes $newvolumeid | grep -q attached; do sleep 1; done
echo

echo "Verifying Disk attached to Server"
while ! lsblk /dev/xvdf; do sleep 1; done
echo "New Volume Attached to Resizing Server"
echo

echo "Attaching the Snapshot EBS volume $snapshotvolumeid to the EC2 resizing server..."
ec2-attach-volume --instance $running_instance --device /dev/sdg $snapshotvolumeid
while ! ec2-describe-volumes $snapshotvolumeid | grep -q attached; do sleep 1; done
echo

echo "Verifying Disk attached to Server"
while ! lsblk /dev/xvdg1; do sleep 1; done
echo "Snapshot Volume Attached to Resizing Server"

echo "Running Filesystem Check on Snapshot Volume attached to /dev/sdg"
/sbin/e2fsck -f -y /dev/xvdg1
echo

echo "Refverifying if any"
/sbin/e2fsck -f -y /dev/xvdg1
echo

echo "Shrinking /dev/xvdg1 to minimum size"
/sbin/resize2fs -M -p /dev/xvdg1
echo

echo "Reverifying if any"
/sbin/resize2fs -M -p /dev/xvdg1
echo

echo "Rerunning File system Check on /dev/sdg"
/sbin/e2fsck -f -y /dev/xvdg1

sleep 20

echo "Creating Partition on the New Volume as per old_volume with size $size"
/sbin/sfdisk /dev/xvdf < /root/my.layout
echo 

echo "Partition Created"
echo "Formatting New Volume attached to /dev/xvdf1"
format_status=$(file -s /dev/xvdf1 -s|grep -io "Linux")
echo "Verifying Format Status"
        if [ "$format_status" != "Linux" ];then
                echo "Formatting /dev/xvdf1"
                mkfs.ext4 /dev/xvdf1
                echo "New Volume Formatted it can now be mounted"
                echo "Mounting New Volume to /new_volume"
                mkdir -pv /new_volume
                mount /dev/xvdf1 /new_volume
                echo "New Volume Mounted"
        else
                echo "Device is Formatted"
                echo "Mounting New Volume to /new_volume"
                mkdir -pv /new_volume
                mount /dev/xvdf1 /new_volume
                echo "New Volume Mounted"
        fi

echo "Mounting Snapshot Volume to /old_volume"
        mkdir -pv /old_volume
        mount /dev/xvdg1 /old_volume

sleep 10

echo "Syncing Data from Snapshot Volume to New volume"
rsync -aHAXxS /old_volume/ /new_volume
if [ $? -eq 0 ];then
        echo "Rsync Completed Succesfully"
fi

sleep 10

echo "ReVerifying Data sync from Old Volume to New Volume"
rsync -aHAXxS  /old_volume/ /new_volume
echo

sleep 10

echo "verifying e2Label of New Volume"
e2label=$(e2label /dev/xvdf1)
if [ "$e2label" == "" ];then
        echo "No Label Defined"
        echo "verifying from old Volume"
        newe2label=$(e2label /dev/xvdg1)
        echo "Assigning e2label to new volume"
        e2label /dev/xvdf1 $newe2label
        echo "Reverifying e2label"
        e2label /dev/xvdf1
        echo
fi

echo "Mapping UUID of Snapshot Volume to New Volume"
uuid=$(lsblk -no NAME,UUID /dev/xvdg1|awk '{print $2}')
/sbin/tune2fs /dev/xvdf1 -U $uuid

echo "UUID for New Volume is"
uuid=$(lsblk -no NAME,UUID /dev/xvdf1|awk '{print $2}')
echo "$uuid"

echo "We are now going to re-install the kernel and grub on the new volume"
for dir in {/dev,/dev/pts,/sys,/proc,/run};
do
        mount -o bind $dir /new_volume$dir;
done
echo "Mounted directories required to Update Grub to New Volume"

echo "Chrooting To New Volume to Install Grub"
cp /root/install_grub.sh /new_volume/root/install_grub.sh
/usr/sbin/chroot /new_volume /bin/bash -c /root/install_grub.sh

echo "Out of Chroot Environment"
echo "UnMounting directories required to Update Grub from New Volume"
for dir in {/dev/pts,/dev,/sys,/proc,/run};
do
        umount /new_volume$dir;
done

echo "Deleting install Grub script"
rm -rf /new_volume/root/install_grub.sh

echo "unmounting New Volume"
while mountpoint -q /new_volume && ! umount /new_volume; do
  sleep 1
done
echo "Device unmounted"

echo "unmounting Snapshot Volume"
while mountpoint -q /old_volume && ! umount /old_volume; do
  sleep 1
done
echo "Device unmounted"
echo

echo "Verifying Status of New Volume and correcting if any.."
e2fsck -f -y /dev/xvdf1
echo "Filesystem Verified"
echo

# Detach the old volume from the resizing instance
echo "Detaching the Snapshot volume $snapshotvolumeid  from the resizing instance..."
while ! ec2-detach-volume $snapshotvolumeid; do sleep 1; done
echo
while ! ec2-describe-volumes $snapshotvolumeid|grep -q available;do echo "Detaching Volume...";sleep 1;done
echo

# Detach the new volume from the resizing instance
echo "Detaching the New volume $newvolumeid from the resizing instance..."
while ! ec2-detach-volume $newvolumeid; do sleep 1; done
echo
while ! ec2-describe-volumes $newvolumeid|grep -q available;do echo "Detaching Volume...";sleep 1;done
echo

#Attach New volume which is resized to the old Instance which needed resizing
echo "Now Attaching New Volume to the Instance $INSTANCE_IP $INSTANCE_ID"
ec2-attach-volume --instance $INSTANCE_ID --device /dev/sda1 $newvolumeid
while ! ec2-describe-volumes $newvolumeid | grep -q attached; do sleep 1; done
echo

echo "Starting up Instance $INSTANCE_IP $INSTANCE_ID"
ec2-start-instances $INSTANCE_ID
while ! ec2-describe-instances $INSTANCE_ID | grep -q running; do sleep 1; done
echo

echo "Verifying if machine is UP"
while ! nc -z $INSTANCE_IP 22 ;do echo booting-Up....;sleep 20;done;
echo

echo "Verifying Resized Disk"
#resized_volume_size=$(ssh -qo StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "df -hT /dev/xvda1 | grep -v Filesystem" | awk '{ print $3 }')
resized_volume_size=$(ansible -m shell -a "df -hT /dev/sda1" $INSTANCE_IP -s|egrep -hiv "File|$INSTANCE_IP"|awk '{print $3}'|tr -d "\n")
echo "Resized Volume Size is $resized_volume_size"
echo

echo "Turning on delete-on-termination so that the new EBS volume will be deleted when the EC2 instance is terminated as is common with EC2 instances..."
ec2-modify-instance-attribute --block-device-mapping  /dev/sda1=$newvolumeid:true $INSTANCE_ID
echo

#####################################################################################################

# Commented Because we can delete OLD volumes once we haveVerified all instances.

## Delete the old EBS volume
echo "Run Following Commands Manually if everythins is working fine.."
echo "ec2-delete-volume $oldvolumeid"
echo "ec2-delete-snapshot $snapshotid"
echo "ec2-delete-volume $snapshotvolumeid"
echo
