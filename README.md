# About

[![forthebadge](http://forthebadge.com/images/badges/built-with-love.svg)](http://forthebadge.com)
[![forthebadge](http://forthebadge.com/images/badges/powered-by-oxygen.svg)](http://forthebadge.com)
[![forthebadge](http://forthebadge.com/images/badges/fuck-it-ship-it.svg)](http://forthebadge.com)

This is the script that can help you create EBS snapshots for your EC2 instances.

# Prerequisites
* awscli - pip install awscli
* jq - yum install jq
* mail - yum install mail
* IAM Role Policy

# IAM Role Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt0123456789012",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:DeleteSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:DescribeVolumes"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

# Usage
```
Usage: ./ebs-snapshot-v2.sh [-r <region>] [-b | -d <age>]
       	-r     	: AWS region
                  us-east-1    		ap-northeast-1
                  us-west-1    		ap-northeast-2
                  us-west-2    		ap-southeast-1
                  eu-west-1    		ap-southeast-2
                  eu-central-1 		sa-east-1
        -b     	: backup EBS
        -d     	: delete snapshot
        <age>  	: day

Examples:
        ./ebs-snapshot-v2.sh -r us-east-1 -b (creates snapshots in us-east-1)
        ./ebs-snapshot-v2.sh -r ap-southeast-1 -d 3 (removes 3-day old snapshots in ap-southeast-1)
```
