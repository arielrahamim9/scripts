#!/bin/bash

# Get system uptime in minutes
uptime_minutes=$(uptime -p | awk '{print $2}')

if [ "$uptime_minutes" -ge 180 ]; then
    echo "WARNING: Instance has been running for $uptime_minutes minutes. Initiating stop..."
    # Get the instance ID
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    # Stop the instance
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION"
elif [ "$uptime_minutes" -ge 60 ]; then
    # Calculate minutes remaining until shutdown
    minutes_remaining=$((180 - uptime_minutes))
    echo "NOTICE: Instance has been running for $uptime_minutes minutes. Will stop in $minutes_remaining minutes."
fi
