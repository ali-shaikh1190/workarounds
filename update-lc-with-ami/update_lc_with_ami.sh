#!/bin/bash
#Update Launch Configuration on AutoScaling Group.
#Qamar Ali
#Date - 13-10-16
######## Configuration Paramaters ###############

INSTANCE_IP=$1
LC_NAME="Dynamic-Launch-ConfigurationAutoScaling-ProdA"
key_name="ec2-keypair-name"
security_group="sg-id"
instance_type="t2.medium"
instance_profile="Automation"
aminame="web-prod-ami-$(date +%Y-%m-%d)"

LC_NAME_CHECK="$(aws autoscaling describe-launch-configurations --launch-configuration-names LaunchConfigurationAutoScalingProdA --query 'LaunchConfigurations[*].[LaunchConfigurationName]' --output text)"

if [ "$LC_NAME" == "$LC_NAME_CHECK" ];then
        echo "Deleting existing LC: $LC_NAME"
        aws autoscaling delete-launch-configuration --launch-configuration-name $LC_NAME
else
        echo "No LC with Name $LC_NAME found"
fi

INSTANCE_ID=$(aws ec2 describe-instances --region ap-southeast-1 --filter "Name=private-ip-address,Values=$INSTANCE_IP" --query 'Reservations[*].Instances[*].[InstanceId]' --output text)

aws ec2 create-image --instance-id $INSTANCE_ID --name $aminame --description "Prod: Standard web server AMI $(date +%Y-%m-%d) " --no-reboot --region ap-southeast-1

while ! aws ec2 describe-images --filter 'Name=name,Values=$aminame' --region ap-southeast-1 --query 'Images[*].[State]' --output text |grep -iq available;do echo "AMI creation is in progress...";sleep 10;done

if [ $? -eq 0 ];then
imageid=$(aws ec2 describe-images --filter 'Name=name,Values=$aminame' --region ap-southeast-1 --query 'Images[*].[ImageId]' --output text)
echo "AMI ID $imageid will be used for the new Launch Configuration."
fi

blk_device_mapping=$(aws ec2 describe-images --filter 'Name=name,Values=$aminame' --region ap-southeast-1 --query "Images[*].BlockDeviceMappings[]" --output json|sed ':a;N;$!ba;s/\n//g'|sed 's/ //g')

echo "Creating LC: $LC_NAME"
aws autoscaling create-launch-configuration --launch-configuration-name $LC_NAME --image-id $imageid --iam-instance-profile $instance_profile --key-name $key_name --security-groups $sec_group --instance-type $instance_type --instance-monitoring Enabled=false --no-ebs-optimized --block-device-mappings $blk_device_mapping

if [ $? -eq 0 ];then
echo "Launch Configuration: $LC_NAME is created with AMI-ID: $imageid"
fi
