#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define log and secure password files
LOG_FILE="/var/log/user_management.log"
SECURE_PASSWORD_FILE="/var/secure/user_passwords.txt"
SECURE_PASSWORD_CSV="/var/secure/user_passwords.csv"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/WandesDummySlack/webhook/url"

# Define custom exit codes
E_INVALID_INPUT=10
E_USER_CREATION_FAILED=20
E_GROUP_CREATION_FAILED=30
E_ADD_USER_TO_GROUP_FAILED=40

# Define resource limits
ulimit -t 60  # CPU time limit in seconds
ulimit -v 1000000  # Virtual memory limit in kilobytes

# Ensure log and secure password directories/files exist
sudo mkdir -p /var/log
sudo mkdir -p /var/secure
sudo touch "$LOG_FILE"
sudo touch "$SECURE_PASSWORD_FILE"
sudo touch "$SECURE_PASSWORD_CSV"
sudo chmod 600 "$SECURE_PASSWORD_FILE"
sudo chmod 600 "$SECURE_PASSWORD_CSV"

# Function to log messages to the log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Function to send notifications to Slack
send_slack_notification() {
    local message=$1
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" "$SLACK_WEBHOOK_URL"
}

# Function to generate a random password of length 12
generate_random_password() {
    < /dev/urandom tr -dc A-Za-z0-9 | head -c12
}

# Function to validate input format for username and groups
validate_input() {
    local username=$1
    local groups=$2

    if [[ -z "$username" || -z "$groups" ]]; then
        log "Error: Invalid input. Username and groups are required."
        send_slack_notification "Invalid input provided. Username and groups are required."
        exit $E_INVALID_INPUT
    fi
}

# Function to create a user and set up their home directory
create_user() {
    local username=$1
    local password=$2

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        log "User $username already exists. Skipping user creation."
    else
        log "Creating user $username."
        # Attempt to create the user with a timeout
        timeout 10 sudo useradd -m -s /bin/bash "$username" || {
            log "Failed to create user $username."
            send_slack_notification "Failed to create user $username."
            exit $E_USER_CREATION_FAILED
        }
        # Set the user's password and home directory permissions
        echo "$username:$password" | sudo chpasswd
        sudo chmod 700 "/home/$username"
        sudo chown "$username:$username" "/home/$username"
        log "User $username created successfully with password $password."
        echo "$username:$password" | sudo tee -a "$SECURE_PASSWORD_FILE" > /dev/null
        echo "$username,$password" | sudo tee -a "$SECURE_PASSWORD_CSV" > /dev/null
    fi
}

# Function to create a group
create_group() {
    local groupname=$1

    # Check if the group already exists
    if getent group "$groupname" &>/dev/null; then
        log "Group $groupname already exists."
    else
        log "Creating group $groupname."
        # Attempt to create the group with a timeout
        timeout 10 sudo groupadd "$groupname" || {
            log "Failed to create group $groupname."
            send_slack_notification "Failed to create group $groupname."
            exit $E_GROUP_CREATION_FAILED
        }
        log "Group $groupname created successfully."
    fi
}

# Function to add a user to a group
add_user_to_group() {
    local username=$1
    local groupname=$2

    # Check if the user is already a member of the group
    if id -nG "$username" | grep -qw "$groupname"; then
        log "User $username is already a member of $groupname."
    else
        log "Adding user $username to group $groupname."
        # Attempt to add the user to the group with a timeout
        timeout 10 sudo usermod -aG "$groupname" "$username" || {
            log "Failed to add user $username to group $groupname."
            send_slack_notification "Failed to add user $username to group $groupname."
            exit $E_ADD_USER_TO_GROUP_FAILED
        }
        log "User $username added to group $groupname successfully."
    fi
}

# Function to rollback user creation if an error occurs
rollback_user_creation() {
    local username=$1

    # Check if the user exists before attempting to remove them
    if id "$username" &>/dev/null; then
        log "Rolling back creation of user $username."
        sudo deluser --remove-home "$username"
        log "User $username removed."
    fi
}

# Function to onboard a user
onboard_user() {
    local username=$1
    local groups=$2

    # Validate the input format
    validate_input "$username" "$groups"

    # Generate a random password for the user
    local password=$(generate_random_password)

    # Create the user with the generated password
    create_user "$username" "$password"

    # Create a personal group for the user
    create_group "$username"

    # Add the user to their personal group
    add_user_to_group "$username" "$username"

    # Process and add the user to the specified groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace from group name
        create_group "$group"
        add_user_to_group "$username" "$group"
    done

    # Notify terminal that user has been successfully onboarded
    echo "User $username has been successfully onboarded with groups: $groups"
}

# Check if the script argument is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <users_file>"
    exit 10  # Invalid input exit code
fi

# Read from the provided text file
users_file="$1"

# Read from the input file and process each line
while IFS=';' read -r username groups; do
    # Remove leading and trailing whitespaces
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    onboard_user "$username" "$groups"
done < "$users_file"

