#!/bin/bash

# Paymenter Management Script
# Version: 1.2.0
# Description: Installation and management script for Paymenter
# Supported: Ubuntu 22.04, Ubuntu 20.04, Debian 10, Debian 11
# License: MIT

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Unicode symbols
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x98"
ARROW="\xE2\x9E\xA4"
STAR="\xE2\x98\x85"
WARN="\xE2\x9A\xA0"

# Global variables
readonly SCRIPT_VERSION="1.2.0"
readonly PAYMENTER_DIR="/var/www/paymenter"
readonly NGINX_CONF="/etc/nginx/sites-available/paymenter.conf"
readonly LOG_FILE="/var/log/paymenter-install.log"
readonly BACKUP_DIR="/var/www/paymenter_backups"

# Required base packages
readonly BASE_PACKAGES=(
    "software-properties-common"
    "curl"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
)

# Required packages
readonly REQUIRED_PACKAGES=(
    "php8.2"
    "php8.2-common"
    "php8.2-cli"
    "php8.2-gd"
    "php8.2-mysql"
    "php8.2-mbstring"
    "php8.2-bcmath"
    "php8.2-xml"
    "php8.2-fpm"
    "php8.2-curl"
    "php8.2-zip"
    "mariadb-server"
    "nginx"
    "tar"
    "unzip"
    "git"
    "redis-server"
)

# Print functions
print_header() {
    local text="$1"
    local length=${#text}
    local padding=$((60 - length))
    local half_padding=$((padding / 2))
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    printf "${PURPLE}║${CYAN}%*s%s%*s${PURPLE}║${NC}\n" $half_padding "" "$text" $((padding - half_padding)) ""
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_status() { echo -e "${YELLOW}${ARROW} ${NC}$1" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}${CHECK_MARK} ${NC}$1" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}${CROSS_MARK} ${NC}$1" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}${WARN} ${NC}$1" | tee -a "$LOG_FILE"; }
print_section() { echo -e "\n${BLUE}${STAR} $1 ${STAR}${NC}\n" | tee -a "$LOG_FILE"; }

# Check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    print_section "Checking System Compatibility"
    
    # Check if system is supported
    if ! grep -E "Ubuntu|Debian" /etc/os-release &>/dev/null; then
        print_error "This script only supports Ubuntu and Debian"
        exit 1
    fi
    
    # Get OS details
    local os_name=$(grep -E '^NAME=' /etc/os-release | cut -d'"' -f2)
    local os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    
    print_success "Detected: $os_name $os_version"
    
    # Check version compatibility
    case "$os_name" in
        "Ubuntu")
            if [[ "$os_version" != "20.04" && "$os_version" != "22.04" ]]; then
                print_error "Unsupported Ubuntu version. Only 20.04 and 22.04 are supported"
                exit 1
            fi
            ;;
        "Debian")
            if [[ "$os_version" != "10" && "$os_version" != "11" ]]; then
                print_error "Unsupported Debian version. Only 10 and 11 are supported"
                exit 1
            fi
            ;;
    esac
    
    print_success "System is compatible"
}

# Install base dependencies
install_base_dependencies() {
    print_section "Installing Base Dependencies"
    
    # Update package list
    print_status "Updating package list..."
    apt update &>> "$LOG_FILE"
    
    # Install base packages
    for package in "${BASE_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            print_status "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt install -y "$package" &>> "$LOG_FILE" || {
                print_error "Failed to install $package"
                return 1
            }
        fi
    done
    
    print_success "Base dependencies installed"
}

# Add PHP repository
add_php_repository() {
    print_section "Adding PHP Repository"
    
    print_status "Adding PHP 8.2 repository..."
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php &>> "$LOG_FILE" || {
        print_error "Failed to add PHP repository"
        return 1
    }
    
    apt update &>> "$LOG_FILE"
    print_success "PHP repository added"
}

# Install required packages
install_required_packages() {
    print_section "Installing Required Packages"
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            print_status "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt install -y "$package" &>> "$LOG_FILE" || {
                print_error "Failed to install $package"
                return 1
            }
        fi
    done
    
    # Install Composer
    if ! command -v composer &>/dev/null; then
        print_status "Installing Composer..."
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer || {
            print_error "Failed to install Composer"
            return 1
        }
    fi
    
    print_success "All required packages installed"
}

# Configure MySQL
setup_mysql() {
    print_section "Configuring Database"
    
    local mysql_password=$1
    
    print_status "Creating database and user..."
    mysql -e "CREATE USER IF NOT EXISTS 'paymenter'@'127.0.0.1' IDENTIFIED BY '${mysql_password}';" || {
        print_error "Failed to create database user"
        return 1
    }
    
    mysql -e "CREATE DATABASE IF NOT EXISTS paymenter;" || {
        print_error "Failed to create database"
        return 1
    }
    
    mysql -e "GRANT ALL PRIVILEGES ON paymenter.* TO 'paymenter'@'127.0.0.1' WITH GRANT OPTION;" || {
        print_error "Failed to grant privileges"
        return 1
    }
    
    mysql -e "FLUSH PRIVILEGES;" || {
        print_error "Failed to flush privileges"
        return 1
    }
    
    print_success "Database configured successfully"
}

# Configure Nginx
setup_nginx() {
    print_section "Configuring Nginx"
    
    local server_name=$1
    
    print_status "Creating Nginx configuration..."
    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${server_name};
    root ${PAYMENTER_DIR}/public;

    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "no-referrer-when-downgrade";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # Enable site and remove default
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if ! nginx -t &>> "$LOG_FILE"; then
        print_error "Nginx configuration test failed"
        return 1
    fi
    
    print_success "Nginx configured successfully"
}

# Setup Queue Worker
setup_queue_worker() {
    print_section "Setting up Queue Worker"
    
    print_status "Creating service file..."
    cat > /etc/systemd/system/paymenter.service << EOF
[Unit]
Description=Paymenter Queue Worker
After=network.target mysql.service redis.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php ${PAYMENTER_DIR}/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Queue worker service created"
}

# Setup Crontab
setup_crontab() {
    print_section "Setting up Crontab"
    
    print_status "Adding cron job..."
    (crontab -l 2>/dev/null | grep -v "$PAYMENTER_DIR"; echo "* * * * * php ${PAYMENTER_DIR}/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    print_success "Cron job added"
}

# Set correct permissions
set_permissions() {
    print_section "Setting Permissions"
    
    print_status "Setting file permissions..."
    chown -R www-data:www-data "$PAYMENTER_DIR"
    find "$PAYMENTER_DIR" -type f -exec chmod 644 {} \;
    find "$PAYMENTER_DIR" -type d -exec chmod 755 {} \;
    chmod -R 775 "$PAYMENTER_DIR/storage" "$PAYMENTER_DIR/bootstrap/cache"
    
    print_success "Permissions set correctly"
}

# Create backup
create_backup() {
    print_section "Creating Backup"
    
    local backup_file="${BACKUP_DIR}/paymenter_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    # Backup files
    print_status "Backing up files..."
    tar -czf "$backup_file" -C "$(dirname $PAYMENTER_DIR)" "$(basename $PAYMENTER_DIR)" &>> "$LOG_FILE" || {
        print_error "Failed to backup files"
        return 1
    }
    
    # Backup database
    print_status "Backing up database..."
    mysqldump paymenter > "${backup_file%.tar.gz}.sql" 2>> "$LOG_FILE" || {
        print_error "Failed to backup database"
        return 1
    }
    
    print_success "Backup created at: $backup_file"
}

# Perform installation
perform_installation() {
    print_header "New Installation"
    
    # Get installation type
    echo -e "${CYAN}Please select installation type:${NC}"
    echo "1) Domain-based installation"
    echo "2) IP-based installation (default)"
    read -p "Enter choice [1-2]: " INSTALL_TYPE
    
    # Get server name
    if [[ "$INSTALL_TYPE" == "1" ]]; then
        read -p "Enter your domain name (e.g., paymenter.org): " SERVER_NAME
    else
        SERVER_NAME=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
        print_status "Using IP address: $SERVER_NAME"
    fi
    
    # Get MySQL password
    while true; do
        read -s -p "Enter MySQL password for Paymenter: " MYSQL_PASSWORD
        echo
        read -s -p "Confirm MySQL password: " MYSQL_PASSWORD_CONFIRM
        echo
        
        if [ "$MYSQL_PASSWORD" = "$MYSQL_PASSWORD_CONFIRM" ]; then
            if [[ "${#MYSQL_PASSWORD}" -ge 8 ]]; then
                break
            else
                print_error "Password must be at least 8 characters long"
            fi
        else
            print_error "Passwords do not match"
        fi
    done
    
    # Check system and install dependencies
    check_os || return 1
    install_base_dependencies || return 1
    add_php_repository || return 1
    install_required_packages || return 1
    
    # Download Paymenter
    print_section "Downloading Paymenter"
    
    mkdir -p "$PAYMENTER_DIR"
    cd "$PAYMENTER_DIR"
    
    print_status "Downloading latest version..."
    curl -Lo paymenter.tar.gz https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz || {
        print_error "Failed to download Paymenter"
        return 1
    }
    
    tar -xzf paymenter.tar.gz
    rm paymenter.tar.gz
    
    # Configure Paymenter
    print_status "Configuring Paymenter..."
    cp .env.example .env
    sed -i "s/DB_PASSWORD=/DB_PASSWORD=${MYSQL_PASSWORD}/" .env
    
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan storage:link
    
    # Setup components
    setup_mysql "$MYSQL_PASSWORD" || return 1
    setup_nginx "$SERVER_NAME" || return 1
    setup_queue_worker || return 1
    setup_crontab || return 1
    set_permissions || return 1
    
    # Run migrations
    print_status "Running database migrations..."
    php artisan migrate --force --seed || {
        print_error "Failed to run database migrations"
        return 1
    }
    
    # Start services
    print_status "Starting services..."
    systemctl restart nginx php8.2-fpm mysql redis-server
    systemctl enable --now paymenter.service
    
    # Create admin user
    print_section "Creating Admin User"
    php artisan p:user:create
    
    print_success "Installation completed successfully!"
    echo -e "\n${CYAN}Access your installation at:${NC} http://${SERVER_NAME}"
    echo -e "\n${YELLOW}Important Next Steps:${NC}"
    echo -e "1. ${WHITE}Back up your encryption key (APP_KEY in the .env file)${NC}"
    if [[ "$INSTALL_TYPE" == "1" ]]; then
        echo -e "2. ${WHITE}Set up SSL/TLS certificates for your domain${NC}"
    fi
    echo -e "3. ${WHITE}Configure your firewall${NC}"
    echo -e "4. ${WHITE}Set up regular backups${NC}"
    
    return 0
}

# Perform automatic update
perform_automatic_update() {
    print_header "Automatic Update"
    
    if [ ! -d "$PAYMENTER_DIR" ]; then
        print_error "Paymenter is not installed!"
        return 1
    fi
    
    # Create backup
    create_backup || return 1
    
    cd "$PAYMENTER_DIR"
    print_status "Running automatic update..."
    php artisan p:upgrade || {
        print_error "Automatic update failed"
        return 1
    }
    
    set_permissions
    systemctl restart paymenter.service nginx php8.2-fpm
    
    print_success "Update completed successfully!"
}

# Perform manual update
perform_manual_update() {
    print_header "Manual Update"
    
    if [ ! -d "$PAYMENTER_DIR" ]; then
        print_error "Paymenter is not installed!"
        return 1
    fi
    
    # Create backup
    create_backup || return 1
    
    cd "$PAYMENTER_DIR"
    
    # Enable maintenance mode
    print_status "Enabling maintenance mode..."
    php artisan down
    
    # Update application
    print_status "Downloading latest version..."
    if ! curl -L https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz | tar -xz; then
        print_error "Failed to download or extract update"
        php artisan up
        return 1
    fi
    
    # Update dependencies
    print_status "Updating dependencies..."
    if ! composer install --no-dev --optimize-autoloader; then
        print_error "Failed to update dependencies"
        php artisan up
        return 1
    fi
    
    # Set permissions
    chmod -R 755 storage/* bootstrap/cache/
    
    # Update database
    print_status "Updating database..."
    if ! php artisan migrate --force --seed; then
        print_error "Database migration failed"
        php artisan up
        return 1
    fi
    
    # Clear cache
    print_status "Clearing caches..."
    php artisan config:clear
    php artisan view:clear
    
    # Set permissions
    set_permissions
    
    # Disable maintenance mode
    print_status "Disabling maintenance mode..."
    php artisan up
    
    systemctl restart paymenter.service nginx php8.2-fpm
    print_success "Manual update completed successfully!"
}

# Remove Paymenter
remove_paymenter() {
    print_header "Remove Paymenter"
    
    if [ ! -d "$PAYMENTER_DIR" ]; then
        print_error "Paymenter is not installed!"
        return 1
    fi
    
    print_warning "This will completely remove Paymenter and all its data!"
    read -p "Create backup before removal? (recommended) [Y/n]: " CREATE_BACKUP
    if [[ "$CREATE_BACKUP" =~ ^[Yy]$ ]] || [[ -z "$CREATE_BACKUP" ]]; then
        create_backup
    fi
    
    read -p "Are you absolutely sure you want to remove Paymenter? This cannot be undone! (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_status "Removal cancelled"
        return 1
    fi
    
    print_section "Removing Paymenter"
    
    # Stop services
    print_status "Stopping services..."
    systemctl stop paymenter.service
    systemctl disable paymenter.service
    
    # Remove database
    print_status "Removing database..."
    mysql -e "DROP DATABASE IF EXISTS paymenter;"
    mysql -e "DROP USER IF EXISTS 'paymenter'@'127.0.0.1';"
    
    # Remove files
    print_status "Removing files..."
    rm -rf "$PAYMENTER_DIR"
    rm -f "$NGINX_CONF"
    rm -f /etc/nginx/sites-enabled/paymenter.conf
    rm -f /etc/systemd/system/paymenter.service
    
    # Remove crontab entry
    print_status "Removing crontab entry..."
    crontab -l | grep -v "paymenter/artisan schedule:run" | crontab -
    
    # Reload services
    print_status "Reloading services..."
    systemctl daemon-reload
    systemctl restart nginx
    
    print_success "Paymenter has been completely removed!"
}

# Show main menu
show_menu() {
    while true; do
        print_header "Paymenter Management Script v${SCRIPT_VERSION}"
        echo -e "${CYAN}Please select an option:${NC}"
        echo -e "1) ${WHITE}New Installation${NC}"
        echo -e "2) ${WHITE}Automatic Update${NC}"
        echo -e "3) ${WHITE}Manual Update${NC}"
        echo -e "4) ${WHITE}Create Backup${NC}"
        echo -e "5) ${WHITE}Remove Paymenter${NC}"
        echo -e "6) ${WHITE}Exit${NC}"
        echo
        read -p "Enter choice [1-6]: " choice

        case $choice in
            1)
                perform_installation
                ;;
            2)
                perform_automatic_update
                ;;
            3)
                perform_manual_update
                ;;
            4)
                create_backup
                ;;
            5)
                remove_paymenter
                ;;
            6)
                print_header "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option selected"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Script initialization
{
    # Create directories
    mkdir -p "$BACKUP_DIR"
    
    # Initialize log file
    echo "=== Paymenter Management Script Log - $(date) ===" > "$LOG_FILE"
    echo "Script Version: ${SCRIPT_VERSION}" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # Check root privileges
    check_root
    
    # Start menu
    clear
    show_menu
} 2>&1 | tee -a "$LOG_FILE"

exit 0