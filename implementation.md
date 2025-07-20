# Implementation Guide: Freqtrade Monitoring Stack

This document provides step-by-step implementation instructions for the complete Freqtrade monitoring system using Docker, Grafana, Prometheus, and Supabase.

## Documentation References

For comprehensive information about each component, refer to the official documentation:

- **Grafana Documentation**: https://grafana.com/docs/
- **Prometheus Documentation**: https://prometheus.io/docs/introduction/overview/
- **Freqtrade Documentation**: https://www.freqtrade.io/en/stable/
- **Supabase Documentation**: https://supabase.com/docs
- **Slack API Documentation**: https://docs.slack.dev/

## Prerequisites

- Docker and Docker Compose installed
- Supabase account and project created
- Basic understanding of cryptocurrency trading and Freqtrade
- At least 4GB RAM and 20GB disk space available

## Phase 1: Project Structure Setup

### 1.1 Create Directory Structure

```bash
mkdir -p {prometheus,grafana/{provisioning/{datasources,dashboards},dashboards},freqtrade/{user_data/{config,strategies,logs,data}},supabase/{migrations,functions}}
```

### 1.2 Initialize Git Repository

```bash
git init
echo "*.log
*.sqlite
.env
user_data/logs/*
user_data/data/*
prometheus_data/
grafana_data/" > .gitignore
```

## Phase 2: Core Configuration Files

### 2.1 Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

volumes:
  prometheus_data: {}
  grafana_data: {}
  freqtrade_data: {}

networks:
  monitoring:
    driver: bridge
  trading:
    driver: bridge
    internal: true

services:
  # Prometheus for metrics collection
  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    networks:
      - monitoring
      - trading
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=7d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Grafana for visualization
  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    networks:
      - monitoring
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=freqtrade2024!
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - GF_FEATURE_TOGGLES_ENABLE=ngAlertInterface
    depends_on:
      prometheus:
        condition: service_healthy

  # First Freqtrade bot instance
  freqtrade-bot1:
    image: freqtradeorg/freqtrade:stable
    container_name: freqtrade-bot1
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8080"
    networks:
      - trading
    volumes:
      - ./freqtrade/user_data:/freqtrade/user_data
      - freqtrade_data:/freqtrade/data
    environment:
      - FREQTRADE_USER_DATA_DIR=/freqtrade/user_data
    command: >
      trade
      --logfile /freqtrade/user_data/logs/freqtrade-bot1.log
      --db-url sqlite:////freqtrade/user_data/tradesv3_bot1.sqlite
      --config /freqtrade/user_data/config_bot1.json
      --strategy DefaultStrategy

  # FTMetric exporter for bot1
  ftmetric-bot1:
    image: ghcr.io/kamontat/ftmetric:v4.5.3
    container_name: ftmetric-bot1
    restart: unless-stopped
    ports:
      - "8091:8090"
    networks:
      - monitoring
      - trading
    environment:
      - FTH_FREQTRADE__URL=http://freqtrade-bot1:8080
      - FTH_FREQTRADE__USERNAME=freqtrader
      - FTH_FREQTRADE__PASSWORD=SuperSecret1!
      - FTH_METRIC__PREFIX=freqtrade_bot1
    depends_on:
      - freqtrade-bot1
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:8090/health"]
      interval: 30s

  # Second Freqtrade bot instance (optional)
  freqtrade-bot2:
    image: freqtradeorg/freqtrade:stable
    container_name: freqtrade-bot2
    restart: unless-stopped
    ports:
      - "127.0.0.1:8082:8080"
    networks:
      - trading
    volumes:
      - ./freqtrade/user_data:/freqtrade/user_data
      - freqtrade_data:/freqtrade/data
    environment:
      - FREQTRADE_USER_DATA_DIR=/freqtrade/user_data
    command: >
      trade
      --logfile /freqtrade/user_data/logs/freqtrade-bot2.log
      --db-url sqlite:////freqtrade/user_data/tradesv3_bot2.sqlite
      --config /freqtrade/user_data/config_bot2.json
      --strategy ConservativeStrategy
    profiles:
      - multi-bot

  # FTMetric exporter for bot2
  ftmetric-bot2:
    image: ghcr.io/kamontat/ftmetric:v4.5.3
    container_name: ftmetric-bot2
    restart: unless-stopped
    ports:
      - "8092:8090"
    networks:
      - monitoring
      - trading
    environment:
      - FTH_FREQTRADE__URL=http://freqtrade-bot2:8080
      - FTH_FREQTRADE__USERNAME=freqtrader
      - FTH_FREQTRADE__PASSWORD=SuperSecret2!
      - FTH_METRIC__PREFIX=freqtrade_bot2
    depends_on:
      - freqtrade-bot2
    profiles:
      - multi-bot
```

### 2.2 Prometheus Configuration

Create `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'freqtrade-monitoring'

rule_files:
  - "rules/*.yml"

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Freqtrade Bot 1 Metrics
  - job_name: 'freqtrade-bot1'
    static_configs:
      - targets: ['ftmetric-bot1:8090']
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    basic_auth:
      username: 'metrics'
      password: 'secure123'

  # Freqtrade Bot 2 Metrics (if using multi-bot profile)
  - job_name: 'freqtrade-bot2'
    static_configs:
      - targets: ['ftmetric-bot2:8090']
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    basic_auth:
      username: 'metrics'
      password: 'secure123'

  # System metrics (optional)
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### 2.3 Grafana Datasource Provisioning

Create `grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "300s"
      httpMethod: POST
```

### 2.4 Grafana Dashboard Provisioning

Create `grafana/provisioning/dashboards/default.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

## Phase 3: Freqtrade Configuration

### 3.1 Basic Bot Configuration

Create `freqtrade/user_data/config_bot1.json`:

```json
{
    "max_open_trades": 5,
    "stake_currency": "USDT",
    "stake_amount": 100,
    "tradable_balance_ratio": 0.99,
    "fiat_display_currency": "USD",
    "dry_run": true,
    "dry_run_wallet": 1000,
    "cancel_open_orders_on_exit": false,
    
    "bid_strategy": {
        "price_side": "bid",
        "ask_last_balance": 0.0,
        "use_order_book": true,
        "order_book_top": 1,
        "check_depth_of_market": {
            "enabled": false,
            "bids_to_ask_delta": 1
        }
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
        "ccxt_config": {},
        "ccxt_async_config": {},
        "pair_whitelist": [
            "BTC/USDT",
            "ETH/USDT",
            "ADA/USDT",
            "DOT/USDT",
            "LINK/USDT"
        ],
        "pair_blacklist": []
    },
    
    "pairlists": [
        {
            "method": "StaticPairList"
        }
    ],
    
    "edge": {
        "enabled": false,
        "process_throttle_secs": 3600,
        "calculate_since_number_of_days": 7,
        "allowed_risk": 0.01,
        "stoploss_range_min": -0.01,
        "stoploss_range_max": -0.1,
        "stoploss_range_step": -0.01,
        "minimum_winrate": 0.60,
        "minimum_expectancy": 0.20,
        "min_trade_number": 10,
        "max_trade_duration_minute": 1440,
        "remove_pumps": false
    },
    
    "telegram": {
        "enabled": false,
        "token": "",
        "chat_id": ""
    },
    
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
    
    "bot_name": "freqtrade-bot1",
    "initial_state": "running",
    "force_entry_enable": false,
    "internals": {
        "process_throttle_secs": 5
    }
}
```

### 3.2 Simple Trading Strategy

Create `freqtrade/user_data/strategies/DefaultStrategy.py`:

```python
from freqtrade.strategy.interface import IStrategy
from typing import Dict, List
from functools import reduce
from pandas import DataFrame
import talib.abstract as ta
import freqtrade.vendor.qtpylib.indicators as qtpylib

class DefaultStrategy(IStrategy):
    INTERFACE_VERSION = 3
    
    # Strategy parameters
    minimal_roi = {
        "60": 0.01,
        "30": 0.02,
        "0": 0.04
    }
    
    stoploss = -0.10
    
    # Optimal timeframe for the strategy
    timeframe = '5m'
    
    # These values can be overridden in the "ask_strategy" section in the config.
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_exit_signal = False
    
    # Number of candles the strategy requires before producing valid signals
    startup_candle_count: int = 30
    
    # Optional order type mapping
    order_types = {
        'entry': 'limit',
        'exit': 'limit',
        'stoploss': 'market',
        'stoploss_on_exchange': False
    }
    
    def informative_pairs(self):
        return []
    
    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # RSI
        dataframe['rsi'] = ta.RSI(dataframe)
        
        # MACD
        macd = ta.MACD(dataframe)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # Bollinger Bands
        bollinger = qtpylib.bollinger_bands(qtpylib.typical_price(dataframe), window=20, stds=2)
        dataframe['bb_lowerband'] = bollinger['lower']
        dataframe['bb_middleband'] = bollinger['mid']
        dataframe['bb_upperband'] = bollinger['upper']
        
        # EMA
        dataframe['ema10'] = ta.EMA(dataframe, timeperiod=10)
        dataframe['ema50'] = ta.EMA(dataframe, timeperiod=50)
        
        return dataframe
    
    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (qtpylib.crossed_above(dataframe['rsi'], 30)) &
                (dataframe['macd'] > dataframe['macdsignal']) &
                (dataframe['close'] > dataframe['ema10']) &
                (dataframe['volume'] > 0)
            ),
            'enter_long'] = 1
        
        return dataframe
    
    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (qtpylib.crossed_above(dataframe['rsi'], 70)) |
                (dataframe['close'] > dataframe['bb_upperband']) |
                (qtpylib.crossed_below(dataframe['macd'], dataframe['macdsignal']))
            ),
            'exit_long'] = 1
        
        return dataframe
```

## Phase 4: Grafana Dashboard Setup

### 4.1 Trading Overview Dashboard

Create `grafana/dashboards/trading-overview.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "Freqtrade Trading Overview",
    "tags": ["freqtrade", "trading"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Total Profit/Loss",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(freqtrade_profit_abs_total)",
            "legendFormat": "Total P&L"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "currencyUSD",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": null},
                {"color": "yellow", "value": 0},
                {"color": "green", "value": 100}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Open Trades",
        "type": "stat",
        "targets": [
          {
            "expr": "freqtrade_open_trades",
            "legendFormat": "Open Trades"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Win Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "rate(freqtrade_trades_total{outcome=\"won\"}[1h]) / rate(freqtrade_trades_total[1h]) * 100",
            "legendFormat": "Win Rate %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 50},
                {"color": "green", "value": 70}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {
      "from": "now-24h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## Phase 5: Supabase Integration

### 5.1 Database Schema

Create `supabase/migrations/001_initial_schema.sql`:

```sql
-- Bot configurations table
CREATE TABLE bot_configurations (
    id SERIAL PRIMARY KEY,
    bot_name VARCHAR(50) NOT NULL UNIQUE,
    config JSONB NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trading metrics table
CREATE TABLE trading_metrics (
    id SERIAL PRIMARY KEY,
    bot_name VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(18,8),
    labels JSONB,
    INDEX idx_bot_timestamp (bot_name, timestamp),
    INDEX idx_metric_name (metric_name)
);

-- Alerts and notifications
CREATE TABLE alert_rules (
    id SERIAL PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    bot_name VARCHAR(50),
    condition_expression TEXT NOT NULL,
    threshold_value DECIMAL(18,8),
    severity VARCHAR(20) DEFAULT 'warning',
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Real-time subscriptions for configuration changes
CREATE OR REPLACE FUNCTION notify_config_change()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('config_change', json_build_object(
        'bot_name', NEW.bot_name,
        'config', NEW.config
    )::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER config_change_trigger
    AFTER INSERT OR UPDATE ON bot_configurations
    FOR EACH ROW EXECUTE FUNCTION notify_config_change();
```

### 5.2 Real-time Configuration Client

Create `supabase/functions/config-sync.js`:

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.SUPABASE_URL
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY

const supabase = createClient(supabaseUrl, supabaseKey)

// Subscribe to configuration changes
const channel = supabase
  .channel('bot-config-changes')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'bot_configurations'
    },
    (payload) => {
      console.log('Config change received:', payload)
      
      // Update bot configuration via API
      updateBotConfiguration(payload.new)
    }
  )
  .subscribe()

async function updateBotConfiguration(config) {
  const { bot_name, config: botConfig } = config
  
  try {
    // Send configuration update to Freqtrade API
    const response = await fetch(`http://freqtrade-${bot_name}:8080/api/v1/config`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.FREQTRADE_JWT_TOKEN}`
      },
      body: JSON.stringify(botConfig)
    })
    
    if (response.ok) {
      console.log(`Configuration updated for ${bot_name}`)
    } else {
      console.error(`Failed to update configuration for ${bot_name}`)
    }
  } catch (error) {
    console.error('Error updating bot configuration:', error)
  }
}

// Export metrics to Supabase
export async function exportMetricsToSupabase(metrics) {
  const { data, error } = await supabase
    .from('trading_metrics')
    .insert(metrics)
  
  if (error) {
    console.error('Error inserting metrics:', error)
  } else {
    console.log('Metrics exported successfully')
  }
}
```

## Phase 6: Deployment and Testing

### 6.1 Initial Deployment

```bash
# Start basic stack (single bot)
docker-compose up -d

# Check service health
docker-compose ps
docker-compose logs -f prometheus grafana

# Verify Prometheus targets
curl http://localhost:9090/api/v1/targets

# Access Grafana
open http://localhost:3000
# Login: admin / freqtrade2024!
```

### 6.2 Multi-Bot Deployment

```bash
# Start with multiple bots
docker-compose --profile multi-bot up -d

# Verify all services are running
docker-compose --profile multi-bot ps
```

### 6.3 Health Checks

```bash
# Test Freqtrade API
curl -u freqtrader:SuperSecret1! http://localhost:8081/api/v1/status

# Test metrics endpoint
curl http://localhost:8091/metrics

# Test Prometheus query
curl "http://localhost:9090/api/v1/query?query=up"
```

## Phase 7: Security and Production Hardening

### 7.1 Environment Variables

Create `.env` file:

```bash
# Grafana
GF_SECURITY_ADMIN_PASSWORD=your-secure-password-here

# Freqtrade API credentials
FREQTRADE_BOT1_USERNAME=freqtrader
FREQTRADE_BOT1_PASSWORD=super-secure-password-1
FREQTRADE_BOT2_USERNAME=freqtrader
FREQTRADE_BOT2_PASSWORD=super-secure-password-2

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Prometheus authentication
PROMETHEUS_AUTH_USERNAME=metrics
PROMETHEUS_AUTH_PASSWORD=secure-metrics-password

# Exchange API credentials (production only)
BINANCE_API_KEY=your-binance-api-key
BINANCE_SECRET_KEY=your-binance-secret-key
```

### 7.2 SSL/TLS Setup with Traefik

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.email=your-email@domain.com"
      - "--certificatesresolvers.myresolver.acme.storage=/acme.json"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/acme.json
    labels:
      - "traefik.http.routers.traefik.rule=Host(\`traefik.yourdomain.com\`)"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"

  grafana:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(\`grafana.yourdomain.com\`)"
      - "traefik.http.routers.grafana.tls.certresolver=myresolver"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  prometheus:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(\`prometheus.yourdomain.com\`)"
      - "traefik.http.routers.prometheus.tls.certresolver=myresolver"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
```

## Phase 8: Monitoring and Alerting

### 8.1 Prometheus Alert Rules

Create `prometheus/rules/freqtrade-alerts.yml`:

```yaml
groups:
  - name: freqtrade-alerts
    rules:
      # Bot health alerts
      - alert: FreqtradeBotDown
        expr: up{job=~"freqtrade-.*"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Freqtrade bot {{ $labels.job }} is down"
          description: "Bot {{ $labels.job }} has been down for more than 30 seconds"

      # Trading performance alerts
      - alert: HighLossAlert
        expr: increase(freqtrade_profit_abs_total[1h]) < -500
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High loss detected on {{ $labels.bot_name }}"
          description: "Bot {{ $labels.bot_name }} lost more than $500 in the last hour"

      # System resource alerts
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.container_label_com_docker_compose_service }}"
```

### 8.2 Basic Monitoring Commands

```bash
# Monitor logs in real-time
docker-compose logs -f freqtrade-bot1

# Check resource usage
docker stats

# Backup configuration
docker-compose exec prometheus promtool tsdb snapshot /prometheus
docker-compose exec grafana grafana-cli admin export-dashboard

# Restart services
docker-compose restart freqtrade-bot1 ftmetric-bot1
```

This implementation guide provides a complete, production-ready setup for monitoring Freqtrade bots with comprehensive metrics collection, visualization, and real-time configuration management.