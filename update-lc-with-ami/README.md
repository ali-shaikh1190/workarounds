#update_lc_with_ami

This Script creates New Launch Configuration for AutoScaling with given Name in parameter LC_NAME.
#####Steps
- Creates AMI of the given ip address as argument
- Delete existing LaunchConfiguration if present
- Creates a new LaunchConfiguration with the new AMI

Requirements
------------
ec2= Access Key 
ec2= Secret Key

For managing ec2 API Access.

Dependencies
------------
None

Example
-------
./update_lc_with_ami.sh <ip>

ip = ec2 instance private ip.


Author Information
------------------
Qamar Ali Shaikh.

