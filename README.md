# AP Config Manager

A simple bash script for managing configurations across multiple OpenWrt/LEDE access points with an interactive dialog-based menu.

## Features

- **Download Configs** - Backup configurations from selected APs to `./data/` subdirectories
- **Upload Configs** - Deploy configurations from `./data/` subdirectories to selected APs
- **Reload Configs** - Remotely reload configurations on APs after upload
- **SSH Key Setup** - Automated passwordless SSH authentication setup for new APs
- **Interactive Selection** - Choose which APs to operate on with a dialog checkbox menu
- **Configuration File** - Keep your network configuration separate from the code

## Prerequisites

- `dialog` - For interactive terminal UI
- `ssh` / `scp` - For remote access to APs
- `ssh-keygen` / `ssh-copy-id` - For SSH key management
- Root access to your access points

## Installation

1. Clone or download this repository
2. Copy the sample configuration file:
   ```bash
   cp ap-config.conf.sample ap-config.conf
   ```
3. Edit `ap-config.conf` with your AP names and IP addresses:
   ```bash
   AP_KITCHEN=10.0.1.10
   AP_BEDROOM=10.0.1.11
   AP_OFFICE=10.0.1.12
   AP_LIVING=10.0.1.13
   ```
4. Make the script executable:
   ```bash
   chmod +x manage.sh
   ```

## Usage

Run the script:
```bash
./manage.sh
```

### Main Menu Options

1. **Download configs** - Backs up `/etc/config/*` from selected APs to `./data/<AP_NAME>/` folders
2. **Upload configs** - Uploads configs from `./data/<AP_NAME>/` to selected APs and optionally reloads them
3. **Setup SSH keys** - Sets up passwordless authentication for selected APs

### Directory Structure

After downloading, configs are stored in the `data/` directory (git-ignored):
```
ap-config/
├── manage.sh
├── ap-config.conf
├── ap-config.conf.sample
└── data/
    ├── KITCHEN/
    │   └── config files...
    ├── BEDROOM/
    │   └── config files...
    ├── OFFICE/
    │   └── config files...
    └── LIVING/
        └── config files...
```

## First Time Setup

1. Run the script and select option **3 - Setup SSH keys**
2. Select the APs you want to configure
3. Enter the root password when prompted for each AP
4. SSH keys will be automatically generated and deployed

After this, all operations will be passwordless.

## Workflow Example

### Backup All APs
1. Run `./manage.sh`
2. Select **1 - Download configs**
3. Select all APs (or use "ALL" option)
4. Configs are downloaded to `./data/<AP_NAME>/` directories

### Deploy Config to Single AP
1. Run `./manage.sh`
2. Select **2 - Upload configs**
3. Select specific AP
4. Choose "Yes" to reload config after upload

### Setup Fresh AP
1. Flash new AP with OpenWrt
2. Set IP address matching your configuration
3. Run `./manage.sh`
4. Select **3 - Setup SSH keys**
5. Select the new AP
6. Enter password once to setup passwordless auth

## Configuration

The script uses `ap-config.conf` for AP definitions. Add or remove APs as needed:

```bash
# Format: AP_NAME=IP_ADDRESS
AP_KITCHEN=10.0.1.10
AP_BEDROOM=10.0.1.11
AP_OFFICE=192.168.1.50
# Add more APs as needed
```

The `ap-config.conf` file is git-ignored to keep your personal network configuration private. Similarly, the `data/` directory containing your downloaded configurations is also git-ignored.

## Requirements

The script uses POSIX shell (`/bin/sh`) and should work on most Linux distributions.

## License

Free to use and modify.
