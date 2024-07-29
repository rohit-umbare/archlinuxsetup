#!/bin/bash
#contact umbarers52@gmail.com
set -e  # Exit on any error

# Function to check if running as root in a chroot environment
check_chroot_user() {
    if [ "$(id -u)" -eq 0 ]; then
        read -p "Running as root. Please provide a non-root user to proceed: " user
        if id "$user" &>/dev/null; then
            echo "Proceeding with user $user."
            export USER="$user"
        else
            echo "User $user does not exist. Exiting."
            exit 1
        fi
    else
        echo "Running as non-root user. Proceeding."
    fi
}

# Function to check for internet connection
check_internet() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        echo "No internet connection. Exiting."
        exit 1
    fi
}

# Directories
aur_dir="$HOME/aur_packages"
automation_dir="$HOME/automation"

# AUR repositories
aur_repos=(
    "https://aur.archlinux.org/google-chrome.git"
    "https://aur.archlinux.org/visual-studio-code-bin.git"
    "https://aur.archlinux.org/preload.git"
    "https://aur.archlinux.org/auto-cpufreq.git"
    "https://aur.archlinux.org/microsoft-edge-stable-bin.git"
    "https://aur.archlinux.org/mirage.git"
)

# Official packages
official_packages=(
    "firefox"
    "telegram-desktop"
    "chromium"
    "git"
    "base-devel"
    "htop"
    "neofetch"
    "tmux"
    "ripgrep"
    "fd"
    "flameshot"
    "nodejs"
    "npm"
    "ufw"
    "libreoffice-fresh"
    "yt-dlp"
    "git-lfs"
    "python"
    "glances"
    "ncdu"
    "zip"
    "unzip"
)

# Variables to track errors
errors=""

# Functions
modify_pacman_conf() {
    echo "Modifying /etc/pacman.conf..."
    sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; errors+="\nFailed to modify /etc/pacman.conf"; }
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; errors+="\nFailed to modify /etc/pacman.conf"; }
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; errors+="\nFailed to modify /etc/pacman.conf"; }
}

modify_makepkg_conf() {
    echo "Modifying /etc/makepkg.conf..."
    sudo sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; errors+="\nFailed to modify /etc/makepkg.conf"; }
    sudo sed -i 's/^#CCACHE_SIZE="2G"/CCACHE_SIZE="10G"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; errors+="\nFailed to modify /etc/makepkg.conf"; }
    sudo sed -i 's/^#USECCACHE="yes"/USECCACHE="yes"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; errors+="\nFailed to modify /etc/makepkg.conf"; }
}

update_mirrors() {
    echo "Generating a new mirror list..."
    sudo pacman -S --noconfirm reflector || { echo "Failed to install reflector"; errors+="\nFailed to install reflector"; }
    sudo reflector --country 'India' --sort rate --save /etc/pacman.d/mirrorlist || { echo "Failed to generate mirror list"; errors+="\nFailed to generate mirror list"; }
    echo "Updating system with new mirrors..."
    sudo pacman -Syu --noconfirm || { echo "Failed to update system"; errors+="\nFailed to update system"; }
}

install_official_packages() {
    echo "Installing official packages..."
    sudo pacman -S --noconfirm "${official_packages[@]}" || { echo "Failed to install some official packages"; errors+="\nFailed to install some official packages"; }
}

setup_services() {
    echo "Configuring UFW..."
    sudo ufw default deny incoming || { echo "Failed to set UFW default deny"; errors+="\nFailed to set UFW default deny"; }
    sudo ufw default allow outgoing || { echo "Failed to set UFW default allow"; errors+="\nFailed to set UFW default allow"; }
    sudo ufw allow ssh || { echo "Failed to allow SSH in UFW"; errors+="\nFailed to allow SSH in UFW"; }
    sudo ufw allow 1714:1764/udp || { echo "Failed to allow UDP range in UFW"; errors+="\nFailed to allow UDP range in UFW"; }
    sudo ufw allow 1714:1764/tcp || { echo "Failed to allow TCP range in UFW"; errors+="\nFailed to allow TCP range in UFW"; }
    sudo ufw enable || { echo "Failed to enable UFW"; errors+="\nFailed to enable UFW"; }
    sudo systemctl enable ufw || { echo "Failed to enable UFW service"; errors+="\nFailed to enable UFW service"; }
    sudo systemctl start ufw || { echo "Failed to start UFW service"; errors+="\nFailed to start UFW service"; }

    echo "Configuring Preload..."
    sudo systemctl enable preload || { echo "Failed to enable Preload"; errors+="\nFailed to enable Preload"; }
    sudo systemctl start preload || { echo "Failed to start Preload"; errors+="\nFailed to start Preload"; }

    echo "Configuring auto-cpufreq..."
    sudo systemctl enable auto-cpufreq || { echo "Failed to enable auto-cpufreq"; errors+="\nFailed to enable auto-cpufreq"; }
    sudo systemctl start auto-cpufreq || { echo "Failed to start auto-cpufreq"; errors+="\nFailed to start auto-cpufreq"; }

    echo "Setting up Bluetooth..."
    sudo systemctl enable bluetooth || { echo "Failed to enable Bluetooth"; errors+="\nFailed to enable Bluetooth"; }
    sudo systemctl start bluetooth || { echo "Failed to start Bluetooth"; errors+="\nFailed to start Bluetooth"; }
}

setup_ytdf() {
    echo "Setting up ytdf utility..."
    mkdir -p "$automation_dir"
    wget https://raw.githubusercontent.com/rohit-umbare/ytdf/main/ytdf.py -O "$automation_dir/ytdf.py" || { echo "Failed to download ytdf.py"; errors+="\nFailed to download ytdf.py"; }
    chmod +x "$automation_dir/ytdf.py" || { echo "Failed to set executable permissions on ytdf.py"; errors+="\nFailed to set executable permissions on ytdf.py"; }
    echo "alias ytdf='python3 $automation_dir/ytdf.py'" >> ~/.bashrc || { echo "Failed to set up ytdf alias"; errors+="\nFailed to set up ytdf alias"; }
    source ~/.bashrc || { echo "Failed to reload .bashrc"; errors+="\nFailed to reload .bashrc"; }
}

cleanup() {
    echo "Cleaning package cache..."
    sudo pacman -Scc --noconfirm || { echo "Failed to clean package cache"; errors+="\nFailed to clean package cache"; }

    echo "Removing AUR build directories..."
    for repo in "${aur_repos[@]}"; do
        repo_name=$(basename "$repo" .git)
        if [ -d "$repo_name" ]; then
            (
                cd "$repo_name" || exit
                rm -rf src pkg || { echo "Failed to remove build directories in $repo_name"; errors+="\nFailed to remove build directories in $repo_name"; }
            )
        fi
    done
}

# Main script
check_chroot_user
check_internet

echo "Creating necessary directories..."
mkdir -p "$aur_dir" "$automation_dir" || { echo "Failed to create directories"; errors+="\nFailed to create directories"; }
cd "$aur_dir" || { echo "Failed to change to AUR directory"; errors+="\nFailed to change to AUR directory"; }

modify_pacman_conf
modify_makepkg_conf

update_mirrors
install_official_packages

echo "Setting Chromium as the default browser..."
xdg-settings set default-web-browser chromium.desktop || { echo "Failed to set Chromium as default browser"; errors+="\nFailed to set Chromium as default browser"; }

echo "Cloning and installing AUR packages..."
for repo in "${aur_repos[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$repo_name" ]; then
        echo "Cloning $repo..."
        git clone "$repo" || { echo "Failed to clone $repo"; errors+="\nFailed to clone $repo"; }
    fi
    (
        cd "$repo_name" || exit
        echo "Building and installing $repo_name..."
        makepkg -si --noconfirm || { echo "Failed to build and install $repo_name"; errors+="\nFailed to build and install $repo_name"; }
    )
done

setup_services
setup_ytdf
cleanup

# Final message
if [ -n "$errors" ]; then
    echo -e "Some tasks encountered errors and were not completed successfully: $errors"
    echo "Please review the errors and address them manually if necessary."
else
    echo "Script completed successfully."
fi
