#!/bin/bash

# Freqtrade Monitoring Stack - Maintenance and Cleanup Script
# Handles routine maintenance, cleanup, updates, and system optimization

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
Maintenance Script for Freqtrade Monitoring Stack

USAGE:
    ./scripts/maintenance.sh [COMMAND] [OPTIONS]

COMMANDS:
    cleanup         Clean up old containers, images, and volumes
    update          Update all Docker images to latest versions
    optimize        Optimize system performance and disk usage
    backup          Create full system backup
    restore         Restore from backup
    logs            Manage and rotate log files
    metrics         Cleanup old metrics data
    health          Run comprehensive health check
    repair          Attempt to repair common issues
    monitor         Monitor system resources

OPTIONS:
    -h, --help      Show this help message
    -f, --force     Force operation without confirmation
    -v, --verbose   Enable verbose output
    -d, --days      Number of days for cleanup (default: 7)

EXAMPLES:
    ./scripts/maintenance.sh cleanup           # Clean up old data
    ./scripts/maintenance.sh update            # Update all images
    ./scripts/maintenance.sh backup            # Create system backup
    ./scripts/maintenance.sh health            # Health check
    ./scripts/maintenance.sh cleanup --days 3 # Clean data older than 3 days

EOF
}

# System cleanup
cleanup_system() {
    log_header "System Cleanup"
    
    local days="${DAYS:-7}"
    
    if [ "$FORCE" != true ]; then
        echo -n "This will clean up data older than $days days. Continue? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            return 0
        fi
    fi
    
    # Stop services temporarily
    log_info "Stopping services for cleanup..."
    docker-compose stop
    
    # Clean Docker system
    log_info "Cleaning Docker system..."
    docker system prune -f
    docker volume prune -f
    
    # Clean old images
    log_info "Removing old Docker images..."
    docker image prune -a -f --filter "until=${days}*24h"
    
    # Clean log files
    cleanup_logs "$days"
    
    # Clean Prometheus data (if configured)
    cleanup_prometheus_data "$days"
    
    # Restart services
    log_info "Restarting services..."
    docker-compose up -d
    
    log_success "System cleanup completed"
}

# Log file cleanup
cleanup_logs() {
    local days="$1"
    
    log_info "Cleaning log files older than $days days..."
    
    # Clean Freqtrade logs
    local log_dir="$PROJECT_DIR/freqtrade/user_data/logs"
    if [ -d "$log_dir" ]; then
        find "$log_dir" -name "*.log" -mtime "+$days" -delete 2>/dev/null || true
        find "$log_dir" -name "*.log.*" -mtime "+$days" -delete 2>/dev/null || true
    fi
    
    # Rotate current logs if they're too large
    for log_file in "$log_dir"/*.log; do
        if [ -f "$log_file" ] && [ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 104857600 ]; then  # 100MB
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            touch "$log_file"
            log_info "Rotated large log file: $(basename "$log_file")"
        fi
    done
    
    log_success "Log cleanup completed"
}

# Prometheus data cleanup
cleanup_prometheus_data() {
    local days="$1"
    
    log_info "Cleaning Prometheus data older than $days days..."
    
    # This would typically be handled by Prometheus retention settings
    # But we can clean up snapshots
    local snapshot_dir="$PROJECT_DIR/prometheus_data/snapshots"
    if [ -d "$snapshot_dir" ]; then
        find "$snapshot_dir" -type d -mtime "+$days" -exec rm -rf {} + 2>/dev/null || true
    fi
    
    log_success "Prometheus data cleanup completed"
}

# Update system
update_system() {
    log_header "Updating System"
    
    log_info "Pulling latest Docker images..."
    docker-compose pull
    
    log_info "Restarting services with new images..."
    docker-compose up -d
    
    # Wait for services to be ready
    sleep 10
    
    # Health check after update
    if health_check_basic; then
        log_success "Update completed successfully"
    else
        log_warning "Update completed but some services may have issues"
    fi
}

# Optimize system performance
optimize_system() {
    log_header "System Optimization"
    
    # Docker optimization
    log_info "Optimizing Docker..."
    docker system df
    
    # Compact Prometheus data
    if docker-compose ps | grep prometheus | grep -q Up; then
        log_info "Compacting Prometheus data..."
        docker-compose exec prometheus promtool tsdb snapshot /prometheus/snapshots/maintenance_$(date +%Y%m%d) /prometheus 2>/dev/null || true
    fi
    
    # Optimize Grafana database
    if docker-compose ps | grep grafana | grep -q Up; then
        log_info "Optimizing Grafana database..."
        # Grafana automatically optimizes its SQLite database
    fi
    
    # Check disk usage
    log_info "Disk usage analysis:"
    df -h "$PROJECT_DIR"
    
    # Memory usage
    log_info "Memory usage analysis:"
    if docker-compose ps | grep -q Up; then
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}"
    fi
    
    log_success "System optimization completed"
}

# Create backup
create_backup() {
    log_header "Creating System Backup"
    
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$PROJECT_DIR/$backup_dir"
    
    mkdir -p "$backup_path"
    
    # Backup configurations
    log_info "Backing up configurations..."
    cp -r "$PROJECT_DIR/grafana" "$backup_path/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/prometheus" "$backup_path/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/freqtrade" "$backup_path/" 2>/dev/null || true
    cp "$PROJECT_DIR/.env" "$backup_path/" 2>/dev/null || true
    cp "$PROJECT_DIR/docker-compose.yml" "$backup_path/" 2>/dev/null || true
    
    # Backup Prometheus data (snapshot)
    if docker-compose ps | grep prometheus | grep -q Up; then
        log_info "Creating Prometheus snapshot..."
        docker-compose exec prometheus promtool tsdb snapshot /prometheus 2>/dev/null || true
        # Copy snapshot if available
        local snapshot_container
        snapshot_container=$(docker-compose ps -q prometheus)
        if [ -n "$snapshot_container" ]; then
            docker cp "$snapshot_container:/prometheus/snapshots" "$backup_path/prometheus_snapshots" 2>/dev/null || true
        fi
    fi
    
    # Backup Grafana database
    if docker-compose ps | grep grafana | grep -q Up; then
        log_info "Backing up Grafana database..."
        local grafana_container
        grafana_container=$(docker-compose ps -q grafana)
        if [ -n "$grafana_container" ]; then
            docker cp "$grafana_container:/var/lib/grafana/grafana.db" "$backup_path/grafana.db" 2>/dev/null || true
        fi
    fi
    
    # Create compressed archive
    log_info "Creating compressed archive..."
    tar -czf "${backup_dir}.tar.gz" -C "$PROJECT_DIR" "$backup_dir"
    rm -rf "$backup_path"
    
    log_success "Backup created: ${backup_dir}.tar.gz"
    echo "Backup size: $(du -h "${backup_dir}.tar.gz" | cut -f1)"
}

# Basic health check
health_check_basic() {
    log_info "Running basic health check..."
    
    local healthy_services=0
    local total_services=0
    
    # Check if services are running
    while IFS= read -r line; do
        if echo "$line" | grep -q "Up"; then
            ((healthy_services++))
        fi
        ((total_services++))
    done < <(docker-compose ps | grep -v "Name\|---")
    
    if [ $total_services -eq 0 ]; then
        log_warning "No services are running"
        return 1
    fi
    
    # Check basic connectivity
    local endpoints=(
        "http://localhost:9090/-/healthy"
        "http://localhost:3000/api/health"
        "http://localhost:8091/health"
    )
    
    local healthy_endpoints=0
    for endpoint in "${endpoints[@]}"; do
        if curl -s "$endpoint" >/dev/null 2>&1; then
            ((healthy_endpoints++))
        fi
    done
    
    if [ $healthy_services -eq $total_services ] && [ $healthy_endpoints -eq 3 ]; then
        log_success "All services are healthy ($healthy_services/$total_services running, $healthy_endpoints/3 endpoints responsive)"
        return 0
    else
        log_warning "Health check issues detected ($healthy_services/$total_services running, $healthy_endpoints/3 endpoints responsive)"
        return 1
    fi
}

# Comprehensive health check
health_check_comprehensive() {
    log_header "Comprehensive Health Check"
    
    # Basic checks
    health_check_basic
    
    # Disk space check
    log_info "Checking disk space..."
    local disk_usage
    disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_warning "Disk usage is high: ${disk_usage}%"
    else
        log_success "Disk usage is acceptable: ${disk_usage}%"
    fi
    
    # Memory check
    log_info "Checking memory usage..."
    if command -v free >/dev/null 2>&1; then
        local memory_usage
        memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [ "$memory_usage" -gt 90 ]; then
            log_warning "Memory usage is high: ${memory_usage}%"
        else
            log_success "Memory usage is acceptable: ${memory_usage}%"
        fi
    fi
    
    # Check data freshness
    log_info "Checking data freshness..."
    if curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q '"result":\['; then
        log_success "Metrics data is fresh"
    else
        log_warning "Metrics data may be stale"
    fi
    
    # Check log files for errors
    log_info "Checking for recent errors..."
    local error_count=0
    if docker-compose logs --since=1h 2>&1 | grep -i "error\|exception\|failed" | wc -l | xargs -I {} [ {} -gt 0 ]; then
        error_count=$(docker-compose logs --since=1h 2>&1 | grep -i "error\|exception\|failed" | wc -l)
        log_warning "Found $error_count error messages in recent logs"
    else
        log_success "No recent errors found in logs"
    fi
}

# Repair common issues
repair_system() {
    log_header "System Repair"
    
    log_info "Attempting to repair common issues..."
    
    # Restart unhealthy services
    local unhealthy_services
    unhealthy_services=$(docker-compose ps | grep -v "Up\|Name\|---" | awk '{print $1}' || true)
    
    if [ -n "$unhealthy_services" ]; then
        log_info "Restarting unhealthy services: $unhealthy_services"
        for service in $unhealthy_services; do
            docker-compose restart "$service"
        done
    fi
    
    # Fix file permissions
    log_info "Checking file permissions..."
    chmod +x "$PROJECT_DIR/deploy.sh" 2>/dev/null || true
    chmod +x "$PROJECT_DIR/scripts"/*.sh 2>/dev/null || true
    
    # Recreate networks if needed
    if ! docker network ls | grep -q "grafana_superbase"; then
        log_info "Recreating Docker networks..."
        docker-compose down
        docker-compose up -d
    fi
    
    # Clear DNS cache (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo dscacheutil -flushcache 2>/dev/null || true
    fi
    
    log_success "Repair completed"
}

# Monitor system resources
monitor_system() {
    log_header "System Monitoring"
    
    echo "Real-time system monitoring (Press Ctrl+C to stop)"
    echo
    
    while true; do
        clear
        echo -e "${CYAN}=== Freqtrade Monitoring Stack - System Status ===${NC}"
        echo "Updated: $(date)"
        echo
        
        # Container status
        echo -e "${YELLOW}Container Status:${NC}"
        docker-compose ps
        echo
        
        # Resource usage
        echo -e "${YELLOW}Resource Usage:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        echo
        
        # Disk usage
        echo -e "${YELLOW}Disk Usage:${NC}"
        df -h "$PROJECT_DIR" | grep -v "Filesystem"
        echo
        
        # Recent metrics
        if curl -s "http://localhost:9090/api/v1/query?query=freqtrade_build_info" >/dev/null 2>&1; then
            echo -e "${YELLOW}Bot Status:${NC}"
            curl -s "http://localhost:9090/api/v1/query?query=freqtrade_build_info" | \
                jq -r '.data.result[] | "\(.metric.cluster): \(if .value[1] == "1" then "UP" else "DOWN" end)"' 2>/dev/null || echo "No data available"
        fi
        
        sleep 5
    done
}

# Main function
main() {
    local command="${1:-help}"
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    case "$command" in
        "cleanup")
            cleanup_system
            ;;
        "update")
            update_system
            ;;
        "optimize")
            optimize_system
            ;;
        "backup")
            create_backup
            ;;
        "logs")
            cleanup_logs "${DAYS:-7}"
            ;;
        "health")
            health_check_comprehensive
            ;;
        "repair")
            repair_system
            ;;
        "monitor")
            monitor_system
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use './scripts/maintenance.sh --help' for usage information"
            exit 1
            ;;
    esac
}

# Parse command line arguments
FORCE=false
VERBOSE=false
DAYS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
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

# Run main function with remaining arguments
main "$@"