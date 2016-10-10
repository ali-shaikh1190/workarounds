##################################################################################
#Create VPC & Instance using Command line:

- Create VPC:
aws ec2 create-vpc --cidr-block 10.20.0.0/16 

- Create IGW:
aws ec2 create-internet-gateway 

- Attach IGW:
aws ec2 attach-internet-gateway --internet-gateway-id $internetGatewayId --vpc-id $vpcId

- Create Subnet:
aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.20.10.0/24 
aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.20.150.0/24 

- Create Subnet in specific zone:
aws ec2 create-subnet --availability-zone us-west-2c --vpc-id $vpcId --cidr-block 10.20.15.0/24 

- Create Route Table:
aws ec2 create-route-table --vpc-id $vpcId 

- Subnet Association in Route table:
aws ec2 associate-route-table --route-table-id $routetableId --subnet-id $subnetId

- Create Internet Gateway route in RouteTable:
aws ec2 create-route --route-table-id $routetableId --destination-cidr-block 0.0.0.0/0 --gateway-id $internetgatewayId

- Create Security Group:
aws ec2 create-security-group --group-name my-security-group --description "my-security-group" --vpc-id $vpcId 

- Add 22 port inbound Rule in SG:
aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 22 --cidr 0.0.0.0/0
#################################################################################
#EC2 Step:

- Create PEM File:
aws ec2 create-key-pair --key-name my-key   > ~/.ssh/my-key.pem
chmod 0600 ~/.ssh/my-key.pem

- Launch Instance:
aws ec2 run-instances --image-id ami-9abea4fb --count 1 --instance-type t2.micro --key-name my-key --security-group-ids $sgId --subnet-id $subnetId --associate-public-ip-address 


###################################################################################################
#Extra Commands:

- For IP Address List including private and public:   
aws ec2 --no-verify-ssl describe-addresses --filters "Name=domain,Values=vpc"


- Describe Instance ID, Private IP & Public IP:
aws ec2 --no-verify-ssl describe-addresses --filters "Name=domain,Values=vpc" --region us-west-2 --output text | awk {'print $5, $8, $9'}


- Describe Tags:
aws ec2 --no-verify-ssl describe-tags --filters "Name=value,Values=PROD"

- To Create multiple volumes in aws:

for i in {1..3}; do aws ec2 --no-verify-ssl create-volume --size 100 --region us-east-1 --availability-zone us-east-1d --volume-type standard; done

- Create autorecovery alarm for any instance:
aws cloudwatch --no-verify-ssl put-metric-alarm --alarm-name Recover_instance_id --alarm-description "Recover the instance $instance_ID" --namespace "AWS/EC2" --dimensions "Name=InstanceId,Value=$InstanceID" --statistic Average --metric-name StatusCheckFailed_System --comparison-operator GreaterThanThreshold --threshold 0 --period 60 --evaluation-periods 2 --alarm-actions {arn:aws:automate:us-west-1:ec2:recover,arn:aws:sns:us-west-1:172221034640:$sns_topic_name} --actions-enabled --region us-west-1



- Create autorecovery alarm for multiple instance: Copy paste all instance-id in instance_ids_file.
for i in `awk {'print $1'} instance_ids_file`; do aws cloudwatch --no-verify-ssl put-metric-alarm --alarm-name Recover_instance_$i --alarm-description "Recover the instance $i" --namespace "AWS/EC2" --dimensions "Name=InstanceId,Value=$i" --statistic Average --metric-name StatusCheckFailed_System --comparison-operator GreaterThanThreshold --threshold 0 --period 60 --evaluation-periods 2 --alarm-actions {arn:aws:automate:us-east-1:ec2:recover,arn:aws:sns:us-east-1:172221034640:status_check_failed} --actions-enabled --region us-east-1; done


- To Delete Alarms:
aws cloudwatch --no-verify-ssl delete-alarms --alarm-names Recover_instance_instance-id

- To create new EIP:
aws ec2 --no-verify-ssl allocate-address --domain vpc --region us-west-2

- To associate EIP to any instance:
aws ec2 --no-verify-ssl associate-address --instance-id i-a4fed261 --allocation-id eipalloc-9d5edcf8 --region us-west-2

- To Teminate Instances use below command:
for i in `cat test1`; do aws ec2 --no-verify-ssl terminate-instances --instance-ids $i; done

- To Teminate multiple Instances use below command: copy paste all instance id in test1 file, Only those instance id you want to be terminated.
for i in `cat test1`; do aws ec2 --no-verify-ssl terminate-instances --instance-ids $i; done

-Get the VOL ID of Instances:
for i in `awk {'print $1'} test_id`; do aws ec2 describe-instances --no-verify-ssl --instance-id $i --region us-west-1 | grep -i VolumeId | awk {'print $4'} ; done | nl

- Search Volume with respective size:
for i in `awk {'print $1'} ids`; do aws ec2 describe-volumes --no-verify-ssl --region us-east-1 --filters Name=attachment.instance-id,Values=$i | egrep "VolumeId|Size|gp2"  | grep Size -A1

- To Create Tag:
for i in `awk {'print $1'} id_panamax`; do aws ec2 --no-verify-ssl create-tags --resources $i --tags Key=Stack,Value=Staging; done

- Change Instance Type:
for i in ` awk {'print $1'} Prod-cdh5-instace-id`; do  aws --no-verify-ssl ec2 modify-instance-attribute --instance-id $i --instance-type r3.2xlarge; done

- To get all snapshot Id by their names:
aws ec2 --no-verify-ssl describe-snapshots --owner-ids aws_account_no. --filters Name=status,Values=completed | egrep 'UG-AWS-WEB-1.0_Daily|UG-AWS-APP-02_Daily|UG-AWS-ME-1.6_Daily|UG-AWS-APP-01_Daily|2.0.UAT_Drools_Daily|2.0.UAT_Daily|2.0.Prod_Solr_Daily|1.6.Prod_Demo_Daily|2.0.Prod_Drools_Daily|2.0.Prod_Demo_Daily|SnapshotId' | uniq > Snapshot_id_remove

- To Remove old snapshot use below commands with the help of above command you will get the snapshot ids:
for i in `awk {'print $1'} Snapshot_id_remove`; do aws ec2 --no-verify-ssl delete-snapshot --snapshot-id $i; done

- Force Detach volume:
for i in `awk {'print $1'} volume`; do aws ec2 --no-verify-ssl --region us-east-1 detach-volume --force --volume-id $i; done

- Delete volume:
for i in `awk {'print $1'} volume`; do aws ec2 --no-verify-ssl --region us-east-1 delete-volume --volume-id $i; done

# Delete Volume Snapshots Step:

1. Tag the volumes:
for i in `awk {'print $1'} snapshot-id-weekly`; do aws ec2 --no-verify-ssl create-tags --resources $i --tags Key=Name,Value=Prod --region us-east-1; done

2. This will pickup the snapshot ID and Timestamp:
aws ec2 --no-verify-ssl describe-snapshots --filters  Name=tag-value,Values="Prod" --query 'Snapshots[*].{ID:SnapshotId,Time:StartTime}' --region us-east-1 > snapshot-daily

OR

aws ec2 --no-verify-ssl describe-snapshots --filters  Name=tag-value,Values="Prod" --query 'Snapshots[*].{ID:SnapshotId,Time:StartTime}' --region us-east-1 | grep "2015" | awk {'print $2'}  > snapshot-ids-weekly

3. Delete Snapshot:
for i in `awk {'print $1'} snapshot-ids-only`; do aws ec2 --no-verify-ssl delete-snapshot --snapshot-id $i --region us-east-1; done

- Change Security Group of any instance:
aws ec2 --no-verify-ssl modify-instance-attribute --instance-id $instance_ID --groups sg-f45b4a91 --region us-west-1;

