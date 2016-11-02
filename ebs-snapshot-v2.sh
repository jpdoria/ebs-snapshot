#!/bin/bash
# Script: ebs-snapshot-v2.sh
# Author: JP <jp@lazyadm.in>
# Date: 2016-04-12
# Prerequisites:
# * awscli - pip install awscli
# * jq - yum install jq
# * mail - yum install mail
# * IAM Role Policy
#	* "ec2:CreateSnapshot"
#	* "ec2:CreateTags"
# 	* "ec2:DeleteSnapshot"
#	* "ec2:DescribeSnapshots"
#	* "ec2:DescribeVolumes"

LOCKFILE=/tmp/.ebs-snapshot.lock
TEMPFILE=/tmp/.ebs-snapshot-${RANDOM}.tmp
DOMAIN=company.com
MAILFROMNAME="AWS Notification"
MAILFROM=aws-notification@$DOMAIN
MAILTO=("user1@$DOMAIN" "user2@$DOMAIN" "user3@$DOMAIN")
SYSLOG=/var/log/messages

# Check or create lock file
if [ ! -e $LOCKFILE ]; then
	echo $$ > $LOCKFILE
else
	kill -0 $(cat $LOCKFILE) && echo "$0 is already running $(cat $LOCKFILE)"
	exit 1
fi

cleanup() {
	rm -f $LOCKFILE $TEMPFILE
}

trap "echo 'Interrupted!; cleanup; exit 1" 1 2 3 15

usage() {
cat <<EOF
Usage: $0 [-r <region>] [-b | -d <age>]
	-r	: AWS region
		  us-east-1		ap-northeast-1
		  us-west-1		ap-northeast-2
		  us-west-2		ap-southeast-1
		  eu-west-1		ap-southeast-2
		  eu-central-1		sa-east-1
        -b	: backup EBS
        -d	: delete snapshot
        <age>	: day

Examples:
        $0 -r us-east-1 -b (creates snapshots in us-east-1)
        $0 -r ap-southeast-1 -d 3 (removes 3-day old snapshots in ap-southeast-1)
EOF
cleanup
}

backup_ebs() {
	echo "EBS Auto-snapshot v2.0"
	echo "Starting creating snapshots..."
	for VOLUME in $(aws ec2 describe-volumes --region $REGION | jq .Volumes[].VolumeId | sed 's/\"//g'); do
		echo -e "Creating snapshot for $VOLUME... \c"
		aws ec2 create-snapshot --region $REGION --volume-id $VOLUME --description "Created by ebs-snapshot.sh" | jq .SnapshotId | sed 's/\"//g' >> $TEMPFILE
		if [ $? -eq 0 ]; then
			echo "Successful!"
		else
			echo "Failed!"
		fi
	done
	SNAPSHOTID=($(cat $TEMPFILE))
	for A in ${SNAPSHOTID[@]}; do
		aws ec2 create-tags --region $REGION --resources $A --tags Key="Name",Value="AWS Daily EBS Snapshot"
	done
	echo -e "Sending notification... \c"
	aws ec2 describe-snapshots --region $REGION --filters Name=snapshot-id,Values=$(IFS=,; echo "${SNAPSHOTID[*]}") --query "Snapshots[*].{SnapshotId:SnapshotId,Time:StartTime}" --output table | mail -s "EBS Snapshots for $REGION | Snapshots created as of $(date "+%Y-%m-%d %H:%M:%S")" -r "$MAILFROMNAME<$MAILFROM>" ${MAILTO[@]}
	if [ $? -eq 0 ]; then
		echo "Successful!"
	else
		echo "Failed!"
	fi
	cleanup
}

delete_snapshots() {
	echo "EBS Auto-snapshot v2.0"
	echo "Checking $AGE-day old snapshots..." | tee -a $TEMPFILE
	for SNAPSHOT in $(aws ec2 describe-snapshots --region $REGION --filters Name=description,Values="Created by ebs-snapshot.sh"| jq .Snapshots[].SnapshotId | sed 's/\"//g'); do
		SNAPSHOTDATE=$(aws ec2 describe-snapshots --region $REGION --filters Name=snapshot-id,Values=$SNAPSHOT | jq .Snapshots[].StartTime | cut -d T -f1 | sed 's/\"//g')
		STARTDATE=$(date +%s)
		ENDDATE=$(date -d $SNAPSHOTDATE +%s)
		INTERVAL=$[(STARTDATE - ENDDATE) / (60*60*24)]
		if (($INTERVAL >= $AGE)); then
			echo -e "Removing $SNAPSHOT... \c" | tee -a $TEMPFILE
			aws ec2 delete-snapshot --region $REGION --snapshot-id $SNAPSHOT > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Successful!" | tee -a $TEMPFILE
			else
				echo "Failed!" | tee -a $TEMPFILE
			fi
		fi
	done
	LINECOUNT=$(wc -l $TEMPFILE | cut -d ' ' -f1)
	if [ $LINECOUNT -eq 1 ]; then
		echo "Nothing to do here."
		echo "$(date "+%b %d %H:%M:%S") localhost $0[$$]: delete_snapshots - nothing to do here." >> $SYSLOG
	else
		echo -e "Sending notification... \c"
		cat $TEMPFILE | mail -s "EBS Snapshots for $REGION | Snapshots removed as of $(date "+%Y-%m-%d %H:%M:%S")" -r "$MAILFROMNAME<$MAILFROM>" ${MAILTO[@]}
		if [ $? -eq 0 ]; then
			echo "Successful!"
		else
			echo "Failed!"
		fi
	fi
	cleanup
}

while getopts ":r:bd:" OPT; do
    case $OPT in
	r)	REGION=$OPTARG
		;;
        b)	backup_ebs
		;;
        d)	AGE=$OPTARG
		delete_snapshots
		;;
	\?)	echo "Invalid option: -$OPTARG"
		usage
		exit 1
		;;
	:)	echo "Option -$OPTARG requires an argument"
		usage
		exit 1
    esac
done

# Prevent no option
if [ $OPTIND -eq 1 ]; then
	usage
	cleanup
	exit 1
fi
