#!/bin/bash

set -e  # Exit on any error

# Directories
aur_dir="$HOME/aur_packages"
automation_dir="$HOME/automation"
conda_dir="$HOME/miniconda3"

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
    "vim"
    "tmux"
    "ripgrep"
    "fd"
    "exa"
    "bat"
    "flameshot"
    "gnome-tweaks"
    "nodejs"
    "npm"
    "ufw"
    "libreoffice-fresh"
    "yt-dlp"
    "git-lfs"
    "python-poetry"
    "glances"
    "ncdu"
    "fail2ban"
    "rkhunter"
)

# Conda packages
conda_packages=(
    "pytorch torchvision torchaudio cpuonly"
    "fastai fastbook"
    "pandas csv matplotlib"
)

# Functions
modify_makepkg_conf() {
    echo "Modifying /etc/makepkg.conf..."
    sudo sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf || echo "Failed to modify /etc/makepkg.conf"
    sudo sed -i 's/^#CFLAGS.*/CFLAGS="-march=native -O2 -pipe"/' /etc/makepkg.conf || echo "Failed to modify /etc/makepkg.conf"
    sudo sed -i 's/^#CXXFLAGS.*/CXXFLAGS="-march=native -O2 -pipe"/' /etc/makepkg.conf || echo "Failed to modify /etc/makepkg.conf"
    sudo sed -i 's/^#PKGEXT="\.pkg\.tar\.zst"/PKGEXT=".pkg.tar"/' /etc/makepkg.conf || echo "Failed to modify /etc/makepkg.conf"
}

modify_pacman_conf() {
    echo "Modifying /etc/pacman.conf..."
    sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf || echo "Failed to modify /etc/pacman.conf"
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf || echo "Failed to modify /etc/pacman.conf"
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf || echo "Failed to modify /etc/pacman.conf"
}

update_mirrors() {
    echo "Generating a new mirror list..."
    sudo pacman -S --noconfirm reflector || echo "Failed to install reflector"
    sudo reflector --country 'India' --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || echo "Failed to generate mirror list"
    echo "Updating system with new mirrors..."
    sudo pacman -Syu --noconfirm || echo "Failed to update system"
}

install_official_packages() {
    echo "Installing official packages..."
    sudo pacman -S --noconfirm "${official_packages[@]}" || echo "Failed to install some official packages"
}

setup_services() {
    echo "Configuring UFW..."
    sudo ufw default deny incoming || echo "Failed to set UFW default deny"
    sudo ufw default allow outgoing || echo "Failed to set UFW default allow"
    sudo ufw allow ssh || echo "Failed to allow SSH in UFW"
    sudo ufw allow 1714:1764/udp || echo "Failed to allow UDP range in UFW"
    sudo ufw allow 1714:1764/tcp || echo "Failed to allow TCP range in UFW"
    sudo ufw enable || echo "Failed to enable UFW"
    sudo systemctl enable ufw || echo "Failed to enable UFW service"
    sudo systemctl start ufw || echo "Failed to start UFW service"

    echo "Configuring Preload..."
    sudo systemctl enable preload || echo "Failed to enable Preload"
    sudo systemctl start preload || echo "Failed to start Preload"

    echo "Configuring auto-cpufreq..."
    sudo systemctl enable auto-cpufreq || echo "Failed to enable auto-cpufreq"
    sudo systemctl start auto-cpufreq || echo "Failed to start auto-cpufreq"

    echo "Setting up Bluetooth..."
    sudo systemctl enable bluetooth || echo "Failed to enable Bluetooth"
    sudo systemctl start bluetooth || echo "Failed to start Bluetooth"
}

install_conda() {
    echo "Installing Miniconda..."
    if [ ! -d "$conda_dir" ]; then
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh || echo "Failed to download Miniconda"
        bash ~/miniconda.sh -b -p "$conda_dir" || echo "Failed to install Miniconda"
        rm ~/miniconda.sh || echo "Failed to remove Miniconda installer"
        eval "$($conda_dir/bin/conda shell.bash hook)" || echo "Failed to initialize Conda"
    else
        echo "Miniconda is already installed."
        eval "$($conda_dir/bin/conda shell.bash hook)" || echo "Failed to initialize Conda"
    fi
}

install_conda_packages() {
    echo "Creating Conda environment 'myenv' and installing packages..."
    conda create -y -n myenv python || echo "Failed to create Conda environment"
    conda activate myenv || echo "Failed to activate Conda environment"
    conda install -y -c pytorch "${conda_packages[0]}" || echo "Failed to install PyTorch packages"
    conda install -y -c fastai "${conda_packages[1]}" || echo "Failed to install Fastai packages"
    conda install -y "${conda_packages[2]}" || echo "Failed to install additional Conda packages"
    conda deactivate || echo "Failed to deactivate Conda environment"
}

cleanup() {
    echo "Cleaning package cache..."
    sudo pacman -Scc --noconfirm || echo "Failed to clean package cache"

    echo "Removing AUR build directories..."
    for repo in "${aur_repos[@]}"; do
        repo_name=$(basename "$repo" .git)
        if [ -d "$repo_name" ]; then
            (
                cd "$repo_name" || exit
                rm -rf src pkg || echo "Failed to remove build directories in $repo_name"
            )
        fi
    done

    echo "Clearing Miniconda package cache..."
    conda clean -a -y || echo "Failed to clear Miniconda package cache"
}

# Main script
echo "Creating necessary directories..."
mkdir -p "$aur_dir" "$automation_dir" || echo "Failed to create directories"
cd "$aur_dir" || echo "Failed to change to AUR directory"

update_mirrors
install_official_packages

echo "Setting Chromium as the default browser..."
xdg-settings set default-web-browser chromium.desktop || echo "Failed to set Chromium as default browser"

modify_makepkg_conf
modify_pacman_conf

setup_services

echo "Cloning and installing AUR packages..."
for repo in "${aur_repos[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$repo_name" ]; then
        echo "Cloning $repo..."
        git clone "$repo" || echo "Failed to clone $repo"
    fi
    (
        cd "$repo_name" || exit
        echo "Building and installing $repo_name..."
        makepkg -si --noconfirm || echo "Failed to build and install $repo_name"
    )
done

echo "Setting up ytdf utility..."
wget https://raw.githubusercontent.com/rohit-umbare/ytdf/main/ytdf.py -O "$automation_dir/ytdf.py" || echo "Failed to download ytdf.py"
chmod +x "$automation_dir/ytdf.py" || echo "Failed to set executable permissions on ytdf.py"
echo "alias ytdf='python3 $automation_dir/ytdf.py'" >> ~/.bashrc || echo "Failed to set up ytdf alias"
source ~/.bashrc || echo "Failed to reload .bashrc"

install_conda
install_conda_packages

echo "Configuring Tmux..."
echo "set -g mouse on" >> ~/.tmux.conf || echo "Failed to configure Tmux"

cleanup

echo "Script completed. Welcome to your customized Arch Linux setup!"
neofetch
