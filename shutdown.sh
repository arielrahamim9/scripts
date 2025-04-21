# To run this script directly from GitHub raw:
# curl -s https://raw.githubusercontent.com/your-username/your-repo/main/stop-instance.sh | sh

#!/bin/bash

# Get system uptime and convert to minutes
uptime_str=$(uptime -p)
uptime_minutes=0

# Extract hours and minutes
if [[ $uptime_str =~ ([0-9]+)\ hour[s]? ]]; then
    hours=${BASH_REMATCH[1]}
    uptime_minutes=$((hours * 60))
fi

if [[ $uptime_str =~ ([0-9]+)\ minute[s]? ]]; then
    minutes=${BASH_REMATCH[1]}
    uptime_minutes=$((uptime_minutes + minutes))
fi

echo "Current uptime: $uptime_minutes minutes"

if [ "$uptime_minutes" -ge 180 ]; then
    echo "WARNING: Instance has been running for $uptime_minutes minutes. Initiating stop..."
    # Get the instance ID
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    # Stop the instance
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION"
elif [ "$uptime_minutes" -ge 120 ]; then
    # Calculate minutes remaining until shutdown
    minutes_remaining=$((180 - uptime_minutes))
    echo "NOTICE: Instance has been running for $uptime_minutes minutes. Will stop in $minutes_remaining minutes."
fi
