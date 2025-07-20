#!/usr/bin/env python3
"""
Mock FTMetric server that generates sample Freqtrade metrics
for testing the monitoring dashboard without a real bot.
"""

import time
import random
from http.server import HTTPServer, BaseHTTPRequestHandler

class MockMetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            
            # Generate mock metrics
            metrics = self.generate_mock_metrics()
            self.wfile.write(metrics.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def generate_mock_metrics(self):
        timestamp = int(time.time() * 1000)
        
        # Mock bot status (randomly up/down)
        bot_status = random.choice([0, 1])
        
        # Mock trade data
        open_trades = random.randint(0, 5)
        balance = 1000 + random.uniform(-200, 300)
        locks = random.randint(0, 2)
        
        # Mock cache stats
        cache_total = random.randint(100, 500)
        cache_miss = random.randint(10, 50)
        
        # Mock log rate
        log_rate = random.randint(1, 10)
        
        metrics = f"""# HELP freqtrade_build_info Information relate to freqtrade, 0 meaning server is down
# TYPE freqtrade_build_info gauge
freqtrade_build_info{{cluster="demo",strategy="DefaultStrategy",version="2025.6"}} {bot_status}

# HELP freqtrade_open_trades Current number of open trades
# TYPE freqtrade_open_trades gauge
freqtrade_open_trades{{cluster="demo",strategy="DefaultStrategy",version="2025.6"}} {open_trades}

# HELP freqtrade_fiat_balance Current fiat balance in exchange
# TYPE freqtrade_fiat_balance gauge
freqtrade_fiat_balance{{cluster="demo",stake="USDT",strategy="DefaultStrategy",version="2025.6"}} {balance:.2f}

# HELP freqtrade_lock_count Current active lock data
# TYPE freqtrade_lock_count gauge
freqtrade_lock_count{{cluster="demo",strategy="DefaultStrategy",version="2025.6"}} {locks}

# HELP freqtrade_internal_cache_total How many time we call cache service for freqtrade data
# TYPE freqtrade_internal_cache_total counter
freqtrade_internal_cache_total{{cluster="demo"}} {cache_total}

# HELP freqtrade_internal_cache_miss How many time we need to call freqtrade
# TYPE freqtrade_internal_cache_miss counter
freqtrade_internal_cache_miss{{cluster="demo"}} {cache_miss}

# HELP freqtrade_log_level_count Count all valid log that ftmetric can pass
# TYPE freqtrade_log_level_count counter
freqtrade_log_level_count{{cluster="demo",level="info"}} {log_rate}

# HELP freqtrade_profit_abs_total Total absolute profit
# TYPE freqtrade_profit_abs_total gauge
freqtrade_profit_abs_total{{cluster="demo",strategy="DefaultStrategy"}} {random.uniform(-50, 150):.2f}

# HELP freqtrade_trades_total Total number of completed trades
# TYPE freqtrade_trades_total counter
freqtrade_trades_total{{cluster="demo",outcome="won"}} {random.randint(5, 25)}
freqtrade_trades_total{{cluster="demo",outcome="lost"}} {random.randint(2, 15)}
"""
        return metrics
    
    def log_message(self, format, *args):
        # Suppress log messages
        pass

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8090), MockMetricsHandler)
    print("Mock FTMetric server running on port 8090...")
    print("Metrics available at http://localhost:8090/metrics")
    server.serve_forever()