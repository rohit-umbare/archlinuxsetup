#!/bin/bash

# Directory where AUR packages will be cloned
aur_dir="$HOME/aur"

# List of AUR package repositories to clone
repos=(
    "https://aur.archlinux.org/google-chrome.git"
    "https://aur.archlinux.org/visual-studio-code-bin.git"
    "https://aur.archlinux.org/preload.git"
    "https://aur.archlinux.org/auto-cpufreq.git"
    "https://aur.archlinux.org/microsoft-edge-stable-bin.git"
)

# Function to modify makepkg.conf
modify_makepkg_conf() {
    sudo sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
    sudo sed -i 's/^#CFLAGS.*/CFLAGS="-march=native -O2 -pipe"/' /etc/makepkg.conf
    sudo sed -i 's/^#CXXFLAGS.*/CXXFLAGS="-march=native -O2 -pipe"/' /etc/makepkg.conf
    sudo sed -i 's/^#PKGEXT="\.pkg\.tar\.zst"/PKGEXT=".pkg.tar"/' /etc/makepkg.conf
}

# Function to modify pacman.conf
modify_pacman_conf() {
    sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
}

# Create AUR directory if it doesn't exist
mkdir -p "$aur_dir"

# Change to the AUR directory
cd "$aur_dir" || exit

# Update system and install essential packages
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm firefox chromium git base-devel htop neofetch vim tmux ripgrep fd exa bat flameshot gnome-tweaks nodejs npm ufw

# Modify makepkg.conf and pacman.conf
modify_makepkg_conf
modify_pacman_conf

# Configure UFW
echo "Configuring UFW..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable

# Clone and install AUR packages
for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$repo_name" ]; then
        echo "Cloning $repo..."
        git clone "$repo"
    fi
    (
        cd "$repo_name" || exit
        echo "Building and installing $repo_name..."
        makepkg -si --noconfirm
    )
done

# Configure Preload
echo "Configuring Preload..."
sudo systemctl enable preload
sudo systemctl start preload

# Configure auto-cpufreq
echo "Configuring auto-cpufreq..."
sudo systemctl enable auto-cpufreq
sudo systemctl start auto-cpufreq

# Configure Bluetooth
echo "Setting up Bluetooth..."
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# Install Miniconda
echo "Installing Miniconda..."
conda_dir="$HOME/miniconda3"
if [ ! -d "$conda_dir" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p "$conda_dir"
    rm ~/miniconda.sh
    eval "$($conda_dir/bin/conda shell.bash hook)"
else
    echo "Miniconda is already installed."
    eval "$($conda_dir/bin/conda shell.bash hook)"
fi

# Create Conda environment and install fastai and pytorch
echo "Creating Conda environment 'myenv' and installing fastai and pytorch..."
conda create -y -n myenv 
conda install pytorch torchvision torchaudio cpuonly -c pytorch
conda activate myenv
conda install -y -c fastai fastai
conda install -y -c fastai fastbook
conda install pandas csv matplotlib 
conda deactivate


# Configure Tmux
echo "Configuring Tmux..."
echo "set -g mouse on" >> ~/.tmux.conf

# Clean package cache
echo "Cleaning package cache..."
sudo pacman -Scc --noconfirm

# Clean build directories in AUR
echo "Cleaning build directories in AUR..."
for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo" .git)
    (
        cd "$repo_name" || exit
        echo "Removing leftover build files..."
        rm -rf src pkg
    )
done

# Clear Miniconda package cache
echo "Clearing Miniconda package cache..."
conda clean -a -y

echo "All packages installed, configured, and system cleaned."
