# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Freqtrade Monitoring Stack.

## Quick Diagnostics

### Health Check Commands

```bash
# Check all services
docker-compose ps

# Verify network connectivity
docker-compose exec prometheus wget -qO- http://ftmetric-bot1:8090/metrics

# Test Grafana API
curl -u admin:freqtrade2024! http://localhost:3000/api/health

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

## Common Issues

### 1. Dashboard Shows "No Data"

**Symptoms**: Grafana panels display "No data" or are empty

**Diagnosis**:
```bash
# Check if metrics are being collected
curl http://localhost:8091/metrics

# Verify Prometheus is scraping
curl "http://localhost:9090/api/v1/query?query=up"

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

**Common Causes**:

#### a) FTMetric Service Down
```bash
# Check service status
docker-compose logs ftmetric-bot1

# Restart the service
docker-compose restart ftmetric-bot1
```

#### b) Prometheus Configuration Error
```bash
# Validate Prometheus config
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Reload configuration
curl -X POST http://localhost:9090/-/reload
```

#### c) Network Connectivity Issues
```bash
# Test network connectivity
docker-compose exec prometheus ping ftmetric-bot1

# Check Docker networks
docker network ls
docker network inspect grafana_superbase_monitoring
```

**Solutions**:

1. **Restart Services**:
   ```bash
   docker-compose restart prometheus ftmetric-bot1 grafana
   ```

2. **Check Time Ranges**: Ensure dashboard time range includes recent data

3. **Verify Queries**: Test PromQL queries in Prometheus web UI

### 2. Container Startup Failures

**Symptoms**: Services fail to start or exit immediately

**Diagnosis**:
```bash
# Check container logs
docker-compose logs [service-name]

# View detailed container info
docker inspect [container-name]

# Check resource usage
docker stats
```

**Common Causes**:

#### a) Port Conflicts
```bash
# Check port usage
lsof -i :3000  # Grafana
lsof -i :9090  # Prometheus
lsof -i :8091  # FTMetric

# Kill conflicting processes
sudo kill -9 [PID]
```

#### b) Volume Mount Issues
```bash
# Check volume permissions
ls -la prometheus/
ls -la grafana/

# Fix permissions if needed
sudo chown -R $USER:$USER prometheus/ grafana/
```

#### c) Memory Issues
```bash
# Check available memory
free -h

# Increase Docker memory limit in Docker Desktop settings
```

**Solutions**:

1. **Stop Conflicting Services**:
   ```bash
   # Stop existing Grafana/Prometheus
   docker stop $(docker ps -q --filter "publish=3000")
   docker stop $(docker ps -q --filter "publish=9090")
   ```

2. **Clear Docker Cache**:
   ```bash
   docker system prune -f
   docker volume prune -f
   ```

### 3. Grafana Login Issues

**Symptoms**: Cannot access Grafana or authentication fails

**Diagnosis**:
```bash
# Check Grafana logs
docker-compose logs grafana

# Verify environment variables
docker-compose exec grafana env | grep GF_
```

**Solutions**:

1. **Reset Admin Password**:
   ```bash
   # Stop Grafana
   docker-compose stop grafana
   
   # Start with password reset
   docker-compose run --rm grafana grafana-cli admin reset-admin-password newpassword
   
   # Restart normally
   docker-compose up -d grafana
   ```

2. **Check Configuration**:
   ```bash
   # Verify admin user settings
   docker-compose exec grafana cat /etc/grafana/grafana.ini | grep admin
   ```

### 4. Freqtrade Bot Connection Errors

**Symptoms**: Bot shows as "Down" in dashboard, API errors

**Diagnosis**:
```bash
# Check bot logs
docker-compose logs freqtrade-bot1

# Test API directly
curl -u freqtrader:SuperSecret1! http://localhost:8081/api/v1/status

# Check bot configuration
docker-compose exec freqtrade-bot1 cat /freqtrade/user_data/config_webserver.json
```

**Common Issues**:

#### a) Exchange Connectivity (Real Bot)
```bash
# DNS resolution check
docker-compose exec freqtrade-bot1 nslookup api.binance.com

# Network connectivity test
docker-compose exec freqtrade-bot1 curl -I https://api.binance.com/api/v3/ping
```

**Solutions**:

1. **Use Mock Mode** (Recommended for testing):
   ```bash
   # Ensure mock FTMetric is running
   docker-compose logs ftmetric-bot1
   
   # Mock service should show:
   # "Mock FTMetric server running on port 8090..."
   ```

2. **Fix Real Bot Issues**:
   ```bash
   # Add proper exchange credentials
   # Edit freqtrade/user_data/config_bot1.json
   # Add valid API keys and secrets
   ```

### 5. Performance Issues

**Symptoms**: Slow dashboard loading, high CPU/memory usage

**Diagnosis**:
```bash
# Check resource usage
docker stats

# Monitor query performance
curl "http://localhost:9090/api/v1/query?query=prometheus_query_duration_seconds"

# Check Prometheus metrics
curl http://localhost:9090/metrics | grep prometheus_tsdb
```

**Solutions**:

1. **Optimize Queries**:
   - Reduce dashboard refresh frequency
   - Use recording rules for complex calculations
   - Limit time ranges for heavy queries

2. **Scale Resources**:
   ```bash
   # Increase Docker memory limits
   # Add resource limits to docker-compose.yml
   
   deploy:
     resources:
       limits:
         memory: 1G
         cpus: '0.5'
   ```

3. **Cleanup Old Data**:
   ```bash
   # Reduce Prometheus retention
   # Edit prometheus.yml:
   # --storage.tsdb.retention.time=3d
   ```

### 6. Data Inconsistencies

**Symptoms**: Metrics don't match expected values, missing data points

**Diagnosis**:
```bash
# Check metric consistency
curl "http://localhost:9090/api/v1/query?query=freqtrade_build_info"

# Verify scrape intervals
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, lastScrape: .lastScrape}'

# Check for gaps in data
curl "http://localhost:9090/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-01T23:59:59Z&step=300s"
```

**Solutions**:

1. **Synchronize Time**:
   ```bash
   # Check system time
   date
   
   # Sync containers with host time
   docker-compose down
   docker-compose up -d
   ```

2. **Verify Scrape Configuration**:
   ```yaml
   # prometheus/prometheus.yml
   scrape_configs:
     - job_name: 'freqtrade-bot1'
       scrape_interval: 30s  # Consistent intervals
       scrape_timeout: 10s   # Adequate timeout
   ```

## Network Issues

### Docker Network Problems

```bash
# List networks
docker network ls

# Inspect network configuration
docker network inspect grafana_superbase_monitoring
docker network inspect grafana_superbase_trading

# Test connectivity between containers
docker-compose exec prometheus ping ftmetric-bot1
docker-compose exec grafana ping prometheus
```

**Solutions**:

1. **Recreate Networks**:
   ```bash
   docker-compose down
   docker network prune
   docker-compose up -d
   ```

2. **Check DNS Resolution**:
   ```bash
   # Test service discovery
   docker-compose exec prometheus nslookup ftmetric-bot1
   ```

### Firewall Issues

```bash
# Check if ports are accessible
telnet localhost 3000
telnet localhost 9090

# Check firewall rules (Linux)
sudo iptables -L

# Check firewall rules (macOS)
sudo pfctl -sr
```

## Configuration Issues

### Environment Variables

```bash
# Check environment variables
docker-compose config

# Verify variable substitution
docker-compose exec grafana env | grep GF_
docker-compose exec prometheus env
```

### File Permissions

```bash
# Check file ownership
ls -la prometheus/
ls -la grafana/

# Fix permissions
chmod 644 prometheus/prometheus.yml
chmod 644 grafana/provisioning/datasources/prometheus.yml
```

### Configuration Validation

```bash
# Validate Prometheus config
docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml

# Validate docker-compose
docker-compose config
```

## Recovery Procedures

### Complete Stack Reset

```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Clean up images
docker-compose pull

# Restart fresh
docker-compose up -d
```

### Selective Service Recovery

```bash
# Restart specific service
docker-compose restart [service-name]

# Rebuild specific service
docker-compose up -d --force-recreate [service-name]

# View service logs in real-time
docker-compose logs -f [service-name]
```

### Data Recovery

```bash
# Backup current state
docker-compose exec prometheus promtool tsdb snapshot /prometheus

# Export Grafana dashboards
curl -u admin:freqtrade2024! http://localhost:3000/api/search | \
  jq '.[] | select(.type=="dash-db") | .uid' | \
  xargs -I {} curl -u admin:freqtrade2024! \
  "http://localhost:3000/api/dashboards/uid/{}" > backup-dashboards.json
```

## Monitoring Health

### Automated Health Checks

Create a health check script:

```bash
#!/bin/bash
# health-check.sh

echo "=== Service Health Check ==="

# Check if services are running
services=("prometheus" "grafana" "ftmetric-bot1")
for service in "${services[@]}"; do
    if docker-compose ps | grep -q "$service.*Up"; then
        echo "✅ $service is running"
    else
        echo "❌ $service is down"
    fi
done

# Check HTTP endpoints
endpoints=(
    "http://localhost:9090/-/healthy:Prometheus"
    "http://localhost:3000/api/health:Grafana"
    "http://localhost:8091/health:FTMetric"
)

for endpoint in "${endpoints[@]}"; do
    url=${endpoint%:*}
    name=${endpoint#*:}
    if curl -s "$url" > /dev/null; then
        echo "✅ $name endpoint is healthy"
    else
        echo "❌ $name endpoint is unreachable"
    fi
done

# Check data freshness
echo "=== Data Freshness ==="
last_scrape=$(curl -s "http://localhost:9090/api/v1/query?query=up" | \
              jq -r '.data.result[0].value[0]')
current_time=$(date +%s)
if [ $((current_time - last_scrape)) -lt 60 ]; then
    echo "✅ Data is fresh (last scrape: $(date -d @$last_scrape))"
else
    echo "❌ Data is stale (last scrape: $(date -d @$last_scrape))"
fi
```

### Alerting on Issues

Set up alerts for common problems:

```yaml
# prometheus/rules/health.yml
groups:
  - name: health
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.container_label_com_docker_compose_service }}"
```

## Getting Help

### Log Collection

```bash
# Collect all logs
docker-compose logs > debug-logs.txt

# Collect specific service logs
docker-compose logs prometheus > prometheus-logs.txt
docker-compose logs grafana > grafana-logs.txt

# Get system information
docker version > system-info.txt
docker-compose version >> system-info.txt
uname -a >> system-info.txt
```

### Community Support

When reporting issues, include:

1. **Environment Information**: OS, Docker version, hardware specs
2. **Configuration Files**: Relevant config files (remove sensitive data)
3. **Log Files**: Recent logs from affected services
4. **Steps to Reproduce**: Detailed reproduction steps
5. **Expected vs Actual**: What you expected vs what happened

### Emergency Contacts

- **GitHub Issues**: Report bugs and get community help
- **Discord**: Real-time community support
- **Documentation**: Check latest docs for updates
- **Stack Overflow**: Technical questions with tags: `freqtrade`, `prometheus`, `grafana`