#!/bin/bash

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Detect system architecture
get_system_arch() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            arch="amd64"  # Default to amd64
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Get public IP
get_public_ip() {
    local ip=""
    # Try multiple services to get public IP
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
        ip=$(curl -s --max-time 5 $service 2>/dev/null)
        if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "$ip"
            return
        fi
    done
    echo ""
}

# Installation function
install_mailchatd() {
    print_info "Starting mailchatd installation..."
    
    # Check if already installed
    if command -v mailchatd &> /dev/null; then
        print_success "mailchatd is already installed"
        local version=$(mailchatd version 2>/dev/null || echo "unknown")
        print_info "Current version: $version"
        read -p "Do you want to reinstall? (y/N): " reinstall
        if ! echo "$reinstall" | grep -qE '^[Yy]$'; then
            return 0
        fi
    fi
    
    # Get system architecture
    local system_arch=$(get_system_arch)
    local download_url="https://download.mailcoin.org/mailchatd-${system_arch}-v0.2.2"
    
    print_info "System architecture: $system_arch"
    print_info "Download URL: $download_url"
    
    # Download executable file
    print_info "Downloading mailchatd..."
    if ! curl -L -o /tmp/mailchatd "$download_url"; then
        print_error "Download failed"
        exit 1
    fi
    
    # Install to /usr/local/bin
    print_info "Installing to /usr/local/bin..."
    sudo mv /tmp/mailchatd /usr/local/bin/mailchatd
    sudo chmod +x /usr/local/bin/mailchatd
    
    # Verify installation
    if command -v mailchatd &> /dev/null; then
        print_success "mailchatd installed successfully"
        mailchatd version 2>/dev/null || true
    else
        print_error "Installation failed"
        exit 1
    fi
}

# Collect DNS provider credentials
collect_dns_credentials() {
    local provider="$1"
    
    echo "==============================================="
    echo "DNS Provider Credentials"
    echo "==============================================="
    
    case "$provider" in
        "cloudflare")
            echo "Cloudflare API Token:"
            echo "1. Go to https://dash.cloudflare.com/profile/api-tokens"
            echo "2. Create a Custom Token with Zone:Edit permissions"
            echo "3. Include zones: Your domain"
            stty -echo 2>/dev/null || true
            printf "Enter Cloudflare API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Cloudflare API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "route53")
            echo "Amazon Route53 Credentials:"
            echo "1. Go to AWS IAM Console"
            echo "2. Create user with Route53 permissions"
            echo "3. Get Access Key ID and Secret Access Key"
            
            printf "Enter AWS Access Key ID: "
            read access_key_id
            while [ -z "$access_key_id" ]; do
                print_error "Access Key ID cannot be empty"
                printf "Enter AWS Access Key ID: "
                read access_key_id
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter AWS Secret Access Key: "
            read secret_access_key
            stty echo 2>/dev/null || true
            echo
            while [ -z "$secret_access_key" ]; do
                print_error "Secret Access Key cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter AWS Secret Access Key: "
                read secret_access_key
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="access_key_id $access_key_id
            secret_access_key $secret_access_key"
            ;;
            
        "digitalocean")
            echo "DigitalOcean API Token:"
            echo "1. Go to https://cloud.digitalocean.com/account/api/tokens"
            echo "2. Generate a new Personal Access Token with read/write scope"
            
            stty -echo 2>/dev/null || true
            printf "Enter DigitalOcean API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter DigitalOcean API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "vultr")
            echo "Vultr API Token:"
            echo "1. Go to https://my.vultr.com/settings/#settingsapi"
            echo "2. Generate a new API Key"
            
            stty -echo 2>/dev/null || true
            printf "Enter Vultr API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Vultr API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "hetzner")
            echo "Hetzner DNS API Token:"
            echo "1. Go to https://dns.hetzner.com/settings/api-token"
            echo "2. Generate a new API Token"
            
            stty -echo 2>/dev/null || true
            printf "Enter Hetzner API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Hetzner API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "gandi")
            echo "Gandi API Token:"
            echo "1. Go to https://admin.gandi.net/settings/api-tokens"
            echo "2. Generate a new API Token"
            
            stty -echo 2>/dev/null || true
            printf "Enter Gandi API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Gandi API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "namecheap")
            echo "Namecheap API Credentials:"
            echo "1. Go to https://ap.www.namecheap.com/settings/tools/apiaccess/"
            echo "2. Enable API access and get API Key"
            
            printf "Enter Namecheap API User: "
            read api_user
            while [ -z "$api_user" ]; do
                print_error "API User cannot be empty"
                printf "Enter Namecheap API User: "
                read api_user
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter Namecheap API Key: "
            read api_key
            stty echo 2>/dev/null || true
            echo
            while [ -z "$api_key" ]; do
                print_error "API Key cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Namecheap API Key: "
                read api_key
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_user $api_user
            api_key $api_key"
            ;;
            
        "namedotcom")
            echo "Name.com API Credentials:"
            echo "1. Go to https://www.name.com/account/settings/api"
            echo "2. Generate API Token"
            
            printf "Enter Name.com Username: "
            read user
            while [ -z "$user" ]; do
                print_error "Username cannot be empty"
                printf "Enter Name.com Username: "
                read user
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter Name.com API Token: "
            read token
            stty echo 2>/dev/null || true
            echo
            while [ -z "$token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Name.com API Token: "
                read token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="user $user
            token $token"
            ;;
            
        "googleclouddns")
            echo "Google Cloud DNS Credentials:"
            echo "1. Create a service account in Google Cloud Console"
            echo "2. Download service account JSON key file"
            echo "3. Provide the full path to the JSON file"
            
            printf "Enter path to service account JSON file: "
            read service_account_json
            while [ -z "$service_account_json" ] || [ ! -f "$service_account_json" ]; do
                if [ -z "$service_account_json" ]; then
                    print_error "Path cannot be empty"
                else
                    print_error "File does not exist: $service_account_json"
                fi
                printf "Enter path to service account JSON file: "
                read service_account_json
            done
            
            dns_config="service_account_json $service_account_json"
            ;;
            
        "gcore")
            echo "G-Core Labs API Token:"
            echo "1. Go to your G-Core Labs account settings"
            echo "2. Generate a new API Token"
            
            stty -echo 2>/dev/null || true
            printf "Enter G-Core Labs API Token: "
            read api_token
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_token" ]; do
                print_error "API Token cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter G-Core Labs API Token: "
                read api_token
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_token $api_token"
            ;;
            
        "alidns")
            echo "Alibaba Cloud DNS Credentials:"
            echo "1. Go to Alibaba Cloud Console"
            echo "2. Access Resource Access Management (RAM)"
            echo "3. Create AccessKey pair with DNS permissions"
            
            printf "Enter Access Key ID: "
            read key_id
            while [ -z "$key_id" ]; do
                print_error "Access Key ID cannot be empty"
                printf "Enter Access Key ID: "
                read key_id
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter Access Key Secret: "
            read key_secret
            stty echo 2>/dev/null || true
            echo
            while [ -z "$key_secret" ]; do
                print_error "Access Key Secret cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Access Key Secret: "
                read key_secret
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="key_id $key_id
            key_secret $key_secret"
            ;;
            
        "acmedns")
            echo "ACME-DNS Credentials:"
            echo "1. Set up an ACME-DNS server or use an existing one"
            echo "2. Register an account and get credentials"
            echo "3. Configure subdomain delegation"
            
            printf "Enter ACME-DNS Username: "
            read username
            while [ -z "$username" ]; do
                print_error "Username cannot be empty"
                printf "Enter ACME-DNS Username: "
                read username
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter ACME-DNS Password: "
            read password
            stty echo 2>/dev/null || true
            echo
            while [ -z "$password" ]; do
                print_error "Password cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter ACME-DNS Password: "
                read password
                stty echo 2>/dev/null || true
                echo
            done
            
            printf "Enter ACME-DNS Subdomain: "
            read subdomain
            while [ -z "$subdomain" ]; do
                print_error "Subdomain cannot be empty"
                printf "Enter ACME-DNS Subdomain: "
                read subdomain
            done
            
            printf "Enter ACME-DNS Server URL [default: https://auth.acme-dns.io]: "
            read server_url
            server_url=${server_url:-https://auth.acme-dns.io}
            
            dns_config="username $username
            password $password
            subdomain $subdomain
            server_url $server_url"
            ;;
            
        "leaseweb")
            echo "LeaseWeb DNS API Key:"
            echo "1. Go to LeaseWeb Customer Portal"
            echo "2. Navigate to API settings"
            echo "3. Generate a new API Key"
            
            stty -echo 2>/dev/null || true
            printf "Enter LeaseWeb API Key: "
            read api_key
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_key" ]; do
                print_error "API Key cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter LeaseWeb API Key: "
                read api_key
                stty echo 2>/dev/null || true
                echo
            done
            
            dns_config="api_key $api_key"
            ;;
            
        "metaname")
            echo "Metaname DNS API Credentials:"
            echo "1. Go to https://metaname.net/"
            echo "2. Navigate to API settings"
            echo "3. Generate API Key and get Account Reference"
            
            stty -echo 2>/dev/null || true
            printf "Enter Metaname API Key: "
            read api_key
            stty echo 2>/dev/null || true
            echo
            
            while [ -z "$api_key" ]; do
                print_error "API Key cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter Metaname API Key: "
                read api_key
                stty echo 2>/dev/null || true
                echo
            done
            
            printf "Enter Account Reference: "
            read account_ref
            while [ -z "$account_ref" ]; do
                print_error "Account Reference cannot be empty"
                printf "Enter Account Reference: "
                read account_ref
            done
            
            dns_config="api_key $api_key
            account_ref $account_ref"
            ;;
            
        "rfc2136")
            echo "RFC2136 DNS Credentials:"
            echo "1. Configure your DNS server for RFC2136 dynamic updates"
            echo "2. Generate TSIG key for authentication"
            echo "3. Note down server address and key details"
            
            printf "Enter DNS Server Address (with port): "
            read server
            while [ -z "$server" ]; do
                print_error "Server address cannot be empty"
                printf "Enter DNS Server Address (with port): "
                read server
            done
            
            printf "Enter TSIG Key Name: "
            read key_name
            while [ -z "$key_name" ]; do
                print_error "Key name cannot be empty"
                printf "Enter TSIG Key Name: "
                read key_name
            done
            
            stty -echo 2>/dev/null || true
            printf "Enter TSIG Key Secret: "
            read key_secret
            stty echo 2>/dev/null || true
            echo
            while [ -z "$key_secret" ]; do
                print_error "Key secret cannot be empty"
                stty -echo 2>/dev/null || true
                printf "Enter TSIG Key Secret: "
                read key_secret
                stty echo 2>/dev/null || true
                echo
            done
            
            printf "Enter TSIG Key Algorithm [default: hmac-sha256]: "
            read key_alg
            key_alg=${key_alg:-hmac-sha256}
            
            dns_config="server $server
            key_name $key_name
            key $key_secret
            key_alg $key_alg"
            ;;
            
        *)
            print_error "Unsupported DNS provider: $provider"
            exit 1
            ;;
    esac
    
    print_success "DNS credentials collected successfully"
}

# Configuration function
configure_mailchatd() {
    print_info "Starting mailchatd configuration..."
    
    # 1. Ask for working directory path
    # Check if NODE_HOME is already set
    if [ -n "$NODE_HOME" ]; then
        print_info "Detected existing NODE_HOME: $NODE_HOME"
        read -p "Enter working directory path [default: $NODE_HOME]: " work_dir
        work_dir=${work_dir:-$NODE_HOME}
    else
        read -p "Enter working directory path [default: /root/.mailchatd]: " work_dir
        work_dir=${work_dir:-/root/.mailchatd}
    fi
    
    # Set and export NODE_HOME immediately
    export NODE_HOME="$work_dir"
    print_info "Working directory: $work_dir"
    print_success "NODE_HOME set to: $NODE_HOME"
    
    # Permanently save NODE_HOME environment variable
    print_info "Permanently saving NODE_HOME environment variable..."
    
    # Detect shell type
    if [ -n "$BASH_VERSION" ]; then
        # Bash shell
        if [ -f "$HOME/.bashrc" ]; then
            # Check if NODE_HOME setting already exists
            if ! grep -q "export NODE_HOME=" "$HOME/.bashrc"; then
                echo "" >> "$HOME/.bashrc"
                echo "# MailChat Node Home Directory" >> "$HOME/.bashrc"
                echo "export NODE_HOME=\"$work_dir\"" >> "$HOME/.bashrc"
                print_success "NODE_HOME added to ~/.bashrc"
            else
                # Update existing NODE_HOME
                sed -i.bak "s|export NODE_HOME=.*|export NODE_HOME=\"$work_dir\"|" "$HOME/.bashrc"
                print_success "Updated NODE_HOME in ~/.bashrc"
            fi
        fi
        
        # Also update .profile for compatibility
        if [ -f "$HOME/.profile" ]; then
            if ! grep -q "export NODE_HOME=" "$HOME/.profile"; then
                echo "" >> "$HOME/.profile"
                echo "# MailChat Node Home Directory" >> "$HOME/.profile"
                echo "export NODE_HOME=\"$work_dir\"" >> "$HOME/.profile"
                print_success "NODE_HOME added to ~/.profile"
            else
                sed -i.bak "s|export NODE_HOME=.*|export NODE_HOME=\"$work_dir\"|" "$HOME/.profile"
                print_success "Updated NODE_HOME in ~/.profile"
            fi
        fi
    else
        # POSIX sh
        if [ -f "$HOME/.profile" ]; then
            if ! grep -q "export NODE_HOME=" "$HOME/.profile"; then
                echo "" >> "$HOME/.profile"
                echo "# MailChat Node Home Directory" >> "$HOME/.profile"
                echo "export NODE_HOME=\"$work_dir\"" >> "$HOME/.profile"
                print_success "NODE_HOME added to ~/.profile"
            else
                sed -i.bak "s|export NODE_HOME=.*|export NODE_HOME=\"$work_dir\"|" "$HOME/.profile"
                print_success "Updated NODE_HOME in ~/.profile"
            fi
        fi
    fi
    
    # For system-level settings (requires root permission)
    if [ "$(id -u)" -eq 0 ]; then
        # Create system-level environment variable file
        if [ -d "/etc/profile.d" ]; then
            cat > /etc/profile.d/mailchatd.sh << EOF
# MailChat Node Environment Variables
export NODE_HOME="$work_dir"
EOF
            chmod 644 /etc/profile.d/mailchatd.sh
            print_success "Created system-level environment file /etc/profile.d/mailchatd.sh"
        fi
        
        # For systemd services, create or update environment file
        mkdir -p /etc/mailchatd
        cat > /etc/mailchatd/environment << EOF
NODE_HOME=$work_dir
EOF
        print_success "Created systemd environment file /etc/mailchatd/environment"
        
        # Add to /etc/environment for system-wide availability
        if [ -f "/etc/environment" ]; then
            # Check if NODE_HOME already exists
            if grep -q "^NODE_HOME=" "/etc/environment"; then
                # Update existing NODE_HOME
                sed -i.bak "s|^NODE_HOME=.*|NODE_HOME=\"$work_dir\"|" "/etc/environment"
                print_success "Updated NODE_HOME in /etc/environment"
            else
                # Add new NODE_HOME
                echo "NODE_HOME=\"$work_dir\"" >> "/etc/environment"
                print_success "NODE_HOME added to /etc/environment"
            fi
        fi
    else
        print_info "Root permission required to set system-level environment variables"
        print_info "Please run script with sudo to permanently save environment variables"
    fi
    
    # Load environment variables immediately (for current script session)
    if [ -f "/etc/profile.d/mailchatd.sh" ]; then
        . /etc/profile.d/mailchatd.sh
    fi
    
    print_success "NODE_HOME environment variable set and effective immediately: $NODE_HOME"
    print_info "Environment variables permanently saved, new terminal sessions will load automatically"
    
    # Initialize node
    print_info "Initializing node..."
    print_info "Using NODE_HOME=$NODE_HOME"
    
    if [ -d "$work_dir/config" ]; then
        print_info "Node configuration directory already exists"
        read -p "Do you want to reinitialize the node? (y/N): " reinit
        if echo "$reinit" | grep -qE '^[Yy]$'; then
            # Backup existing configuration
            if [ -f "$work_dir/config/genesis.json" ]; then
                mv "$work_dir/config/genesis.json" "$work_dir/config/genesis.json.bak"
                print_info "Backed up existing genesis.json"
            fi
            if [ -f "$work_dir/config/config.toml" ]; then
                mv "$work_dir/config/config.toml" "$work_dir/config/config.toml.bak"
                print_info "Backed up existing config.toml"
            fi
            NODE_HOME="$work_dir" mailchatd init localnode
            print_success "Node reinitialization completed"
        else
            print_info "Skipping node initialization"
        fi
    else
        NODE_HOME="$work_dir" mailchatd init localnode
        print_success "Node initialization completed"
    fi
    
    # Copy default mailchatd.conf file (if it doesn't exist)
    if [ ! -f "$work_dir/mailchatd.conf" ]; then
        print_info "Creating default configuration file..."
        # Try to copy from precompiles directory
        if [ -f "./precompiles/mailchatd.conf" ]; then
            cp "./precompiles/mailchatd.conf" "$work_dir/mailchatd.conf"
        elif [ -f "/usr/share/mailchatd/mailchatd.conf" ]; then
            cp "/usr/share/mailchatd/mailchatd.conf" "$work_dir/mailchatd.conf"
        else
            # Download default configuration file
            print_info "Downloading default mailchatd.conf..."
            if ! curl -L -o "$work_dir/mailchatd.conf" "https://download.mailcoin.org/mailchatd.conf"; then
                print_error "Unable to get default configuration file"
                exit 1
            fi
        fi
        print_success "Default configuration file created successfully"
    fi
    
    # 2. Download configuration files
    print_info "Downloading configuration files..."
    
    # Ensure configuration directory exists
    mkdir -p "$work_dir/config"
    
    # Download genesis.json (always overwrite, as official genesis block is needed)
    print_info "Downloading official genesis.json..."
    if [ -f "$work_dir/config/genesis.json" ]; then
        mv "$work_dir/config/genesis.json" "$work_dir/config/genesis.json.old"
        print_info "Backed up original genesis.json as genesis.json.old"
    fi
    if curl -L -o "$work_dir/config/genesis.json" "https://download.mailcoin.org/genesis.json"; then
        print_success "genesis.json downloaded successfully"
    else
        print_error "genesis.json download failed"
        exit 1
    fi
    
    # Download config.toml (always overwrite, as official configuration is needed)
    print_info "Downloading official config.toml..."
    if [ -f "$work_dir/config/config.toml" ]; then
        mv "$work_dir/config/config.toml" "$work_dir/config/config.toml.old"
        print_info "Backed up original config.toml as config.toml.old"
    fi
    if curl -L -o "$work_dir/config/config.toml" "https://download.mailcoin.org/config.toml"; then
        print_success "config.toml downloaded successfully"
    else
        print_error "config.toml download failed"
        exit 1
    fi
    
    # 3. Ask for email domain
    read -p "Enter email domain: " email_domain
    while [ -z "$email_domain" ]; do
        print_error "Email domain cannot be empty"
        read -p "Enter email domain: " email_domain
    done
    
    # 4. Ask for public IP
    local detected_ip=$(get_public_ip)
    if [ -n "$detected_ip" ]; then
        read -p "Enter public IP [default: $detected_ip]: " public_ip
        public_ip=${public_ip:-$detected_ip}
    else
        read -p "Enter public IP: " public_ip
        while [ -z "$public_ip" ]; do
            print_error "Public IP cannot be empty"
            read -p "Enter public IP: " public_ip
        done
    fi
    
    # 5. Ask for DNS provider with comprehensive options
    echo ""
    echo "==============================================="
    echo "DNS Provider Selection"
    echo "==============================================="
    echo "Available DNS providers:"
    echo "1)  cloudflare      - Cloudflare DNS (requires: api_token)"
    echo "2)  route53         - Amazon Route53 (requires: access_key_id, secret_access_key)"  
    echo "3)  digitalocean    - DigitalOcean DNS (requires: api_token)"
    echo "4)  vultr           - Vultr DNS (requires: api_token)"
    echo "5)  hetzner         - Hetzner DNS (requires: api_token)"
    echo "6)  gandi           - Gandi DNS (requires: api_token)"
    echo "7)  namecheap       - Namecheap DNS (requires: api_user, api_key)"
    echo "8)  namedotcom      - Name.com DNS (requires: user, token)"
    echo "9)  googleclouddns  - Google Cloud DNS (requires: service_account_json)"
    echo "10) gcore           - G-Core Labs DNS (requires: api_token)"
    echo "11) alidns          - Alibaba Cloud DNS (requires: key_id, key_secret)"
    echo "12) acmedns         - ACME-DNS (requires: username, password, subdomain, server_url)"
    echo "13) leaseweb        - LeaseWeb DNS (requires: api_key)"
    echo "14) metaname        - Metaname DNS (requires: api_key)"
    echo "15) rfc2136         - RFC2136 DNS (requires: server, key_name, key_secret)"
    echo "==============================================="
    
    while true; do
        read -p "Select DNS provider (1-15) [default: 1 (cloudflare)]: " dns_choice
        dns_choice=${dns_choice:-1}
        
        case "$dns_choice" in
            1)
                dns_provider="cloudflare"
                dns_display_name="Cloudflare"
                break
                ;;
            2)
                dns_provider="route53"
                dns_display_name="Amazon Route53"
                break
                ;;
            3)
                dns_provider="digitalocean"
                dns_display_name="DigitalOcean"
                break
                ;;
            4)
                dns_provider="vultr"
                dns_display_name="Vultr"
                break
                ;;
            5)
                dns_provider="hetzner"
                dns_display_name="Hetzner"
                break
                ;;
            6)
                dns_provider="gandi"
                dns_display_name="Gandi"
                break
                ;;
            7)
                dns_provider="namecheap"
                dns_display_name="Namecheap"
                break
                ;;
            8)
                dns_provider="namedotcom"
                dns_display_name="Name.com"
                break
                ;;
            9)
                dns_provider="googleclouddns"
                dns_display_name="Google Cloud DNS"
                break
                ;;
            10)
                dns_provider="gcore"
                dns_display_name="G-Core Labs"
                break
                ;;
            11)
                dns_provider="alidns"
                dns_display_name="Alibaba Cloud DNS"
                break
                ;;
            12)
                dns_provider="acmedns"
                dns_display_name="ACME-DNS"
                break
                ;;
            13)
                dns_provider="leaseweb"
                dns_display_name="LeaseWeb"
                break
                ;;
            14)
                dns_provider="metaname"
                dns_display_name="Metaname"
                break
                ;;
            15)
                dns_provider="rfc2136"
                dns_display_name="RFC2136"
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1-15."
                continue
                ;;
        esac
    done
    
    print_info "Selected DNS provider: $dns_display_name"
    echo ""
    
    # 6. Collect DNS provider credentials based on selection
    collect_dns_credentials "$dns_provider"
    
    # 7. Modify mailchatd.conf
    local config_file="$work_dir/mailchatd.conf"
    
    print_info "Updating configuration file..."
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file does not exist: $config_file"
        exit 1
    fi
    
    # Backup original configuration
    cp "$config_file" "${config_file}.bak"
    print_info "Backed up original configuration file as ${config_file}.bak"
    
    # Use sed for replacement (better compatibility)
    # Replace hostname
    sed -i.tmp "s/\$(hostname) = .*/\$(hostname) = mx1.$email_domain/" "$config_file"
    
    # Replace primary_domain
    sed -i.tmp "s/\$(primary_domain) = .*/\$(primary_domain) = $email_domain/" "$config_file"
    
    # Replace DNS provider and credentials in TLS block
    # Replace the DNS provider line (preserve indentation and support dots in provider names)
    sed -i.tmp "s/\([[:space:]]*\)dns [a-zA-Z0-9_.][a-zA-Z0-9_.]*[[:space:]]*{/\1dns $dns_provider {/" "$config_file"
    
    # Replace DNS credentials block - remove old credential lines and insert new ones
    # Find the line number of the DNS provider opening brace
    dns_start=$(grep -n "dns.*{" "$config_file" | cut -d: -f1)
    if [ -n "$dns_start" ]; then
        # Find the closing brace line number for the DNS block
        dns_end=$(sed -n "${dns_start},\$p" "$config_file" | grep -n "^[[:space:]]*}" | head -1 | cut -d: -f1)
        if [ -n "$dns_end" ]; then
            dns_end=$((dns_start + dns_end - 1))
            
            # Create temporary file with new DNS configuration
            {
                # Lines before DNS block content (including opening brace)
                sed -n "1,${dns_start}p" "$config_file"
                # Insert new DNS configuration with proper indentation
                echo "$dns_config" | sed 's/^[[:space:]]*/            /'
                # Lines from closing brace onwards
                sed -n "${dns_end},\$p" "$config_file"
            } > "${config_file}.new"
            
            mv "${config_file}.new" "$config_file"
            print_success "DNS provider configuration updated successfully"
        else
            print_error "Could not find DNS configuration block ending"
            # Fallback to simple replacement for backward compatibility
            sed -i.tmp "s/api_token .*/api_token $(echo "$dns_config" | grep api_token | cut -d' ' -f2-)/" "$config_file"
            print_info "Applied fallback configuration update"
        fi
    else
        print_error "Could not find DNS configuration block"
        exit 1
    fi
    
    # Delete temporary files
    rm -f "${config_file}.tmp"
    
    print_success "Configuration file update completed"
    
    # 8. Check DNS settings
    print_info "Checking DNS settings..."
    if NODE_HOME="$work_dir" mailchatd dns check; then
        print_success "DNS settings check passed"
    else
        print_error "DNS settings check failed, please check configuration"
    fi
    
    # 9. Export DNS configuration information
    print_info "Exporting DNS configuration information..."
    NODE_HOME="$work_dir" mailchatd dns export
    
    print_success "Configuration completed"
}

# Create and start services
start_services() {
    print_info "Starting to set up system services..."
    
    # Determine NODE_HOME value
    local node_home
    if [ -f "/etc/mailchatd/environment" ]; then
        # Read from environment file
        node_home=$(grep "^NODE_HOME=" /etc/mailchatd/environment | cut -d= -f2)
    fi
    
    # If not in environment file, try to get from environment variable
    if [ -z "$node_home" ]; then
        node_home="${NODE_HOME}"
    fi
    
    # If still not available, ask user
    if [ -z "$node_home" ]; then
        read -p "Enter NODE_HOME path [default: /root/.mailchatd]: " node_home
        node_home=${node_home:-/root/.mailchatd}
        
        # Save to environment file
        mkdir -p /etc/mailchatd
        cat > /etc/mailchatd/environment << EOF
NODE_HOME=$node_home
EOF
        print_success "NODE_HOME saved to /etc/mailchatd/environment"
    else
        print_info "Using NODE_HOME: $node_home"
    fi
    
    # Check and handle mailchatd.service
    local create_mailchatd_service=false
    
    if [ -f "/etc/systemd/system/mailchatd.service" ]; then
        print_info "Detected existing mailchatd.service"
        read -p "Stop and recreate mailchatd.service? (y/N): " recreate_service
        if echo "$recreate_service" | grep -qE '^[Yy]$'; then
            print_info "Stopping mailchatd.service..."
            sudo systemctl stop mailchatd.service 2>/dev/null || true
            sudo systemctl disable mailchatd.service 2>/dev/null || true
            sudo rm -f /etc/systemd/system/mailchatd.service
            sudo systemctl daemon-reload
            print_success "Old mailchatd.service removed"
            create_mailchatd_service=true
        else
            print_info "Keeping existing mailchatd.service"
        fi
    else
        create_mailchatd_service=true
    fi
    
    # Create mailchatd.service
    if [ "$create_mailchatd_service" = true ]; then
        print_info "Creating mailchatd.service..."
        
        cat > /tmp/mailchatd.service << EOF
[Unit]
Description=MailChat Blockchain Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/mailchatd/environment
ExecStart=/usr/local/bin/mailchatd start --log_level info
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

# Security restrictions
PrivateTmp=false
ProtectSystem=strict
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
        
        sudo mv /tmp/mailchatd.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable mailchatd.service
        print_success "mailchatd.service created successfully"
    fi
    
    # Start mailchatd.service (if service file exists)
    if [ -f "/etc/systemd/system/mailchatd.service" ]; then
        print_info "Starting mailchatd.service..."
        sudo systemctl restart mailchatd.service
        if sudo systemctl is-active --quiet mailchatd.service; then
            print_success "mailchatd.service started successfully"
        else
            print_error "mailchatd.service failed to start"
            sudo systemctl status mailchatd.service --no-pager
        fi
    else
        print_info "mailchatd.service does not exist, skipping startup"
    fi
    
    # Check and handle mailchatd-mail.service
    local create_mail_service=false
    
    if [ -f "/etc/systemd/system/mailchatd-mail.service" ]; then
        print_info "Detected existing mailchatd-mail.service"
        read -p "Stop and recreate mailchatd-mail.service? (y/N): " recreate_mail_service
        if echo "$recreate_mail_service" | grep -qE '^[Yy]$'; then
            print_info "Stopping mailchatd-mail.service..."
            sudo systemctl stop mailchatd-mail.service 2>/dev/null || true
            sudo systemctl disable mailchatd-mail.service 2>/dev/null || true
            sudo rm -f /etc/systemd/system/mailchatd-mail.service
            sudo systemctl daemon-reload
            print_success "Old mailchatd-mail.service removed"
            create_mail_service=true
        else
            print_info "Keeping existing mailchatd-mail.service"
        fi
    else
        create_mail_service=true
    fi
    
    # Create mailchatd-mail.service
    if [ "$create_mail_service" = true ]; then
        print_info "Creating mailchatd-mail.service..."
        
        cat > /tmp/mailchatd-mail.service << EOF
[Unit]
Description=MailChat Mail Service
After=network-online.target mailchatd.service
Wants=network-online.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/mailchatd/environment
ExecStart=/usr/local/bin/mailchatd run
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

# Security restrictions
PrivateTmp=false
ProtectSystem=strict
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
        
        sudo mv /tmp/mailchatd-mail.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable mailchatd-mail.service
        print_success "mailchatd-mail.service created successfully"
    fi
    
    # Start mailchatd-mail.service (if service file exists)
    if [ -f "/etc/systemd/system/mailchatd-mail.service" ]; then
        print_info "Starting mailchatd-mail.service..."
        sudo systemctl restart mailchatd-mail.service
        if sudo systemctl is-active --quiet mailchatd-mail.service; then
            print_success "mailchatd-mail.service started successfully"
        else
            print_error "mailchatd-mail.service failed to start"
            sudo systemctl status mailchatd-mail.service --no-pager
        fi
    else
        print_info "mailchatd-mail.service does not exist, skipping startup"
    fi
    
    print_success "All services have been set up and started"
}

# Show menu
show_menu() {
    echo "========================================"
    echo "       MailChat Installation and Configuration Script"
    echo "========================================"
    echo "1. Complete installation (Install + Configure + Start)"
    echo "2. Install mailchatd only"
    echo "3. Configure mailchatd only"
    echo "4. Start services only"
    echo "5. Exit"
    echo "========================================"
}

# Main function
main() {
    # Check if running as root user
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script requires root permission to run"
        print_info "Please use: sudo $0"
        exit 1
    fi
    
    show_menu
    read -p "Please select an option [1-5]: " choice
    
    case $choice in
        1)
            install_mailchatd
            configure_mailchatd
            start_services
            print_success "Complete installation finished!"
            ;;
        2)
            install_mailchatd
            ;;
        3)
            configure_mailchatd
            ;;
        4)
            start_services
            ;;
        5)
            print_info "Exiting"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    print_info "Current NODE_HOME: $NODE_HOME"
    print_info "View service status:"
    print_info "  systemctl status mailchatd"
    print_info "  systemctl status mailchatd-mail"
    print_info "View logs:"
    print_info "  journalctl -u mailchatd -f"
    print_info "  journalctl -u mailchatd-mail -f"
    print_info "Manually load environment variables (if needed):"
    print_info "  source /etc/profile.d/mailchatd.sh"
}

# Run main function
main "$@"