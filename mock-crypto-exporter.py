#!/usr/bin/env python3
"""
Mock CoinMarketCap Exporter for demo purposes.
Generates realistic cryptocurrency metrics for Prometheus.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import random
import time
import math
from datetime import datetime, timedelta

class MockCryptoExporter(BaseHTTPRequestHandler):
    """
    Mock cryptocurrency metrics exporter that generates realistic data.
    """
    
    # Base prices for cryptocurrencies
    base_prices = {
        "BTC": 30000,
        "ETH": 1900,
        "ADA": 0.35,
        "DOT": 5.5,
        "LINK": 7.2,
        "SOL": 25.0,
        "MATIC": 0.85,
        "AVAX": 15.5
    }
    
    # Market cap multipliers (approximate supply)
    supply = {
        "BTC": 21000000,
        "ETH": 120000000,
        "ADA": 35000000000,
        "DOT": 1200000000,
        "LINK": 1000000000,
        "SOL": 400000000,
        "MATIC": 10000000000,
        "AVAX": 300000000
    }
    
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            
            metrics = self.generate_metrics()
            self.wfile.write(metrics.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Override to reduce log verbosity."""
        if '/metrics' not in args[0]:
            print(f"{self.address_string()} - [{self.log_date_time_string()}] {format % args}")
    
    def generate_metrics(self):
        """Generate realistic cryptocurrency metrics."""
        output = []
        output.append('# HELP coin_market coinmarketcap metric values')
        output.append('# TYPE coin_market gauge')
        
        # Current time for consistency
        current_time = time.time()
        
        for symbol, base_price in self.base_prices.items():
            # Generate realistic price variations
            # Use sine wave for general trend plus random noise
            trend = math.sin(current_time / 3600) * 0.05  # 5% max trend variation
            volatility = (random.random() - 0.5) * 0.02   # 2% random volatility
            
            # Calculate current price
            price_multiplier = 1 + trend + volatility
            current_price = base_price * price_multiplier
            
            # Calculate 24h change (more volatile)
            change_24h = (random.random() - 0.5) * 10  # -5% to +5%
            
            # Calculate 1h change (less volatile)
            change_1h = (random.random() - 0.5) * 2   # -1% to +1%
            
            # Calculate 7d change (trend-based)
            change_7d = trend * 100 + (random.random() - 0.5) * 5
            
            # Market cap
            market_cap = current_price * self.supply[symbol]
            
            # 24h volume (typically 5-20% of market cap)
            volume_24h = market_cap * (0.05 + random.random() * 0.15)
            
            # Rank (simplified - based on market cap order)
            rank = list(self.base_prices.keys()).index(symbol) + 1
            
            # Price in USD
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="price_usd"}} {current_price:.6f}')
            
            # Price in BTC
            btc_price = self.base_prices["BTC"] * (1 + trend + volatility)
            price_btc = current_price / btc_price if symbol != "BTC" else 1
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="price_btc"}} {price_btc:.8f}')
            
            # 24h volume
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="24h_volume_usd"}} {volume_24h:.2f}')
            
            # Market cap
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="market_cap_usd"}} {market_cap:.2f}')
            
            # Supply metrics
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="available_supply"}} {self.supply[symbol]:.0f}')
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="total_supply"}} {self.supply[symbol]:.0f}')
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="max_supply"}} {self.supply[symbol]:.0f}')
            
            # Percentage changes
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="percent_change_1h"}} {change_1h:.2f}')
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="percent_change_24h"}} {change_24h:.2f}')
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="percent_change_7d"}} {change_7d:.2f}')
            
            # Rank
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="rank"}} {rank}')
            
            # Last updated
            output.append(f'coin_market{{id="0",name="{symbol.lower()}",symbol="{symbol}",metric="last_updated"}} {int(current_time)}')
        
        # Add newline at the end
        output.append('')
        
        # Also add coinmarketcap_ prefixed metrics for compatibility
        output.append('# HELP coinmarketcap_price_usd Current price in USD')
        output.append('# TYPE coinmarketcap_price_usd gauge')
        for symbol, base_price in self.base_prices.items():
            trend = math.sin(current_time / 3600) * 0.05
            volatility = (random.random() - 0.5) * 0.02
            current_price = base_price * (1 + trend + volatility)
            output.append(f'coinmarketcap_price_usd{{symbol="{symbol}"}} {current_price:.6f}')
        
        output.append('')
        output.append('# HELP coinmarketcap_percent_change_24h 24 hour price change percentage')
        output.append('# TYPE coinmarketcap_percent_change_24h gauge')
        for symbol in self.base_prices.keys():
            change_24h = (random.random() - 0.5) * 10
            output.append(f'coinmarketcap_percent_change_24h{{symbol="{symbol}"}} {change_24h:.2f}')
        
        output.append('')
        output.append('# HELP coinmarketcap_market_cap_usd Market capitalization in USD')
        output.append('# TYPE coinmarketcap_market_cap_usd gauge')
        for symbol, base_price in self.base_prices.items():
            trend = math.sin(current_time / 3600) * 0.05
            volatility = (random.random() - 0.5) * 0.02
            current_price = base_price * (1 + trend + volatility)
            market_cap = current_price * self.supply[symbol]
            output.append(f'coinmarketcap_market_cap_usd{{symbol="{symbol}"}} {market_cap:.2f}')
        
        output.append('')
        output.append('# HELP coinmarketcap_24h_volume_usd 24 hour trading volume in USD')
        output.append('# TYPE coinmarketcap_24h_volume_usd gauge')
        for symbol, base_price in self.base_prices.items():
            trend = math.sin(current_time / 3600) * 0.05
            volatility = (random.random() - 0.5) * 0.02
            current_price = base_price * (1 + trend + volatility)
            market_cap = current_price * self.supply[symbol]
            volume_24h = market_cap * (0.05 + random.random() * 0.15)
            output.append(f'coinmarketcap_24h_volume_usd{{symbol="{symbol}"}} {volume_24h:.2f}')
        
        output.append('')
        
        return '\n'.join(output)

def main():
    """Start the mock cryptocurrency exporter."""
    port = 9101
    server = HTTPServer(('0.0.0.0', port), MockCryptoExporter)
    print(f"Mock Cryptocurrency Metrics Exporter running on port {port}...")
    print("Generating realistic crypto market data for demo purposes")
    print("Access metrics at: http://localhost:9101/metrics")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()

if __name__ == '__main__':
    main()