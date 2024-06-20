#!/bin/bash

# check if a command line tool is installed
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install $1 before running this script."
        exit 1
    fi
}

# display menu and get user choice
display_menu() {
    echo "Select your preferred storage provider:"
    echo "1. Amazon S3 (AWS)"
    echo "2. MinIO"
    read -p "Enter your choice [1-2]: " choice
    case $choice in
        1) storage_type="aws";;
        2) storage_type="minio";;
        *) echo "Invalid choice. Please enter 1 or 2."; exit 1;;
    esac
}

# get user input for path to backup
get_user_input() {
    read -e -p "Please enter a path to backup (use TAB for completion): " path
    echo "$path"
}

# validate the path is a non-empty string and exists
validate_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        echo "Error: Path cannot be empty."
        return 1
    elif [[ ! -d "$path" ]]; then
        echo "Error: Path does not exist or is not a directory."
        return 1
    else
        return 0
    fi
}

# create a backup and compress it
backup_and_compress() {
    local path="$1"
    local backup_name="backup_$(basename "$path")_$(date +%Y%m%d%H%M%S).tar.gz"
    tar -czf "$backup_name" -C "$path" .
    echo "$backup_name"
}

# upload to S3 using AWS-CLI
upload_to_s3() {
    local file="$1"
    local bucket_name="$2"
    aws s3 cp "$file" "s3://$bucket_name/"
    return $?
}

# upload to MinIO using MinIO-Client 
upload_to_minio() {
    local file="$1"
    local bucket_name="$2"
    mc cp "$file" "myminio/$bucket_name/"
    return $?
}

# cleanup after successful upload
cleanup_after_upload() {
    local result="$1"
    local file="$2"
    if [[ $result -eq 0 ]]; then
        rm "$file"
        echo "Backup file removed."
    else
        echo "Failed to upload. Please check AWS configuration or MinIO settings."
    fi
}

# Main script
main() {
    check_command "aws"

    #check_command "mc"

    display_menu

    user_path=$(get_user_input)

    if ! validate_path "$user_path"; then
        exit 1
    fi

    backup_file=$(backup_and_compress "$user_path")

    # Ask the user for S3 bucket details
    echo "Please enter the S3 bucket name:"
    read -e -p "> " bucket_name

    # Upload the backup to the selected storage provider
    if [[ "$storage_type" == "aws" ]]; then
        upload_to_s3 "$backup_file" "$bucket_name"
        upload_result=$?
    elif [[ "$storage_type" == "minio" ]]; then
        upload_to_minio "$backup_file" "$bucket_name"
        upload_result=$?
    else
        echo "Invalid storage type."
        exit 1
    fi

    cleanup_after_upload "$upload_result" "$backup_file"
    if [ upload_result = 0 ]; then
        echo "Backup and upload process completed."
    fi
}

main
