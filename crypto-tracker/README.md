# Cryptocurrency Tracker Dashboard

This is an additional monitoring stack for tracking cryptocurrency prices and market data, running alongside the Freqtrade monitoring system.

## Features

🔥 **Real-time Cryptocurrency Data**
- Live price tracking from CoinMarketCap
- Market capitalization monitoring
- 24h volume and price change tracking
- Historical data visualization

📊 **Comprehensive Dashboards**
- Cryptocurrency price overview
- Market cap distribution
- Trading volume analysis
- Percentage change tracking

🚀 **Easy Deployment**
- Runs on separate ports (no conflicts)
- Independent Docker containers
- Separate Grafana instance with crypto-specific dashboards

## Quick Start

### 1. Deploy with Crypto Tracker Profile

```bash
# Deploy the crypto tracker alongside existing services
./deploy.sh --profile crypto-tracker install
```

### 2. Access the Crypto Dashboard

- **Crypto Grafana**: http://localhost:3001
  - Username: `admin`
  - Password: `crypto2024!`

- **Crypto Overview Dashboard**: http://localhost:3001/d/crypto-overview

### 3. Prometheus Endpoints

- **Crypto Prometheus**: http://localhost:9091
- **CoinMarketCap Metrics**: http://localhost:9101/metrics

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  CoinMarketCap  │───▶│ Crypto-         │───▶│ Crypto-Grafana  │
│  Exporter       │    │ Prometheus      │    │ (Port 3001)     │
│  (Port 9101)    │    │ (Port 9091)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Services

1. **crypto-prometheus** (Port 9091)
   - Dedicated Prometheus instance for crypto data
   - Scrapes CoinMarketCap exporter every minute
   - 30-day data retention

2. **coinmarketcap-exporter** (Port 9101)
   - Fetches cryptocurrency data from CoinMarketCap API
   - Exports Prometheus metrics
   - Covers major cryptocurrencies (BTC, ETH, ADA, etc.)

3. **crypto-grafana** (Port 3001)
   - Separate Grafana instance for crypto visualization
   - Pre-configured dashboards
   - Independent user management

## Available Metrics

The CoinMarketCap exporter provides these metrics:

```
# Price metrics
coinmarketcap_price_usd{symbol="BTC"}           # Current price in USD
coinmarketcap_price_btc{symbol="ETH"}           # Price in BTC

# Market metrics
coinmarketcap_market_cap_usd{symbol="BTC"}      # Market capitalization
coinmarketcap_24h_volume_usd{symbol="BTC"}      # 24h trading volume

# Change metrics
coinmarketcap_percent_change_1h{symbol="BTC"}   # 1h price change %
coinmarketcap_percent_change_24h{symbol="BTC"}  # 24h price change %
coinmarketcap_percent_change_7d{symbol="BTC"}   # 7d price change %

# Supply metrics
coinmarketcap_available_supply{symbol="BTC"}    # Circulating supply
coinmarketcap_total_supply{symbol="BTC"}        # Total supply
```

## Dashboard Panels

### Cryptocurrency Overview Dashboard

1. **Price Trends**
   - Real-time price charts for BTC, ETH, ADA
   - Time-series visualization
   - Customizable time ranges

2. **Current Prices**
   - Latest price values
   - Color-coded by cryptocurrency
   - Instant value display

3. **Market Cap Distribution**
   - Pie chart of market capitalization
   - Proportional representation
   - Major cryptocurrency comparison

4. **24h Price Change**
   - Percentage change over 24 hours
   - Positive/negative trend indicators
   - Time-series change visualization

5. **Trading Volume**
   - 24-hour trading volume
   - Volume comparison across cryptocurrencies
   - Market activity indicators

## Configuration

### Adding More Cryptocurrencies

Edit the dashboard queries to include additional symbols:

```json
{
  "expr": "coinmarketcap_price_usd{symbol=\"DOT\"}",
  "legendFormat": "Polkadot (DOT)"
}
```

### Customizing Scrape Intervals

Edit `crypto-tracker/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'coinmarketcap-exporter'
    scrape_interval: 120s  # Increase to 2 minutes
    static_configs:
      - targets: ['coinmarketcap-exporter:9101']
```

### Environment Variables

Add to `.env` file:

```env
# Crypto Tracker Configuration
CRYPTO_GRAFANA_PASSWORD=crypto2024!
CRYPTO_GRAFANA_PORT=3001
CRYPTO_PROMETHEUS_PORT=9091
COINMARKETCAP_EXPORTER_PORT=9101
```

## Management Commands

```bash
# Start crypto tracker services
./deploy.sh --profile crypto-tracker start

# View crypto services status
./deploy.sh status

# View crypto service logs
./deploy.sh logs crypto-grafana
./deploy.sh logs crypto-prometheus
./deploy.sh logs coinmarketcap-exporter

# Health check including crypto services
./deploy.sh --profile crypto-tracker health

# Stop all services (including crypto)
./deploy.sh stop
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if ports are in use
   lsof -i :3001  # Crypto Grafana
   lsof -i :9091  # Crypto Prometheus
   lsof -i :9101  # CoinMarketCap exporter
   ```

2. **No Crypto Data**
   ```bash
   # Check CoinMarketCap exporter
   curl http://localhost:9101/metrics
   
   # Check Prometheus targets
   curl http://localhost:9091/api/v1/targets
   ```

3. **Dashboard Not Loading**
   ```bash
   # Check Grafana logs
   ./deploy.sh logs crypto-grafana
   
   # Verify datasource connection
   curl http://localhost:3001/api/health
   ```

### Data Refresh Issues

If cryptocurrency data appears stale:

1. Check exporter connectivity:
   ```bash
   docker logs coinmarketcap-exporter
   ```

2. Restart the exporter:
   ```bash
   docker-compose restart coinmarketcap-exporter
   ```

3. Verify Prometheus scraping:
   ```bash
   # Check last scrape time
   curl "http://localhost:9091/api/v1/query?query=up{job=\"coinmarketcap-exporter\"}"
   ```

## Integration with Freqtrade Stack

The crypto tracker runs independently but complements the Freqtrade monitoring:

- **Separate Infrastructure**: No interference with trading bots
- **Cross-Reference Data**: Compare bot performance with market trends
- **Unified Monitoring**: Use both dashboards for comprehensive analysis

### Combined Analysis Workflow

1. **Monitor Trading Performance**: http://localhost:3000
2. **Check Market Conditions**: http://localhost:3001  
3. **Correlate Bot Success**: Compare bot profits with market trends
4. **Adjust Strategies**: Use market data to inform trading decisions

## API Limits and Considerations

### CoinMarketCap API

- **Free Tier**: 333 calls/day
- **Rate Limiting**: Respect API limits
- **Caching**: Data is cached in Prometheus
- **Scrape Frequency**: Default 60s (configurable)

### Optimization Tips

1. **Reduce Scrape Frequency** for production:
   ```yaml
   scrape_interval: 300s  # 5 minutes
   ```

2. **Monitor API Usage**:
   ```bash
   # Count API calls in logs
   docker logs coinmarketcap-exporter 2>&1 | grep -c "request"
   ```

3. **Use Longer Retention** for historical analysis:
   ```yaml
   # In crypto-prometheus config
   - '--storage.tsdb.retention.time=90d'
   ```

## Advanced Configuration

### Custom Cryptocurrency Selection

The exporter can be configured to track specific cryptocurrencies by setting environment variables:

```yaml
# In docker-compose.yml
coinmarketcap-exporter:
  environment:
    - COINS=bitcoin,ethereum,cardano,polkadot,chainlink
    - CURRENCY=USD
    - API_KEY=your-coinmarketcap-api-key  # For pro features
```

### Alerting Setup

Create alerts for significant price movements:

```yaml
# In crypto-tracker/prometheus/rules/alerts.yml
groups:
  - name: crypto-alerts
    rules:
      - alert: BitcoinPriceDrop
        expr: decrease(coinmarketcap_price_usd{symbol="BTC"}[1h]) > 1000
        labels:
          severity: warning
        annotations:
          summary: "Bitcoin price dropped significantly"
```

## Support and Updates

- **Documentation**: Check latest updates in project README
- **Issues**: Report problems via GitHub issues
- **Monitoring**: Use health checks to ensure system stability
- **Updates**: Pull latest images with `./deploy.sh update`

Happy crypto monitoring! 📈🚀