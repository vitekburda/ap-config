# AP Config Manager

A simple bash script for managing configurations across multiple OpenWrt/LEDE access points with an interactive dialog-based menu.

## Features

- **Download Configs** - Backup configurations from selected APs to `./data/` subdirectories
- **Upload Configs** - Deploy configurations from `./data/` subdirectories to selected APs
- **Reload Configs** - Remotely reload configurations on APs after upload
- **SSH Key Setup** - Automated passwordless SSH authentication setup for new APs
- **Startup Script Management** - Download, upload, and execute startup scripts (rc.local and custom init scripts)
- **Reboot Control** - Remotely reboot selected APs with confirmation
- **Interactive Selection** - Choose which APs to operate on with a dialog checkbox menu
- **Git Version Control** - Automatic git commits for tracking configuration changes
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
4. **Download startup scripts** - Backs up `/etc/rc.local` and `/etc/init.d/custom_*` scripts to `./data/<AP_NAME>/etc/`
5. **Upload startup scripts** - Uploads startup scripts from `./data/<AP_NAME>/etc/` and optionally executes them
6. **Execute startup scripts** - Manually execute startup scripts on selected APs without uploading
7. **Reboot selected APs** - Remotely reboot selected APs with confirmation dialog

### Directory Structure

After downloading, configs and startup scripts are stored in the `data/` directory with automatic git versioning:
```
ap-config/
├── manage.sh
├── ap-config.conf
├── ap-config.conf.sample
└── data/
    ├── .git/                    # Automatic version control
    ├── KITCHEN/
    │   └── etc/
    │       ├── config/          # OpenWrt config files
    │       ├── rc.local         # Startup script
    │       └── init.d/
    │           └── custom_*     # Custom init scripts
    ├── BEDROOM/
    │   └── etc/
    ├── OFFICE/
    │   └── etc/
    └── LIVING/
        └── etc/
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

## Startup Script Management

The script supports managing custom startup scripts on your APs:

### Supported Script Types
- **rc.local** - Traditional init script at `/etc/rc.local`
- **Custom init scripts** - Scripts matching `/etc/init.d/custom_*` pattern

### Managing Startup Scripts

**Download existing scripts:**
```bash
./manage.sh → 4 - Download startup scripts
```

**Create/edit scripts locally:**
```bash
# Edit or create scripts in ./data/<AP_NAME>/etc/
nano ./data/KITCHEN/etc/rc.local
nano ./data/KITCHEN/etc/init.d/custom_firewall
```

**Upload to APs:**
```bash
./manage.sh → 5 - Upload startup scripts
```

Scripts are automatically:
- Made executable (`chmod +x`)
- Enabled as init services (for `/etc/init.d/custom_*`)
- Optionally executed immediately after upload

**Test execution:**
```bash
./manage.sh → 6 - Execute startup scripts
```

## Git Version Control

All configuration and startup script changes are automatically tracked:
- Downloads create commits like "Downloaded configs from: AP1,AP2"
- Uploads create commits like "Uploaded startup scripts to: AP1"
- Local git repository in `./data/.git/` for version history

## Configuration

The script uses `ap-config.conf` for AP definitions. Add or remove APs as needed:

```bash
# Format: AP_NAME=IP_ADDRESS
AP_KITCHEN=10.0.1.10
AP_BEDROOM=10.0.1.11
AP_OFFICE=192.168.1.50
# Add more APs as needed
```

The `ap-config.conf` file is git-ignored to keep your personal network configuration private.

## Safety Features

- **Confirmation dialogs** for destructive operations (upload, reboot)
- **Git versioning** tracks all changes with automatic commits
- **AP selection** prevents accidental operations on wrong devices
- **Background reboot** prevents SSH session hangs during reboot

## Requirements

The script uses POSIX shell (`/bin/sh`) and should work on most Linux distributions.

## License

Free to use and modify.
