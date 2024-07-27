#!/bin/bash

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
    "chromium"
    "git"
    "base-devel"
    "htop"
    "neofetch"
    "tmux"
    "ripgrep"
    "fd"
    "exa"
    "bat"
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
    "fail2ban"
    "rkhunter"
)

# Functions
modify_pacman_conf() {
    echo "Modifying /etc/pacman.conf..."
    sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; exit 1; }
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; exit 1; }
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf || { echo "Failed to modify /etc/pacman.conf"; exit 1; }
}

modify_makepkg_conf() {
    echo "Modifying /etc/makepkg.conf..."
    sudo sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; exit 1; }
    sudo sed -i 's/^#CCACHE_SIZE="2G"/CCACHE_SIZE="10G"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; exit 1; }
    sudo sed -i 's/^#USECCACHE="yes"/USECCACHE="yes"/' /etc/makepkg.conf || { echo "Failed to modify /etc/makepkg.conf"; exit 1; }
}

update_mirrors() {
    echo "Generating a new mirror list..."
    sudo pacman -S --noconfirm reflector || { echo "Failed to install reflector"; exit 1; }
    sudo reflector --country 'India' --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || { echo "Failed to generate mirror list"; exit 1; }
    echo "Updating system with new mirrors..."
    sudo pacman -Syu --noconfirm || { echo "Failed to update system"; exit 1; }
}

install_official_packages() {
    echo "Installing official packages..."
    sudo pacman -S --noconfirm "${official_packages[@]}" || { echo "Failed to install some official packages"; exit 1; }
}

setup_services() {
    echo "Configuring UFW..."
    sudo ufw default deny incoming || { echo "Failed to set UFW default deny"; exit 1; }
    sudo ufw default allow outgoing || { echo "Failed to set UFW default allow"; exit 1; }
    sudo ufw allow ssh || { echo "Failed to allow SSH in UFW"; exit 1; }
    sudo ufw allow 1714:1764/udp || { echo "Failed to allow UDP range in UFW"; exit 1; }
    sudo ufw allow 1714:1764/tcp || { echo "Failed to allow TCP range in UFW"; exit 1; }
    sudo ufw enable || { echo "Failed to enable UFW"; exit 1; }
    sudo systemctl enable ufw || { echo "Failed to enable UFW service"; exit 1; }
    sudo systemctl start ufw || { echo "Failed to start UFW service"; exit 1; }

    echo "Configuring Preload..."
    sudo systemctl enable preload || { echo "Failed to enable Preload"; exit 1; }
    sudo systemctl start preload || { echo "Failed to start Preload"; exit 1; }

    echo "Configuring auto-cpufreq..."
    sudo systemctl enable auto-cpufreq || { echo "Failed to enable auto-cpufreq"; exit 1; }
    sudo systemctl start auto-cpufreq || { echo "Failed to start auto-cpufreq"; exit 1; }

    echo "Setting up Bluetooth..."
    sudo systemctl enable bluetooth || { echo "Failed to enable Bluetooth"; exit 1; }
    sudo systemctl start bluetooth || { echo "Failed to start Bluetooth"; exit 1; }
}

setup_ytdf() {
    echo "Setting up ytdf utility..."
    mkdir -p "$automation_dir"
    wget https://raw.githubusercontent.com/rohit-umbare/ytdf/main/ytdf.py -O "$automation_dir/ytdf.py" || { echo "Failed to download ytdf.py"; exit 1; }
    chmod +x "$automation_dir/ytdf.py" || { echo "Failed to set executable permissions on ytdf.py"; exit 1; }
    echo "alias ytdf='python3 $automation_dir/ytdf.py'" >> ~/.bashrc || { echo "Failed to set up ytdf alias"; exit 1; }
    source ~/.bashrc || { echo "Failed to reload .bashrc"; exit 1; }
}

setup_fail2ban() {
    echo "Configuring Fail2ban..."
    sudo systemctl enable fail2ban || { echo "Failed to enable Fail2ban"; exit 1; }
    sudo systemctl start fail2ban || { echo "Failed to start Fail2ban"; exit 1; }
    # Example configuration, customize as needed
    sudo tee /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
bantime = 10m
EOF
    sudo systemctl restart fail2ban || { echo "Failed to restart Fail2ban"; exit 1; }
}

setup_rkhunter() {
    echo "Configuring Rkhunter..."
    sudo systemctl enable rkhunter || { echo "Failed to enable Rkhunter"; exit 1; }
    sudo systemctl start rkhunter || { echo "Failed to start Rkhunter"; exit 1; }
    # Example configuration, customize as needed
    sudo rkhunter --update || { echo "Failed to update Rkhunter"; exit 1; }
    sudo rkhunter --check || { echo "Failed to run Rkhunter check"; exit 1; }
}

cleanup() {
    echo "Cleaning package cache..."
    sudo pacman -Scc --noconfirm || { echo "Failed to clean package cache"; exit 1; }

    echo "Removing AUR build directories..."
    for repo in "${aur_repos[@]}"; do
        repo_name=$(basename "$repo" .git)
        if [ -d "$repo_name" ]; then
            (
                cd "$repo_name" || exit
                rm -rf src pkg || { echo "Failed to remove build directories in $repo_name"; exit 1; }
            )
        fi
    done
}

# Main script
check_chroot_user
check_internet

echo "Creating necessary directories..."
mkdir -p "$aur_dir" "$automation_dir" || { echo "Failed to create directories"; exit 1; }
cd "$aur_dir" || { echo "Failed to change to AUR directory"; exit 1; }

modify_pacman_conf
modify_makepkg_conf

update_mirrors
install_official_packages

echo "Setting Chromium as the default browser..."
xdg-settings set default-web-browser chromium.desktop || { echo "Failed to set Chromium as default browser"; exit 1; }

echo "Cloning and installing AUR packages..."
for repo in "${aur_repos[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$repo_name" ]; then
        echo "Cloning $repo..."
        git clone "$repo" || { echo "Failed to clone $repo"; exit 1; }
    fi
    (
        cd "$repo_name" || exit
        echo "Building and installing $repo_name..."
        makepkg -si --noconfirm || { echo "Failed to build and install $repo_name"; exit 1; }
    )
done

setup_ytdf

echo "Configuring Tmux..."
echo "set -g mouse on" >> ~/.tmux.conf || { echo "Failed to configure Tmux"; exit 1; }

setup_services
setup_fail2ban
setup_rkhunter

cleanup

echo "Script completed. Welcome to your customized Arch Linux setup!"
neofetch
