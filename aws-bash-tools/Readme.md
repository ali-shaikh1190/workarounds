# Shell scripts to ease some AWS administration tasks.

* aws-common.sh - Common vars and functions, meant to be sourced by other scripts

* backup-volumes-into-snapshots.sh - Backup one or more volumes by making snapshots. 
Supports snapshot multi-tagging and description. 
Can operate in synchronous mode. 

Example of usage:

    ./backup-volumes-into-snapshots.sh -s -v vol-bcf905d4 -d Hourly_backup -t "Content=Database" -t "backup=hourly"

* find-vols-by-tag.sh - Find volumes by a given tag. Example of usage:

Example of usage:

    ./find-vols-by-tag.sh -t Content=Database

* find-vols-attached-to-instance.sh - Search for volumes attached to a given instance. Example of usage:

Example of usage:

    ./find-vols-attached-to-instance.sh -i i-9293812

* clean-old-snapshots.sh - Clean old snapshots. Supports snapshot filtering (any criteria supported by ec2 api tools).
It leaves untouched all snapshots not older than X days, and leave one per day for any snapshot not older than Y days (given that 0 < X < Y).

Example of usage: 

    ./clean-old-snapshots.sh -f tag:backup=hourly -a 1 -d 7

* ec2-describe-instances-for-humans - Describe instances of one or more regions (or all of them if none specified)
in a more human-friendly format. 

Example of usage:
    
    ./ec2-describe-instances-for-humans.sh -r eu-west-1 -r us-east-1
