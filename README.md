# 🚀 Paymenter Management Script

<div align="center">

![Version](https://img.shields.io/badge/version-1.2.0-blue.svg?cacheSeconds=2592000)
![Tested on Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04-E95420?style=flat&logo=ubuntu&logoColor=white)
![Tested on Debian](https://img.shields.io/badge/Debian-10%20%7C%2011-A81D33?style=flat&logo=debian&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An advanced installation and management script for Paymenter, featuring automated installation, updates, backups, and removal capabilities.

[Features](#✨-features) •
[Prerequisites](#📋-prerequisites) •
[Installation](#💾-installation) •
[Usage](#🔧-usage) •
[Documentation](#📖-documentation) •
[Support](#💬-support)

</div>

## ✨ Features

- 🔄 **One-Click Installation**: Automated installation process with all dependencies
- 🛡️ **Secure Configuration**: Proper security settings and permissions out of the box
- 🔒 **SSL/TLS Ready**: Built-in support for domain configuration and SSL
- 📦 **Service Management**: Integrated service configuration and management
- 🔄 **Easy Updates**: Both automatic and manual update options
- 💾 **Backup System**: Integrated backup functionality for files and database
- 🧹 **Clean Removal**: Complete system cleanup option
- 📝 **Detailed Logging**: Comprehensive logging of all operations

## 📋 Prerequisites

- **Supported Operating Systems**:
  - Ubuntu 20.04 LTS
  - Ubuntu 22.04 LTS
  - Debian 10
  - Debian 11
- **Root Access**: Root privileges are required
- **Minimum Requirements**:
  - 1 CPU Core
  - 2GB RAM
  - 10GB Storage

## 💾 Installation

1. **Download the script**:
```bash
curl -o paymenter-manager.sh https://raw.githubusercontent.com/yourusername/paymenter-manager/main/paymenter-manager.sh
```

2. **Make it executable**:
```bash
chmod +x paymenter-manager.sh
```

3. **Run the script**:
```bash
sudo ./paymenter-manager.sh
```

## 🔧 Usage

The script provides an interactive menu with the following options:

```
╔══════════════════════════════════════════════════════════════════╗
║                Paymenter Management Script v1.2.0                 ║
╚══════════════════════════════════════════════════════════════════╝

Please select an option:
1) New Installation
2) Automatic Update
3) Manual Update
4) Create Backup
5) Remove Paymenter
6) Exit
```

### New Installation

- Supports both domain-based and IP-based installations
- Automatically installs and configures all required dependencies
- Sets up database, web server, and services
- Creates admin user automatically

### Automatic Update

- Quick update using Paymenter's built-in updater
- Creates backup before updating
- Handles all necessary cache clearing and permission updates

### Manual Update

- Detailed step-by-step update process
- Creates backup before updating
- Maintenance mode during update
- Complete dependency update

### Backup System

- Comprehensive backup of all files and database
- Timestamped backup files
- Stored in `/var/www/paymenter_backups`

### Removal

- Complete system cleanup
- Optional backup before removal
- Removes all related services and configurations

## 📖 Documentation

### Directory Structure

```
/var/www/paymenter          # Main application directory
/var/www/paymenter_backups  # Backup storage
/var/log/paymenter-install.log  # Installation logs
```

### Log Files

- Installation logs: `/var/log/paymenter-install.log`
- Nginx logs: `/var/log/nginx/`
- PHP-FPM logs: `/var/log/php8.2-fpm.log`

### Service Management

```bash
# Restart Paymenter services
systemctl restart paymenter.service

# Check service status
systemctl status paymenter.service

# View logs
journalctl -u paymenter.service
```

## 🛠️ Troubleshooting

### Common Issues

1. **Installation Fails**
   - Check system requirements
   - Verify internet connectivity
   - Review logs at `/var/log/paymenter-install.log`

2. **Database Connection Issues**
   - Verify MySQL service is running
   - Check database credentials in `.env`
   - Ensure proper permissions

3. **Web Server Issues**
   - Check Nginx configuration
   - Verify PHP-FPM is running
   - Review Nginx error logs

## 💬 Support

- 📫 **Issues**: Create an issue in this repository
- 📝 **Feature Requests**: Open a discussion
- 🤝 **Contributing**: Pull requests are welcome

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
Made with ❤️ for the Paymenter community
</div>
