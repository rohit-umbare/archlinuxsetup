#!/bin/bash
#contact umbarers52@gmail.com
set -e  # Exit on any error

# Directory containing AUR packages
aur_dir="$HOME/aur_packages"

# Variables to track errors
errors=""

# Function to check and update AUR repositories
update_aur_repos() {
    for repo_dir in "$aur_dir"/*/; do
        # Remove trailing slash from directory path
        repo_dir="${repo_dir%/}"
        repo_name=$(basename "$repo_dir")

        echo "Processing $repo_name..."
        if [ -d "$repo_dir" ]; then
            cd "$repo_dir" || { echo "Failed to change to $repo_dir"; errors+="\nFailed to change to $repo_dir"; continue; }
            git pull || { echo "Failed to pull updates for $repo_name"; errors+="\nFailed to pull updates for $repo_name"; continue; }

            # Check if there are any changes
            if [ -n "$(git status --porcelain)" ]; then
                echo "Changes detected in $repo_name. Building and installing..."
                # Build and install if there are changes
                makepkg -si --noconfirm || { echo "Failed to build and install $repo_name"; errors+="\nFailed to build and install $repo_name"; continue; }
            else
                echo "No changes in $repo_name."
            fi
        else
            echo "Directory $repo_dir does not exist."
            errors+="\nDirectory $repo_dir does not exist."
        fi
    done
}

# Main script
echo "Checking and updating AUR repositories..."
update_aur_repos

# Final message
if [ -n "$errors" ]; then
    echo -e "Some tasks encountered errors and were not completed successfully: $errors"
    echo "Please review the errors and address them manually if necessary."
else
    echo "Script completed successfully."
fi