#!/bin/bash

# Title: remove_old_amis.sh - Remove Old AMIs After 7 Days

# Global Variables
RETENTION_PERIOD=7 # Days, change as needed
REGION="${AWS_REGION}"
DRY_RUN="${DRY_RUN:-true}"

# Function to get the list of AMIs older than the retention period
get_old_amis() {
    local cutoff_date
    cutoff_date=$(date -d "-${RETENTION_PERIOD} days" +%Y-%m-%dT%H:%M:%S)
   
    local old_amis
    old_amis=$(aws ec2 describe-images --region "$REGION" --owners self \
        --query "Images[?CreationDate<'$cutoff_date'].ImageId" \
        --output text)
   
    printf "%s\\n" "$old_amis"
}

# Function to deregister an AMI
deregister_ami() {
    local ami_id=$1
   
    if [ "$DRY_RUN" = "true" ]; then
        printf "DRY-RUN: Would deregister AMI: %s\\n" "$ami_id"
        return 0
    fi

    if ! aws ec2 deregister-image --region "$REGION" --image-id "$ami_id"; then
        printf "Failed to deregister AMI: %s\\n" "$ami_id" >&2
        return 1
    fi
   
    printf "Successfully deregistered AMI: %s\\n" "$ami_id"
}

# Function to remove snapshots associated with an AMI
remove_snapshots() {
    local ami_id=$1
   
    local snapshot_ids
    snapshot_ids=$(aws ec2 describe-images --region "$REGION" --image-ids "$ami_id" \
        --query "Images[].BlockDeviceMappings[].Ebs.SnapshotId" --output text)
   
    if [[ -z "$snapshot_ids" ]]; then
        printf "No snapshots found for AMI: %s\\n" "$ami_id"
        return
    fi
   
    local snapshot_id
    for snapshot_id in $snapshot_ids; do
        if [ "$DRY_RUN" = "true" ]; then
            printf "DRY-RUN: Would delete snapshot: %s\\n" "$snapshot_id"
            continue
        fi

        if ! aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$snapshot_id"; then
            printf "Failed to delete snapshot: %s\\n" "$snapshot_id" >&2
            return 1
        fi
       
        printf "Successfully deleted snapshot: %s\\n" "$snapshot_id"
    done
}

# Main function
main() {
    local old_amis
    old_amis=$(get_old_amis)
   
    if [[ -z "$old_amis" ]]; then
        printf "No AMIs older than %d days found.\\n" "$RETENTION_PERIOD"
        return 0
    fi
   
    local ami_id
    for ami_id in $old_amis; do
        if ! deregister_ami "$ami_id"; then
            continue
        fi
        if ! remove_snapshots "$ami_id"; then
            continue
        fi
    done
}

main "$@"
