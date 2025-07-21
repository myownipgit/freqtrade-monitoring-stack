#!/bin/bash

# Freqtrade Monitoring Stack - Configuration Management Script
# Interactive tool for managing bot configurations, environment variables, and settings

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Show help
show_help() {
    cat << EOF
Configuration Management Script for Freqtrade Monitoring Stack

USAGE:
    ./scripts/config-manager.sh [COMMAND] [OPTIONS]

COMMANDS:
    interactive     Interactive configuration wizard (default)
    env             Manage environment variables
    bot             Configure bot settings
    grafana         Configure Grafana settings
    prometheus      Configure Prometheus settings
    security        Configure security settings
    backup          Backup all configurations
    restore         Restore configurations from backup
    validate        Validate all configuration files
    reset           Reset to default configurations

OPTIONS:
    -h, --help      Show this help message
    -f, --file      Specify configuration file
    -b, --bot       Specify bot name (bot1, bot2, etc.)
    -v, --verbose   Enable verbose output

EXAMPLES:
    ./scripts/config-manager.sh                    # Interactive wizard
    ./scripts/config-manager.sh env                # Manage environment
    ./scripts/config-manager.sh bot --bot bot1     # Configure specific bot
    ./scripts/config-manager.sh validate           # Validate configs

EOF
}

# Interactive configuration wizard
interactive_wizard() {
    log_header "Freqtrade Monitoring Stack Configuration Wizard"
    
    echo -e "${CYAN}Welcome to the configuration wizard!${NC}"
    echo "This will help you set up your monitoring stack."
    echo
    
    # Environment setup
    setup_environment_interactive
    
    # Bot configuration
    setup_bots_interactive
    
    # Security settings
    setup_security_interactive
    
    # Grafana settings
    setup_grafana_interactive
    
    # Final confirmation
    echo
    log_success "Configuration completed!"
    echo "You can now run: ./deploy.sh install"
}

# Interactive environment setup
setup_environment_interactive() {
    log_header "Environment Configuration"
    
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_info "Creating environment file..."
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    fi
    
    echo "Current environment settings:"
    echo
    
    # Grafana admin password
    local current_password
    current_password=$(grep "GF_SECURITY_ADMIN_PASSWORD" "$PROJECT_DIR/.env" | cut -d'=' -f2)
    echo -n "Grafana admin password [$current_password]: "
    read -r new_password
    if [ -n "$new_password" ]; then
        sed -i.bak "s/GF_SECURITY_ADMIN_PASSWORD=.*/GF_SECURITY_ADMIN_PASSWORD=$new_password/" "$PROJECT_DIR/.env"
        rm "$PROJECT_DIR/.env.bak"
        log_success "Grafana password updated"
    fi
    
    # Ports configuration
    echo
    echo "Port Configuration:"
    configure_port "Grafana" "GRAFANA_PORT" "3000"
    configure_port "Prometheus" "PROMETHEUS_PORT" "9090"
    configure_port "FTMetric Bot1" "FTMETRIC_BOT1_PORT" "8091"
}

# Configure individual port
configure_port() {
    local service_name="$1"
    local env_var="$2"
    local default_port="$3"
    
    local current_port
    current_port=$(grep "$env_var" "$PROJECT_DIR/.env" 2>/dev/null | cut -d'=' -f2 || echo "$default_port")
    
    echo -n "$service_name port [$current_port]: "
    read -r new_port
    
    if [ -n "$new_port" ] && [ "$new_port" != "$current_port" ]; then
        if grep -q "$env_var" "$PROJECT_DIR/.env"; then
            sed -i.bak "s/$env_var=.*/$env_var=$new_port/" "$PROJECT_DIR/.env"
        else
            echo "$env_var=$new_port" >> "$PROJECT_DIR/.env"
        fi
        rm -f "$PROJECT_DIR/.env.bak"
        log_success "$service_name port updated to $new_port"
    fi
}

# Interactive bot setup
setup_bots_interactive() {
    log_header "Bot Configuration"
    
    echo "How many bots would you like to monitor?"
    echo "1) Single bot (recommended for beginners)"
    echo "2) Multiple bots"
    echo "3) Demo mode only (mock data)"
    echo -n "Choice [3]: "
    read -r bot_choice
    
    case "${bot_choice:-3}" in
        1)
            configure_single_bot
            ;;
        2)
            configure_multiple_bots
            ;;
        3)
            log_info "Using demo mode with mock data"
            ;;
        *)
            log_warning "Invalid choice, using demo mode"
            ;;
    esac
}

# Configure single bot
configure_single_bot() {
    log_info "Configuring single bot..."
    
    local config_file="$PROJECT_DIR/freqtrade/user_data/config_bot1.json"
    
    echo -n "Bot name [freqtrade-bot1]: "
    read -r bot_name
    bot_name=${bot_name:-freqtrade-bot1}
    
    echo -n "Stake currency [USDT]: "
    read -r stake_currency
    stake_currency=${stake_currency:-USDT}
    
    echo -n "Stake amount [$100]: "
    read -r stake_amount
    stake_amount=${stake_amount:-100}
    
    echo -n "Dry run mode? [y/N]: "
    read -r dry_run
    dry_run=${dry_run:-y}
    
    if [[ "$dry_run" =~ ^[Yy]$ ]]; then
        dry_run_value="true"
        echo -n "Dry run wallet amount [$1000]: "
        read -r wallet_amount
        wallet_amount=${wallet_amount:-1000}
    else
        dry_run_value="false"
        wallet_amount="0"
        log_warning "Live trading mode selected. Ensure you have proper API credentials!"
    fi
    
    # Update configuration
    update_bot_config "$config_file" "$bot_name" "$stake_currency" "$stake_amount" "$dry_run_value" "$wallet_amount"
    
    log_success "Bot configuration updated"
}

# Update bot configuration file
update_bot_config() {
    local config_file="$1"
    local bot_name="$2"
    local stake_currency="$3"
    local stake_amount="$4"
    local dry_run="$5"
    local wallet_amount="$6"
    
    # Create temporary config with updated values
    cat > "$config_file" << EOF
{
    "max_open_trades": 5,
    "stake_currency": "$stake_currency",
    "stake_amount": $stake_amount,
    "tradable_balance_ratio": 0.99,
    "fiat_display_currency": "USD",
    "dry_run": $dry_run,
    "dry_run_wallet": $wallet_amount,
    "cancel_open_orders_on_exit": false,
    
    "bid_strategy": {
        "price_side": "bid",
        "ask_last_balance": 0.0,
        "use_order_book": true,
        "order_book_top": 1
    },
    
    "ask_strategy": {
        "price_side": "ask",
        "use_order_book": true,
        "order_book_top": 1
    },
    
    "exchange": {
        "name": "binance",
        "key": "",
        "secret": "",
        "pair_whitelist": [
            "BTC/USDT",
            "ETH/USDT",
            "ADA/USDT"
        ],
        "pair_blacklist": []
    },
    
    "pairlists": [
        {
            "method": "StaticPairList"
        }
    ],
    
    "api_server": {
        "enabled": true,
        "listen_ip_address": "0.0.0.0",
        "listen_port": 8080,
        "verbosity": "error",
        "enable_openapi": false,
        "jwt_secret_key": "something-random",
        "CORS_origins": [],
        "username": "freqtrader",
        "password": "SuperSecret1!"
    },
    
    "bot_name": "$bot_name",
    "initial_state": "running",
    "force_entry_enable": false,
    "internals": {
        "process_throttle_secs": 5
    },
    "dataformat_ohlcv": "json",
    "dataformat_trades": "jsongz"
}
EOF
}

# Configure multiple bots
configure_multiple_bots() {
    log_info "Configuring multiple bots..."
    
    echo -n "Number of bots [2]: "
    read -r num_bots
    num_bots=${num_bots:-2}
    
    for ((i=1; i<=num_bots; i++)); do
        echo
        log_info "Configuring bot $i..."
        
        local config_file="$PROJECT_DIR/freqtrade/user_data/config_bot$i.json"
        
        echo -n "Bot $i name [freqtrade-bot$i]: "
        read -r bot_name
        bot_name=${bot_name:-freqtrade-bot$i}
        
        # Use default values for multiple bots to speed up setup
        update_bot_config "$config_file" "$bot_name" "USDT" "100" "true" "1000"
        
        log_success "Bot $i configured"
    done
}

# Security configuration
setup_security_interactive() {
    log_header "Security Configuration"
    
    echo "Configure security settings:"
    echo
    
    # JWT secret
    echo -n "Generate new JWT secret? [Y/n]: "
    read -r generate_jwt
    if [[ ! "$generate_jwt" =~ ^[Nn]$ ]]; then
        local jwt_secret
        jwt_secret=$(openssl rand -hex 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
        
        if grep -q "JWT_SECRET_KEY" "$PROJECT_DIR/.env"; then
            sed -i.bak "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$jwt_secret/" "$PROJECT_DIR/.env"
        else
            echo "JWT_SECRET_KEY=$jwt_secret" >> "$PROJECT_DIR/.env"
        fi
        rm -f "$PROJECT_DIR/.env.bak"
        
        log_success "JWT secret generated"
    fi
    
    # API credentials warning
    echo
    log_warning "Exchange API Credentials:"
    echo "For live trading, you'll need to manually add exchange API credentials"
    echo "to the bot configuration files. Never commit real API keys to git!"
}

# Grafana configuration
setup_grafana_interactive() {
    log_header "Grafana Configuration"
    
    echo "Grafana dashboard settings:"
    echo
    
    echo -n "Enable additional plugins? [y/N]: "
    read -r enable_plugins
    
    if [[ "$enable_plugins" =~ ^[Yy]$ ]]; then
        echo "Additional plugins will be installed:"
        echo "- grafana-piechart-panel"
        echo "- grafana-clock-panel"
        log_info "Plugins configured in docker-compose.yml"
    fi
    
    echo -n "Auto-provision demo dashboards? [Y/n]: "
    read -r provision_dashboards
    
    if [[ ! "$provision_dashboards" =~ ^[Nn]$ ]]; then
        log_success "Demo dashboards will be auto-provisioned"
    fi
}

# Environment management
manage_environment() {
    log_header "Environment Variable Management"
    
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_info "Creating .env file from template..."
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    fi
    
    echo "Current environment variables:"
    cat "$PROJECT_DIR/.env"
    echo
    
    echo "Actions:"
    echo "1) Edit environment file"
    echo "2) Reset to defaults"
    echo "3) Validate configuration"
    echo "4) Back to main menu"
    echo -n "Choice [4]: "
    read -r env_choice
    
    case "${env_choice:-4}" in
        1)
            ${EDITOR:-nano} "$PROJECT_DIR/.env"
            log_success "Environment file updated"
            ;;
        2)
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            log_success "Environment reset to defaults"
            ;;
        3)
            validate_environment
            ;;
        4)
            return
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

# Validate environment
validate_environment() {
    log_info "Validating environment configuration..."
    
    local errors=0
    
    # Check required variables
    local required_vars=("GF_SECURITY_ADMIN_PASSWORD")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$PROJECT_DIR/.env"; then
            log_error "Missing required variable: $var"
            ((errors++))
        fi
    done
    
    # Check port conflicts
    local ports
    ports=$(grep "_PORT=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | sort | uniq -d)
    if [ -n "$ports" ]; then
        log_error "Duplicate ports found: $ports"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Environment configuration is valid"
    else
        log_error "Environment validation failed with $errors errors"
    fi
}

# Configuration backup
backup_configs() {
    log_header "Backing Up Configurations"
    
    local backup_dir="config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup key configuration files
    cp "$PROJECT_DIR/.env" "$backup_dir/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/freqtrade/user_data" "$backup_dir/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/grafana/provisioning" "$backup_dir/" 2>/dev/null || true
    cp "$PROJECT_DIR/prometheus/prometheus.yml" "$backup_dir/" 2>/dev/null || true
    
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_success "Configuration backup created: ${backup_dir}.tar.gz"
}

# Validate all configurations
validate_configs() {
    log_header "Validating All Configurations"
    
    local errors=0
    
    # Validate environment
    validate_environment || ((errors++))
    
    # Validate JSON configurations
    for config in "$PROJECT_DIR"/freqtrade/user_data/config_*.json; do
        if [ -f "$config" ]; then
            if python3 -m json.tool "$config" >/dev/null 2>&1; then
                log_success "$(basename "$config") is valid JSON"
            else
                log_error "$(basename "$config") has invalid JSON syntax"
                ((errors++))
            fi
        fi
    done
    
    # Validate Docker Compose
    if docker-compose -f "$PROJECT_DIR/docker-compose.yml" config >/dev/null 2>&1; then
        log_success "docker-compose.yml is valid"
    else
        log_error "docker-compose.yml has syntax errors"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "All configurations are valid!"
    else
        log_error "Validation failed with $errors errors"
    fi
}

# Main function
main() {
    local command="${1:-interactive}"
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    case "$command" in
        "interactive")
            interactive_wizard
            ;;
        "env")
            manage_environment
            ;;
        "bot")
            setup_bots_interactive
            ;;
        "security")
            setup_security_interactive
            ;;
        "backup")
            backup_configs
            ;;
        "validate")
            validate_configs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use './scripts/config-manager.sh --help' for usage information"
            exit 1
            ;;
    esac
}

# Parse arguments and run main
main "$@"