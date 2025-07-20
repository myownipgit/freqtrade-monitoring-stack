# Contributing to Freqtrade Monitoring Stack

Thank you for your interest in contributing to the Freqtrade Monitoring Stack! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- Docker Desktop installed
- Git installed
- Basic knowledge of Docker, Prometheus, and Grafana
- Understanding of cryptocurrency trading concepts

### Development Environment Setup

1. **Fork the Repository**
   ```bash
   # Fork via GitHub web interface, then clone your fork
   git clone https://github.com/yourusername/freqtrade-monitoring-stack.git
   cd freqtrade-monitoring-stack
   ```

2. **Set Up Development Environment**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Start development stack
   docker-compose up -d
   
   # Verify everything is running
   docker-compose ps
   ```

3. **Access Development Services**
   - Grafana: http://localhost:3000 (admin/freqtrade2024!)
   - Prometheus: http://localhost:9090
   - Mock Metrics: http://localhost:8091/metrics

## 📋 How to Contribute

### Reporting Issues

When reporting issues, please include:

1. **Environment Information**
   - Operating system and version
   - Docker version
   - Browser version (for UI issues)

2. **Steps to Reproduce**
   - Clear, numbered steps
   - Expected vs actual behavior
   - Screenshots if applicable

3. **Logs and Error Messages**
   ```bash
   # Get service logs
   docker-compose logs [service-name]
   
   # Get all logs
   docker-compose logs > logs.txt
   ```

### Suggesting Enhancements

Enhancement suggestions should include:

- **Use case**: Why is this enhancement needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches you've thought about
- **Implementation notes**: Technical considerations

## 🛠 Development Guidelines

### Code Style

#### Python Code (mock-ftmetric.py)
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Include docstrings for functions and classes
- Maximum line length: 88 characters

#### Docker and YAML Files
- Use 2-space indentation for YAML
- Keep line length under 100 characters
- Comment complex configurations
- Use descriptive service names

#### JSON Configuration
- Use 2-space indentation
- Validate JSON syntax before committing
- Include comments where the format allows

### Git Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Keep commits focused and atomic
   - Write clear commit messages
   - Test changes locally

3. **Commit Guidelines**
   ```bash
   # Use conventional commit format
   git commit -m "feat: add new dashboard panel for trade history"
   git commit -m "fix: resolve Prometheus connection timeout"
   git commit -m "docs: update installation instructions"
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   # Create PR via GitHub web interface
   ```

### Testing

#### Local Testing
```bash
# Start the stack
docker-compose up -d

# Verify services are healthy
curl http://localhost:9090/api/v1/targets
curl http://localhost:8091/metrics

# Check dashboard loads
curl -I http://localhost:3000
```

#### Dashboard Testing
- Test all panels display data correctly
- Verify responsiveness on different screen sizes
- Ensure proper error handling for missing data
- Test auto-refresh functionality

### Documentation

#### README Updates
- Update feature lists for new functionality
- Add configuration examples
- Include troubleshooting steps for new components

#### Code Documentation
```python
def generate_mock_metrics(self) -> str:
    """
    Generate mock Freqtrade metrics in Prometheus format.
    
    Returns:
        str: Prometheus-formatted metrics string with randomized values
    """
```

## 📊 Specific Contribution Areas

### Dashboard Development

When creating new dashboards:

1. **Panel Design**
   - Use consistent color schemes
   - Include helpful tooltips
   - Ensure mobile responsiveness

2. **Metrics Selection**
   - Choose relevant and actionable metrics
   - Avoid information overload
   - Group related metrics logically

3. **Query Optimization**
   - Use efficient PromQL queries
   - Consider query performance impact
   - Add appropriate time ranges

### Mock Data Enhancement

For improving the mock metrics generator:

1. **Realistic Data Patterns**
   - Simulate realistic trading patterns
   - Include market volatility simulation
   - Add correlation between related metrics

2. **Additional Metrics**
   - Research real Freqtrade metrics
   - Add new metric types
   - Maintain backward compatibility

### Infrastructure Improvements

1. **Docker Optimization**
   - Reduce image sizes
   - Improve startup times
   - Add health checks

2. **Configuration Management**
   - Simplify environment setup
   - Add validation for required variables
   - Improve error messages

## 🔧 Component-Specific Guidelines

### Grafana Dashboards

```json
{
  "dashboard": {
    "title": "Clear, Descriptive Title",
    "tags": ["freqtrade", "relevant-tag"],
    "refresh": "30s",
    "panels": [
      {
        "title": "Descriptive Panel Title",
        "type": "appropriate-visualization-type",
        "targets": [
          {
            "expr": "efficient_promql_query",
            "legendFormat": "{{meaningful_label}}"
          }
        ]
      }
    ]
  }
}
```

### Prometheus Configuration

```yaml
# Add comments explaining complex rules
scrape_configs:
  - job_name: 'descriptive-job-name'
    static_configs:
      - targets: ['service:port']
    scrape_interval: 30s  # Explain why this interval
    metrics_path: '/metrics'
```

### Docker Compose Services

```yaml
services:
  service-name:
    image: specific-version-tag  # Pin versions for stability
    container_name: descriptive-name
    restart: unless-stopped     # Explain restart policy
    environment:
      - DOCUMENTED_ENV_VAR=value
    healthcheck:
      test: ["CMD", "health-check-command"]
      interval: 30s
    networks:
      - appropriate-network
```

## 🧪 Testing Checklist

Before submitting a PR:

- [ ] All services start successfully with `docker-compose up -d`
- [ ] Dashboards load without errors
- [ ] Metrics are being collected and displayed
- [ ] No broken links in documentation
- [ ] Environment variables are documented
- [ ] Changes are tested in both development and production modes

## 📝 Pull Request Process

1. **PR Description Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   - [ ] Tested locally
   - [ ] All dashboards working
   - [ ] Documentation updated

   ## Screenshots
   (If applicable)
   ```

2. **Review Process**
   - PRs require at least one review
   - Address all feedback before merging
   - Ensure CI checks pass
   - Squash commits when merging

## 🎯 Priority Areas

We especially welcome contributions in these areas:

1. **Additional Dashboard Panels**
   - Risk management metrics
   - Portfolio allocation views
   - Performance comparison charts

2. **Alert Rules**
   - More sophisticated alerting logic
   - Integration with external notification systems
   - Custom alert thresholds

3. **Documentation**
   - Video tutorials
   - Architecture diagrams
   - Troubleshooting guides

4. **Testing**
   - Automated testing framework
   - Integration tests
   - Performance benchmarks

## 🤝 Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code contributions and reviews

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers get started
- Credit others for their contributions

## 🏆 Recognition

Contributors will be recognized in:

- GitHub contributors list
- Release notes for significant contributions
- README acknowledgments section

## 📞 Getting Help

If you need help with contributing:

1. Check existing issues and discussions
2. Create a new discussion for questions
3. Join the community chat for real-time help
4. Review existing PRs for examples

Thank you for contributing to the Freqtrade Monitoring Stack! 🚀