# MailChat

**MailChat** is a composable all-in-one email server with blockchain authentication support. It integrates enterprise-grade email server functionality with EVM wallet signature authentication to create a secure, modern email platform.

[![License](https://img.shields.io/badge/license-GPL%203.0-blue)](LICENSE)
[![Go Version](https://img.shields.io/badge/go-1.24+-blue.svg)](https://golang.org)

[English](README.md) | [中文](README_ZH.md)

## Features

### Core Capabilities
- **Full Email Server**: Complete SMTP/IMAP support with enterprise-grade features
- **Blockchain Authentication**: EVM wallet signature-based email access control
- **Multi-DNS Support**: Automated TLS certificates with 15+ DNS provider integrations
- **Spam Protection**: DKIM, SPF, DMARC validation with reputation scoring
- **Flexible Storage**: SQL database backends (PostgreSQL, MySQL, SQLite) and S3-compatible object storage

### Technical Specifications

| Feature | Specification |
|---------|---------------|
| **Email Protocols** | SMTP, IMAP, Submission |
| **Authentication** | EVM Wallet, LDAP, PAM, SASL |
| **TLS** | Automatic ACME certificates |
| **Storage** | SQLite, PostgreSQL, MySQL, S3 |
| **DNS Providers** | 15+ supported |

## Quick Start

### One-Click Installation

Install and configure MailChat with a single command:

```bash
# Download and run the installation script
curl -sSL https://raw.githubusercontent.com/mail-chat-chain/mailchatd/main/start.sh | bash
```

The automated installer will:

1. **Download & Install** the `mailchatd` binary
2. **Domain Configuration** - Set up your email domain
3. **DNS Provider Setup** - Choose from 15 supported providers
4. **TLS Certificate** - Automatic ACME DNS-01 challenge setup
5. **Service Management** - Create and start systemd services

### Supported DNS Providers

| Provider | Type | Authentication |
|----------|------|----------------|
| **Cloudflare** | Global CDN | API Token |
| Amazon Route53 | AWS DNS | Access Key + Secret |
| DigitalOcean | Cloud DNS | API Token |
| Google Cloud DNS | GCP DNS | Service Account JSON |
| Vultr | Cloud DNS | API Key |
| Hetzner | European DNS | API Token |
| Gandi | Domain Registrar | API Token |
| Namecheap | Domain Registrar | API Credentials |
| **+ 7 more** | Various | Various |

## Manual Installation

### Prerequisites

```yaml
System Requirements:
  OS: Ubuntu 20.04+ / macOS 12+ / CentOS 8+
  CPU: 2+ cores
  RAM: 2GB minimum (4GB recommended)
  Storage: 20GB SSD
  Network: 100Mbps

Software Dependencies:
  Go: 1.24+
  Git: Latest
  Make: Latest
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/mail-chat-chain/mailchatd.git
cd mailchatd

# Build the binary
make build

# Verify installation
./build/mailchatd --help
```

### Start the Server

```bash
# Run the mail server
./mailchatd run

# Or use the start.sh script for automated configuration and startup
./start.sh
```

## Email Server Features

### Mail Server Capabilities

- **SMTP/IMAP Services**: Full-featured email server with encrypted communication
- **Blockchain Authentication**: Email access controlled by EVM wallet signatures
- **Distributed Storage**: IMAP mailboxes stored in SQL with optional S3 blob storage
- **Spam Protection**: DKIM, SPF, DMARC validation with reputation scoring

### Configuration Example

```
# mailchatd.conf
$(hostname) = mx1.example.com
$(primary_domain) = example.com

tls {
    loader acme {
        hostname $(hostname)
        email postmaster@$(hostname)
        agreed
        challenge dns-01
        dns cloudflare {
            api_token YOUR_API_TOKEN
        }
    }
}

storage.imapsql local_mailboxes {
    driver sqlite3
    dsn imapsql.db
}

auth.pass_blockchain blockchain_auth {
    blockchain &mailchatd
    storage &local_mailboxes
}

smtp tcp://0.0.0.0:8825 {
    hostname $(hostname)

    source $(primary_domain) {
        deliver_to &local_mailboxes
    }
}

imap tls://0.0.0.0:993 {
    auth &blockchain_auth
    storage &local_mailboxes
}
```

### DNS Management Commands

```bash
# Configure DNS settings
mailchatd dns config

# Check DNS configuration
mailchatd dns check

# Export DNS records for domain setup
mailchatd dns export

# Get public IP for A records
mailchatd dns ip
```

## Available Commands

```
mailchatd [command]

Available Commands:
  run          Start the mail server
  creds        User credentials management
  dns          DNS configuration guide and checker
  hash         Generate password hashes for use with pass_table
  imap-acct    IMAP storage accounts management
  imap-mboxes  IMAP mailboxes (folders) management
  imap-msgs    IMAP messages management
  help         Help about any command
```

## Architecture

### System Components

```
┌─────────────────┐     ┌─────────────────┐
│  Email Client   │────▶│   SMTP/IMAP     │
│  (Thunderbird,  │     │   Endpoints     │
│   Outlook, etc) │     └────────┬────────┘
└─────────────────┘              │
                                 ▼
                    ┌─────────────────────┐
                    │  Authentication     │
                    │  (Blockchain/LDAP)  │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌─────────────┐  ┌───────────┐  ┌──────────┐
     │   Storage   │  │   Check   │  │  Modify  │
     │  (SQL/S3)   │  │(DKIM/SPF) │  │  (DKIM)  │
     └─────────────┘  └───────────┘  └──────────┘
```

### Available Modules

**Authentication:**
- `auth.pass_blockchain` - Blockchain wallet signature authentication
- `auth.pass_table` - Password table authentication
- `auth.ldap` - LDAP directory authentication
- `auth.pam` - Linux PAM authentication
- `auth.external` - External script authentication

**Storage:**
- `storage.imapsql` - SQL database IMAP backend
- `storage.blob.fs` - Filesystem blob storage
- `storage.blob.s3` - S3-compatible object storage

**Checks:**
- `check.dkim` - DKIM signature verification
- `check.spf` - SPF sender policy verification
- `check.dnsbl` - DNS blacklist checking
- `check.rspamd` - Rspamd spam checking

**Endpoints:**
- `smtp` - SMTP server
- `imap` - IMAP server
- `submission` - Mail submission

## Configuration

### Performance Tuning

```
# mailchatd.conf

smtp tcp://0.0.0.0:8825 {
    limits {
        all rate 20 1s
        all concurrency 10
    }
}

imap tls://0.0.0.0:993 {
    io_debug no
}
```

## Documentation

- **[Complete Technical Documentation](DOCUMENTATION.md)** - Comprehensive setup and configuration guide
- **[Deployment Guide](DEPLOYMENT.md)** - Server deployment and management

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Build the project
make build

# Run tests
make test

# Run linter
make lint
```

## License

This project is licensed under the GPL 3.0 License - see the [LICENSE](LICENSE) file for details.

## Links

- **Website**: https://mailcoin.org
- **Documentation**: https://docs.mailcoin.org

## Support

- **GitHub Issues**: For bugs and feature requests
- **Documentation**: For setup and configuration help

---

**MailChat** - Modern Email Server with Blockchain Authentication
