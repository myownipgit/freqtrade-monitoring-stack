# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a cryptocurrency trading bot monitoring system that combines Freqtrade, Docker, Grafana, Prometheus, and Supabase. The architecture follows a microservices pattern with containerized components for scalable monitoring of multiple trading bots.

### Core Components

- **Freqtrade Bots**: Multiple containerized trading bot instances
- **FTMetric Exporters**: Prometheus exporters that translate Freqtrade REST API to metrics
- **Prometheus**: Time-series metrics collection and storage
- **Grafana**: Visualization dashboards and alerting
- **Supabase**: Real-time PostgreSQL backend for configuration management

### Data Flow Architecture

1. Prometheus scrapes metrics from FTMetric exporters (15-30s intervals)
2. Grafana queries Prometheus using PromQL for dashboard visualization
3. Supabase provides real-time configuration updates via WebSocket subscriptions
4. Alert manager handles critical trading notifications

## Development Commands

### Docker Operations
```bash
# Start the complete monitoring stack
docker-compose up -d

# Start individual services
docker-compose up prometheus grafana
docker-compose up freqtrade1 ftmetric1

# View logs for specific services
docker-compose logs -f prometheus
docker-compose logs -f freqtrade1

# Rebuild after configuration changes
docker-compose down && docker-compose up -d --build
```

### Prometheus Management
```bash
# Reload Prometheus configuration
curl -X POST http://localhost:9090/-/reload

# Check configuration syntax
promtool check config prometheus/prometheus.yml

# Query metrics directly
curl "http://localhost:9090/api/v1/query?query=trading_bot_profit"
```

### Grafana Operations
```bash
# Access Grafana (default: admin/changeme)
open http://localhost:3000

# Import dashboard from file
curl -X POST http://admin:changeme@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana/dashboards/trading-overview.json
```

## Configuration Structure

### Key Configuration Files
- `docker-compose.yml`: Main service orchestration
- `prometheus/prometheus.yml`: Metrics collection configuration
- `grafana/provisioning/`: Dashboard and datasource provisioning
- `freqtrade/user_data/config.json`: Bot trading configuration
- `supabase/migrations/`: Database schema definitions

### Environment Variables
- `FTH_FREQTRADE__URL`: Freqtrade API endpoint
- `FTH_FREQTRADE__USERNAME/PASSWORD`: Bot authentication
- `SUPABASE_URL/KEY`: Database connection
- `GF_SECURITY_ADMIN_PASSWORD`: Grafana admin password

## Critical Metrics to Monitor

### Trading Performance
- `trading_bot_profit`: Cumulative profit/loss by bot
- `trading_bot_open_trades`: Active position count
- `trading_bot_win_rate`: Successful trade percentage
- `trading_bot_drawdown`: Maximum portfolio decline

### System Health
- `freqtrade_api_response_time`: Bot API latency
- `prometheus_scrape_duration`: Collection performance
- `container_memory_usage`: Resource utilization

## Network Architecture

The stack uses two Docker networks:
- `monitoring`: External access to Grafana/Prometheus
- `private`: Internal communication between bots and exporters

### Port Mapping
- Grafana: 3000
- Prometheus: 9090
- Freqtrade bots: 8081+ (localhost only)
- FTMetric exporters: 8091+

## Scaling Patterns

### Multi-Bot Setup
Each trading bot requires:
1. Freqtrade container with unique database
2. Dedicated FTMetric exporter
3. Separate Prometheus scrape job
4. Bot-specific Grafana variables

### Federation for Large Deployments
Use Prometheus federation when monitoring 10+ bots:
- Regional Prometheus instances scrape local bots
- Global Prometheus federates from regional instances
- Grafana queries global instance for unified dashboards

## Security Considerations

### API Authentication
- All metrics endpoints use HTTP Basic Auth
- Freqtrade API requires username/password
- Supabase uses service role JWT for privileged metrics

### Network Isolation
- Trading bots run on private Docker network
- Only exporters expose metrics to monitoring network
- External access limited to Grafana dashboard

## Alerting Strategy

### Critical Alerts (immediate notification)
- Bot down for >30 seconds
- Profit loss >5% in 1 hour
- API rate limit approaching (>80% of exchange limit)

### Warning Alerts (15-minute delay)
- Memory usage >85%
- Scrape failures >10% in 5 minutes
- Trade execution latency >30 seconds

## Troubleshooting Common Issues

### Bot Connection Problems
1. Check Freqtrade container logs: `docker-compose logs freqtrade1`
2. Verify API credentials in FTMetric environment
3. Test direct API access: `curl http://localhost:8081/api/v1/status`

### Missing Metrics
1. Confirm Prometheus targets: http://localhost:9090/targets
2. Check FTMetric exporter health: `curl http://localhost:8091/health`
3. Validate scrape configuration syntax

### Grafana Dashboard Issues
1. Verify Prometheus datasource connectivity
2. Check PromQL query syntax in query inspector
3. Confirm metric names match exporter output

## Data Retention

- Prometheus: 7 days local storage (configurable)
- Supabase: Unlimited historical data in PostgreSQL
- Grafana: Dashboard configurations backed up to Git
- Long-term metrics: Consider Prometheus remote write to cloud storage