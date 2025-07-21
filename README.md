# Freqtrade Monitoring Stack

A comprehensive monitoring solution for cryptocurrency trading bots using **Grafana**, **Prometheus**, **Freqtrade**, and **Supabase**. This stack provides real-time visualization, metrics collection, and historical analysis for professional cryptocurrency trading operations.

![Architecture Overview](docs/images/architecture-overview.png)

## 🚀 Features

- **Real-time Bot Monitoring**: Live dashboards showing trading performance, open trades, and system health
- **Multi-Bot Support**: Monitor multiple Freqtrade instances from a single dashboard
- **Historical Analysis**: Long-term data retention and trend analysis
- **Alert Management**: Configurable alerts for critical trading events
- **Docker Containerized**: Easy deployment with Docker Compose
- **Mock Mode**: Demo mode with simulated trading data for testing

## 📊 Dashboard Metrics

### Trading Performance
- **Bot Status**: Real-time up/down status monitoring
- **Open Trades**: Current number of active positions
- **Current Balance**: Available trading capital
- **Profit/Loss Tracking**: Cumulative and period-based P&L
- **Win Rate**: Success percentage of completed trades

### System Health
- **API Response Times**: Bot performance metrics
- **Cache Statistics**: Efficiency of data collection
- **Log Activity**: System activity and error tracking
- **Lock Count**: Trading restriction monitoring

## 🛠 Quick Start

### Prerequisites

- Docker Desktop installed and running
- At least 4GB RAM and 20GB disk space
- Basic understanding of Docker and cryptocurrency trading

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/freqtrade-monitoring-stack.git
cd freqtrade-monitoring-stack
```

### 2. Choose Your Deployment

#### Option A: Freqtrade Monitoring Only (Default)
```bash
# Start trading bot monitoring
./deploy.sh install
```

#### Option B: Multi-Bot Trading Setup
```bash
# Start with multiple bot support
./deploy.sh --profile multi-bot install
```

#### Option C: Cryptocurrency Market Tracking
```bash
# Start with crypto market dashboard
./deploy.sh --profile crypto-tracker install
```

#### Option D: Everything Combined
```bash
# Start all services (trading + crypto tracking)
./deploy.sh --profile multi-bot install
./deploy.sh --profile crypto-tracker start
```

# Check service status
docker-compose ps
```

### 3. Access Dashboards

#### Freqtrade Monitoring
- **Grafana Dashboard**: http://localhost:3000
  - Username: `admin`
  - Password: `freqtrade2024!`
- **Prometheus Metrics**: http://localhost:9090
- **Trading Dashboard**: http://localhost:3000/d/freqtrade-trading-overview

#### Cryptocurrency Market Tracking (if crypto-tracker profile is used)
- **Crypto Grafana**: http://localhost:3001
  - Username: `admin`
  - Password: `crypto2024!`
- **Crypto Dashboard**: http://localhost:3001/d/crypto-overview
- **Crypto Prometheus**: http://localhost:9091
- **CoinMarketCap Data**: http://localhost:9101/metrics

## 📁 Project Structure

```
freqtrade-monitoring-stack/
├── docker-compose.yml          # Main orchestration file
├── deploy.sh                   # Main deployment script
├── scripts/                    # Management scripts
│   ├── config-manager.sh       # Configuration wizard
│   └── maintenance.sh          # System maintenance
├── prometheus/
│   └── prometheus.yml          # Metrics collection config
├── grafana/
│   ├── provisioning/           # Auto-provisioning configs
│   │   ├── datasources/        # Prometheus datasource
│   │   └── dashboards/         # Dashboard provisioning
│   └── dashboards/             # Dashboard JSON files
├── crypto-tracker/             # Cryptocurrency monitoring stack
│   ├── prometheus/             # Crypto-specific Prometheus config
│   ├── grafana/
│   │   ├── provisioning/       # Crypto dashboard provisioning
│   │   └── dashboards/         # Crypto-specific dashboards
│   └── README.md               # Crypto tracker documentation
├── freqtrade/
│   └── user_data/              # Bot configurations and strategies
│       ├── config_*.json       # Trading bot configs
│       └── strategies/         # Trading strategies
├── supabase/                   # Database migrations and functions
├── mock-ftmetric.py           # Demo metrics generator
├── CLAUDE.md                  # AI assistant guidance
└── implementation.md          # Detailed setup guide
```

## 🐳 Services

### Freqtrade Monitoring Stack (Default)
| Service | Port | Description |
|---------|------|-------------|
| **Grafana** | 3000 | Trading visualization dashboards |
| **Prometheus** | 9090 | Trading metrics collection and storage |
| **Freqtrade Bot** | 8081 | Trading bot API (localhost only) |
| **FTMetric Exporter** | 8091 | Metrics exporter for Prometheus |

### Cryptocurrency Tracker Stack (Optional)
| Service | Port | Description |
|---------|------|-------------|
| **Crypto Grafana** | 3001 | Cryptocurrency market dashboards |
| **Crypto Prometheus** | 9091 | Crypto metrics collection and storage |
| **CoinMarketCap Exporter** | 9101 | Real-time crypto price data exporter |

## 🔧 Configuration

### Environment Variables

Create a `.env` file for production deployments:

```bash
# Grafana
GF_SECURITY_ADMIN_PASSWORD=your-secure-password

# Freqtrade API
FREQTRADE_USERNAME=your-username
FREQTRADE_PASSWORD=your-password

# Supabase (optional)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Exchange API (for live trading)
EXCHANGE_API_KEY=your-exchange-api-key
EXCHANGE_SECRET_KEY=your-exchange-secret-key
```

### Multi-Bot Setup

To monitor multiple bots, use the multi-bot profile:

```bash
# Start with multiple bot instances
docker-compose --profile multi-bot up -d
```

## 📈 Dashboard Usage

### Freqtrade Trading Overview

The main dashboard provides:

1. **Status Panels**: Quick overview of bot health and performance
2. **Time Series Graphs**: Historical trends and patterns
3. **Real-time Updates**: Auto-refresh every 30 seconds
4. **Interactive Filters**: Filter by bot, timeframe, and strategy

### Custom Dashboards

Add your own dashboards by:

1. Creating JSON files in `grafana/dashboards/`
2. Restarting Grafana: `docker-compose restart grafana`
3. Dashboards auto-load via provisioning

## 🔔 Alerting

### Built-in Alert Rules

- **Bot Down**: Triggered when bot is unreachable for >30 seconds
- **High Loss**: Activated when losses exceed 5% in 1 hour
- **System Resources**: Memory/CPU usage above 85%
- **API Failures**: High error rates from exchange APIs

### Custom Alerts

Configure additional alerts in `prometheus/rules/` directory.

## 🧪 Demo Mode

The stack includes a mock metrics generator for testing:

- Simulates realistic trading data
- Randomized but consistent metrics
- No external dependencies required
- Perfect for demonstrations and development

## 🔐 Security

### Production Considerations

- Change default passwords in `.env` file
- Use HTTPS with reverse proxy (Traefik/Nginx)
- Implement API authentication
- Restrict network access to internal services
- Regular security updates for all components

### Network Architecture

- **Monitoring Network**: External access to dashboards
- **Trading Network**: Internal bot communication
- **Isolated Services**: Bots run on private network

## 📖 Documentation

### Detailed Guides

- [**Implementation Guide**](implementation.md) - Step-by-step setup instructions
- [**Architecture Overview**](docs/architecture.md) - System design and components
- [**API Reference**](docs/api-reference.md) - Prometheus metrics and endpoints
- [**Troubleshooting**](docs/troubleshooting.md) - Common issues and solutions

### External Documentation

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Freqtrade Documentation](https://www.freqtrade.io/en/stable/)
- [Supabase Documentation](https://supabase.com/docs)

## 🚧 Development

### Local Development

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose logs -f

# Rebuild after changes
docker-compose up -d --build
```

### Adding New Metrics

1. Extend `mock-ftmetric.py` for development
2. Add new panels to dashboard JSON
3. Update Prometheus scrape configs
4. Test with mock data before production

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/freqtrade-monitoring-stack.git
cd freqtrade-monitoring-stack

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
pytest tests/

# Start development stack
docker-compose -f docker-compose.dev.yml up -d
```

## 📊 Performance

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 20GB | 50GB |
| **Network** | 10 Mbps | 100 Mbps |

### Scaling Guidelines

- **Single Bot**: Default configuration
- **2-5 Bots**: Add more Prometheus targets
- **5+ Bots**: Consider Prometheus federation
- **High Volume**: Use VictoriaMetrics for better performance

## 🐛 Troubleshooting

### Common Issues

#### Dashboard Shows "No Data"
```bash
# Check service status
docker-compose ps

# Verify metrics endpoint
curl http://localhost:8091/metrics

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

#### Bot Connection Errors
```bash
# Check bot logs
docker-compose logs freqtrade-bot1

# Verify API credentials
curl -u username:password http://localhost:8081/api/v1/status
```

#### Performance Issues
```bash
# Monitor resource usage
docker stats

# Check Prometheus query performance
curl http://localhost:9090/api/v1/query?query=up
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Freqtrade Community](https://github.com/freqtrade/freqtrade) for the excellent trading bot framework
- [Grafana Labs](https://grafana.com/) for the visualization platform
- [Prometheus](https://prometheus.io/) for metrics collection
- [Supabase](https://supabase.com/) for the real-time database

## 📞 Support

- **Documentation**: Check the [docs](docs/) directory
- **Issues**: Report bugs via [GitHub Issues](https://github.com/yourusername/freqtrade-monitoring-stack/issues)
- **Discussions**: Join [GitHub Discussions](https://github.com/yourusername/freqtrade-monitoring-stack/discussions)
- **Community**: [Discord Server](https://discord.gg/freqtrade) for real-time help

---

**⚠️ Disclaimer**: This monitoring stack is for educational and development purposes. Always test thoroughly before using with real trading capital. Cryptocurrency trading involves substantial risk of loss.

---

Made with ❤️ by the Freqtrade Monitoring Community