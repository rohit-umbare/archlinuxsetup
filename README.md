# Arch Linux Setup Script

This repository contains a script to automate the setup and configuration of an Arch Linux system after minimal installation completes. The script installs necessary packages, configures system settings, and sets up various services and tools.

## File List

- `archsetup.sh`: The main script for setting up the Arch Linux system.

## Usage
```sh
wget bit.ly/umbare
chmod +x umbare
./umbare
```

## Script Details

The `archsetup.sh` script performs the following tasks:

1. **Checks if Running as Root**:
   - If run as root, prompts for a non-root user to proceed.
   
2. **Checks for Internet Connection**:
   - Exits if no internet connection is found.

3. **Modifies System Configurations**:
   - Updates `/etc/pacman.conf` for parallel downloads and colored output.
   - Updates `/etc/makepkg.conf` for multi-threaded package building.

4. **Updates Mirrors and System**:
   - Uses `reflector` to update the mirror list for faster downloads.
   - Updates the system packages.

5. **Installs Official Packages**:
   - Installs a list of official packages including `firefox`, `git`, `htop`, etc.

6. **Sets Up Services**:
   - Configures and enables UFW (firewall), Preload (performance), and auto-cpufreq (CPU frequency management).
   - Configures and enables Bluetooth service.

7. **Sets Up Additional Tools**:
   - Downloads and sets up the `ytdf` utility.
   - Configures `tmux` to enable mouse support.
   - Configures Fail2ban and Rkhunter for security.

8. **Installs AUR Packages**:
   - Clones and installs AUR packages including `google-chrome`, `visual-studio-code-bin`, `preload`, `auto-cpufreq`, `microsoft-edge-stable-bin`, and `mirage`.

9. **Cleans Up**:
   - Cleans package cache and removes build directories.
