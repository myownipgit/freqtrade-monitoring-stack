#!/bin/bash

# Freqtrade Monitoring Stack - Local Deployment Script
# This script automates the deployment of the complete monitoring stack
# with environment validation, service health checks, and configuration management.

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="freqtrade-monitoring-stack"
REQUIRED_DOCKER_VERSION="20.0.0"
REQUIRED_COMPOSE_VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
Freqtrade Monitoring Stack Deployment Script

USAGE:
    ./deploy.sh [COMMAND] [OPTIONS]

COMMANDS:
    install         Install and start the complete stack (default)
    start           Start existing services
    stop            Stop all services
    restart         Restart all services
    status          Show service status
    logs            Show service logs
    clean           Stop and remove all containers and volumes
    update          Pull latest images and restart
    config          Interactive configuration setup
    health          Run health checks on all services
    backup          Backup configuration and data
    restore         Restore from backup

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress non-essential output
    -f, --force     Force operation without confirmation
    -p, --profile   Use specific profile (default, multi-bot, crypto-tracker, production)
    --no-checks     Skip pre-deployment checks

EXAMPLES:
    ./deploy.sh                    # Install with default configuration
    ./deploy.sh start              # Start existing services
    ./deploy.sh --profile multi-bot install       # Install with multi-bot support
    ./deploy.sh --profile crypto-tracker install  # Install with crypto tracker
    ./deploy.sh logs grafana       # Show Grafana logs
    ./deploy.sh clean --force      # Clean without confirmation

For more information, see: https://github.com/myownipgit/freqtrade-monitoring-stack
EOF
}

# Version comparison function
version_compare() {
    printf '%s\n%s' "$1" "$2" | sort -V | head -n1
}

# Check if version meets minimum requirement
version_check() {
    local current="$1"
    local required="$2"
    local name="$3"
    
    if [ "$(version_compare "$current" "$required")" = "$required" ]; then
        log_success "$name version $current meets requirement (>= $required)"
        return 0
    else
        log_error "$name version $current does not meet requirement (>= $required)"
        return 1
    fi
}

# System requirements check
check_requirements() {
    log_header "Checking System Requirements"
    
    local checks_passed=0
    local total_checks=4
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        local docker_version
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if version_check "$docker_version" "$REQUIRED_DOCKER_VERSION" "Docker"; then
            ((checks_passed++))
        fi
    else
        log_error "Docker is not installed. Please install Docker Desktop."
        echo "  Download from: https://www.docker.com/products/docker-desktop"
    fi
    
    # Check if Docker Compose is available
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        local compose_version
        if command -v docker-compose >/dev/null 2>&1; then
            compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        else
            compose_version=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        fi
        if version_check "$compose_version" "$REQUIRED_COMPOSE_VERSION" "Docker Compose"; then
            ((checks_passed++))
        fi
    else
        log_error "Docker Compose is not available."
    fi
    
    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon is running"
        ((checks_passed++))
    else
        log_error "Docker daemon is not running. Please start Docker Desktop."
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space
    available_space=$(df -BG "$PWD" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -ge 10 ]; then
        log_success "Sufficient disk space available (${available_space}GB)"
        ((checks_passed++))
    else
        log_warning "Low disk space (${available_space}GB). Recommended: 20GB+"
    fi
    
    # Check available memory
    if command -v free >/dev/null 2>&1; then
        local available_memory_gb
        available_memory_gb=$(free -g | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_memory_gb" -ge 2 ]; then
            log_success "Sufficient memory available (${available_memory_gb}GB)"
        else
            log_warning "Low available memory (${available_memory_gb}GB). Recommended: 4GB+"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        local total_memory_gb
        total_memory_gb=$(sysctl hw.memsize | awk '{printf "%.0f", $2/1024/1024/1024}')
        log_info "Total system memory: ${total_memory_gb}GB"
    fi
    
    if [ $checks_passed -eq $total_checks ]; then
        log_success "All system requirements checks passed!"
        return 0
    else
        log_error "System requirements check failed ($checks_passed/$total_checks passed)"
        return 1
    fi
}

# Check if ports are available
check_ports() {
    log_header "Checking Port Availability"
    
    local ports=(3000 9090 8091)
    local port_names=("Grafana" "Prometheus" "FTMetric")
    
    # Add crypto tracker ports if using that profile
    if [ "$PROFILE" = "crypto-tracker" ]; then
        ports+=(3001 9091 9101)
        port_names+=("Crypto-Grafana" "Crypto-Prometheus" "CoinMarketCap")
    fi
    local conflicts=0
    
    for i in "${!ports[@]}"; do
        local port=${ports[$i]}
        local name=${port_names[$i]}
        
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_warning "Port $port ($name) is already in use"
            if [ "$VERBOSE" = true ]; then
                lsof -Pi :$port -sTCP:LISTEN
            fi
            ((conflicts++))
        else
            log_success "Port $port ($name) is available"
        fi
    done
    
    if [ $conflicts -gt 0 ]; then
        log_warning "$conflicts port conflicts detected"
        if [ "$FORCE" != true ]; then
            echo "Use --force to proceed anyway, or stop conflicting services first"
            return 1
        fi
    fi
    
    return 0
}

# Create environment file from template
setup_environment() {
    log_header "Setting Up Environment"
    
    if [ ! -f .env ] && [ -f .env.example ]; then
        log_info "Creating .env file from template..."
        cp .env.example .env
        log_success "Environment file created. You can customize it by editing .env"
    elif [ -f .env ]; then
        log_info "Environment file already exists"
    else
        log_warning "No environment template found, using defaults"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local health_url="$2"
    local max_wait="$3"
    local wait_time=0
    local interval=5
    
    log_info "Waiting for $service_name to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        if curl -s "$health_url" >/dev/null 2>&1; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo -n "."
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    log_error "$service_name failed to become ready within ${max_wait}s"
    return 1
}

# Health check for all services
health_check() {
    log_header "Running Health Checks"
    
    local services_healthy=0
    local total_services=0
    
    # Check Docker services
    log_info "Checking container status..."
    if ! docker-compose ps | grep -q "Up"; then
        log_error "No services are running. Run './deploy.sh start' first."
        return 1
    fi
    
    # Service health checks
    local health_checks=(
        "Prometheus:http://localhost:9090/-/healthy:30"
        "Grafana:http://localhost:3000/api/health:30"
        "FTMetric:http://localhost:8091/health:20"
    )
    
    # Add crypto tracker health checks if using that profile
    if [ "$PROFILE" = "crypto-tracker" ]; then
        health_checks+=(
            "Crypto-Prometheus:http://localhost:9091/-/healthy:30"
            "Crypto-Grafana:http://localhost:3001/api/health:30"
            "CoinMarketCap:http://localhost:9101/metrics:20"
        )
    fi
    
    for check in "${health_checks[@]}"; do
        IFS=':' read -r name url timeout <<< "$check"
        ((total_services++))
        
        if wait_for_service "$name" "$url" "$timeout"; then
            ((services_healthy++))
        fi
    done
    
    # Data freshness check
    log_info "Checking data freshness..."
    if curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q '"result":\['; then
        log_success "Metrics data is available"
        ((services_healthy++))
        ((total_services++))
    else
        log_error "No metrics data found"
        ((total_services++))
    fi
    
    # Summary
    echo
    if [ $services_healthy -eq $total_services ]; then
        log_success "All health checks passed! ($services_healthy/$total_services)"
        return 0
    else
        log_error "Health checks failed ($services_healthy/$total_services passed)"
        return 1
    fi
}

# Display access information
show_access_info() {
    log_header "Access Information"
    
    cat << EOF
${GREEN}🚀 Freqtrade Monitoring Stack is ready!${NC}

${CYAN}📊 Dashboards:${NC}
  • Grafana Dashboard:    http://localhost:3000
    Login: admin / freqtrade2024!
  
  • Trading Overview:     http://localhost:3000/d/freqtrade-trading-overview
  
  • Prometheus:          http://localhost:9090
EOF

    # Add crypto tracker info if using that profile
    if [ "$PROFILE" = "crypto-tracker" ]; then
        cat << EOF

${CYAN}💰 Crypto Tracker:${NC}
  • Crypto Grafana:       http://localhost:3001
    Login: admin / crypto2024!
  
  • Crypto Overview:      http://localhost:3001/d/crypto-overview
  
  • Crypto Prometheus:    http://localhost:9091
  • CoinMarketCap Data:   http://localhost:9101/metrics
EOF
    fi
    
    cat << EOF

${CYAN}🔧 Management:${NC}
  • View logs:            ./deploy.sh logs [service]
  • Check status:         ./deploy.sh status
  • Stop services:        ./deploy.sh stop
  • Health check:         ./deploy.sh health

${CYAN}📚 Documentation:${NC}
  • README:              ./README.md
  • Implementation:       ./implementation.md
  • Troubleshooting:      ./docs/troubleshooting.md
  • Architecture:         ./docs/architecture.md

${YELLOW}⚠️  Note: This is running in demo mode with mock data.${NC}
${YELLOW}   For live trading, configure real Freqtrade bots.${NC}

EOF
}

# Install function
install_stack() {
    log_header "Installing Freqtrade Monitoring Stack"
    
    # Run pre-deployment checks
    if [ "$SKIP_CHECKS" != true ]; then
        if ! check_requirements; then
            log_error "Requirements check failed. Use --no-checks to skip."
            exit 1
        fi
        
        if ! check_ports; then
            exit 1
        fi
    fi
    
    # Setup environment
    setup_environment
    
    # Pull images
    log_info "Pulling Docker images..."
    if [ "$PROFILE" != "default" ]; then
        docker-compose --profile "$PROFILE" pull
    else
        docker-compose pull
    fi
    
    # Start services
    log_info "Starting services..."
    if [ "$PROFILE" != "default" ]; then
        docker-compose --profile "$PROFILE" up -d
    else
        docker-compose up -d
    fi
    
    # Wait for services and run health checks
    if health_check; then
        show_access_info
    else
        log_error "Some services failed health checks. Check logs with: ./deploy.sh logs"
        exit 1
    fi
}

# Start services
start_services() {
    log_header "Starting Services"
    
    if [ "$PROFILE" != "default" ]; then
        docker-compose --profile "$PROFILE" up -d
    else
        docker-compose up -d
    fi
    
    health_check
}

# Stop services
stop_services() {
    log_header "Stopping Services"
    docker-compose down
    log_success "All services stopped"
}

# Show service status
show_status() {
    log_header "Service Status"
    docker-compose ps
    
    echo
    log_info "Resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -10
}

# Show logs
show_logs() {
    local service="$1"
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        docker-compose logs -f "$service"
    else
        log_info "Showing logs for all services..."
        docker-compose logs -f
    fi
}

# Clean up everything
clean_stack() {
    log_header "Cleaning Up Stack"
    
    if [ "$FORCE" != true ]; then
        echo -n "This will remove all containers, volumes, and data. Continue? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            return 0
        fi
    fi
    
    log_info "Stopping and removing containers..."
    docker-compose down -v
    
    log_info "Removing unused images..."
    docker image prune -f
    
    log_success "Cleanup completed"
}

# Update stack
update_stack() {
    log_header "Updating Stack"
    
    log_info "Pulling latest images..."
    docker-compose pull
    
    log_info "Restarting services..."
    docker-compose up -d
    
    health_check
}

# Backup function
backup_stack() {
    log_header "Creating Backup"
    
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_info "Backing up configuration files..."
    cp -r grafana/ prometheus/ freqtrade/ "$backup_dir/"
    
    if docker-compose ps | grep -q "Up"; then
        log_info "Creating Prometheus snapshot..."
        docker-compose exec prometheus promtool tsdb snapshot /prometheus >/dev/null 2>&1 || true
        
        log_info "Exporting Grafana dashboards..."
        mkdir -p "$backup_dir/grafana-export"
        # Export would require Grafana API calls here
    fi
    
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_success "Backup created: ${backup_dir}.tar.gz"
}

# Main script logic
main() {
    local command="${1:-install}"
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    case "$command" in
        "install")
            install_stack
            ;;
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-}"
            ;;
        "clean")
            clean_stack
            ;;
        "update")
            update_stack
            ;;
        "health")
            health_check
            ;;
        "backup")
            backup_stack
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use './deploy.sh --help' for usage information"
            exit 1
            ;;
    esac
}

# Parse command line arguments
VERBOSE=false
QUIET=false
FORCE=false
PROFILE="default"
SKIP_CHECKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        --no-checks)
            SKIP_CHECKS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            # Pass remaining arguments to main
            break
            ;;
    esac
done

# Set quiet mode
if [ "$QUIET" = true ]; then
    exec >/dev/null 2>&1
fi

# Run main function with remaining arguments
main "$@"