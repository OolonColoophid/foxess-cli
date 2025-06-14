#!/usr/bin/env python3
"""
FoxESS CLI - Command line tool to query FoxESS energy data
Python version for Linux compatibility when Swift networking is not available
"""

import json
import hashlib
import time
import sys
import argparse
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any, Union


class Device:
    """Represents a FoxESS device with its associated properties."""
    
    def __init__(self, data: Dict[str, Any]):
        self.device_sn = data.get('deviceSN', '')
        self.station_name = data.get('stationName', '')
        self.station_id = data.get('stationID', '')
        self.battery = data.get('battery')
        self.module_sn = data.get('moduleSN', '')
        self.device_type = data.get('deviceType', '')
        self.has_pv = data.get('hasPV', False)
        self.has_battery = data.get('hasBattery', False)


class OpenQueryData:
    """Individual data point from a device query."""
    
    def __init__(self, data: Dict[str, Any]):
        self.variable = data.get('variable', '')
        self.value = data.get('value')
        self.name = data.get('name', '')
        self.unit = data.get('unit', '')


class FoxESSStatsAPI:
    """Main API client for communicating with FoxESS Cloud."""
    
    def __init__(self, api_key: str, debug_mode: bool = False):
        self.api_key = api_key
        self.token = None
        self.debug_mode = debug_mode
        self.base_url = "https://www.foxesscloud.com"
        
    def _generate_signature(self, path: str, timestamp: str) -> str:
        """Generate FoxESS signature using MD5."""
        signature_parts = [path, self.token or "", timestamp]
        signature_input = "\\r\\n".join(signature_parts)
        return hashlib.md5(signature_input.encode()).hexdigest()
    
    def _get_headers(self, path: str) -> Dict[str, str]:
        """Generate headers for API requests."""
        timestamp = str(int(time.time() * 1000))
        signature = self._generate_signature(path, timestamp)
        
        headers = {
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "en-US;q=0.9,en;q=0.8",
            "Content-Type": "application/json",
            "lang": "en",
            "timezone": "UTC",
            "User-Agent": "FoxESSCmdLine/1.0",
            "timestamp": timestamp,
            "signature": signature
        }
        
        if self.token:
            headers["token"] = self.token
            
        if self.debug_mode:
            print(f"DEBUG: Setting up headers for {path}")
            print(f"DEBUG: Timestamp: {timestamp}")
            print(f"DEBUG: Signature: {signature}")
            
        return headers
    
    def _fetch(self, url: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generic method to fetch and decode API responses."""
        path = url.replace(self.base_url, "")
        headers = self._get_headers(path)
        
        if self.debug_mode:
            print(f"DEBUG: Fetching {url}")
            
        json_data = json.dumps(data).encode('utf-8')
        request = urllib.request.Request(url, data=json_data, headers=headers, method='POST')
        
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if self.debug_mode:
                    print(f"DEBUG: Status code: {response.status}")
                    
                response_data = json.loads(response.read().decode('utf-8'))
                
                if response_data.get('errno', 0) > 0:
                    raise Exception(f"Server error {response_data['errno']}")
                    
                return response_data.get('result', {})
                
        except urllib.error.HTTPError as e:
            error_text = e.read().decode('utf-8') if e.fp else str(e)
            if self.debug_mode:
                print(f"DEBUG: Error response: {error_text}")
            raise Exception(f"HTTP {e.code}: {error_text}")
        except urllib.error.URLError as e:
            raise Exception(f"URL Error: {e.reason}")
    
    def authenticate(self):
        """Authenticate with the FoxESS API."""
        if self.debug_mode:
            print("DEBUG: Setting API key as token")
        self.token = self.api_key
    
    def test_authentication(self) -> bool:
        """Test if the API key is valid."""
        if self.debug_mode:
            print("DEBUG: Testing authentication")
            
        self.authenticate()
        
        try:
            self._fetch(f"{self.base_url}/op/v0/device/list", {
                "currentPage": 1,
                "pageSize": 10
            })
            return True
        except Exception as e:
            if self.debug_mode:
                print(f"DEBUG: Authentication test failed: {e}")
            return False
    
    def fetch_device_list(self) -> List[Device]:
        """Fetch the list of devices associated with this account."""
        if self.debug_mode:
            print("DEBUG: Fetching device list")
            
        result = self._fetch(f"{self.base_url}/op/v0/device/list", {
            "currentPage": 1,
            "pageSize": 10
        })
        
        return [Device(device_data) for device_data in result.get('data', [])]
    
    def fetch_real_data(self, device_sn: str) -> List[OpenQueryData]:
        """Fetch real-time data from a specific device."""
        variables = [
            "generationPower", "feedinPower", "gridConsumptionPower", "loadsPower",
            "batChargePower", "batDischargePower", "SoC", "batTemperature",
            "ambientTemperation", "invTemperation", "meterPower2", "pvPower"
        ]
        
        if self.debug_mode:
            print(f"DEBUG: Fetching real-time data for {device_sn}")
            
        result = self._fetch(f"{self.base_url}/op/v0/device/real/query", {
            "deviceSN": device_sn,
            "variables": variables
        })
        
        # Find the device data in the response
        for device_data in result:
            if device_data.get('deviceSN') == device_sn:
                return [OpenQueryData(data) for data in device_data.get('datas', [])]
                
        raise Exception("No data found for device")


def get_data_value(data_list: List[OpenQueryData], key: str) -> Optional[Union[float, str]]:
    """Get a value for a variable from the data list."""
    for item in data_list:
        if item.variable.lower() == key.lower():
            if isinstance(item.value, (int, float)):
                return float(item.value)
            return item.value
    return None


def get_data_unit(data_list: List[OpenQueryData], key: str) -> str:
    """Get the unit for a variable from the data list."""
    for item in data_list:
        if item.variable.lower() == key.lower():
            unit = item.unit or ""
            # Replace degrees-C symbol with just "C"
            unit = unit.replace("°C", "C")
            return unit
    return ""


def get_data_name(data_list: List[OpenQueryData], key: str) -> str:
    """Get the human-readable name for a variable from the data list."""
    for item in data_list:
        if item.variable.lower() == key.lower():
            return item.name
    return key


def dump_all_variables(data_list: List[OpenQueryData], decimal_places: int = 2):
    """Print all available variables and their current values."""
    print("Available variables:")
    for item in data_list:
        if isinstance(item.value, (int, float)):
            # Apply the zero threshold for solar energy values
            adjusted_value = 0.0 if (item.variable in ["generationPower", "pvPower"] and item.value <= 0.02) else item.value
            value_str = f"{adjusted_value:.{decimal_places}f}".rstrip('0').rstrip('.')
        else:
            value_str = str(item.value) if item.value is not None else "unknown"
        
        print(f"  {item.variable}: {value_str} {item.unit or ''}")


def format_power_value(value: float, decimal_places: int = 2) -> str:
    """Format power value in kW with specified decimal places."""
    formatted = f"{value:.{decimal_places}f}".rstrip('0').rstrip('.')
    return f"{formatted} kW"


def main():
    parser = argparse.ArgumentParser(description="foxESS - Command line tool to query FoxESS energy data")
    parser.add_argument("api_key", help="FoxESS API key for authentication")
    parser.add_argument("--debug", action="store_true", help="Enable debug output")
    parser.add_argument("--test", action="store_true", help="Test the API key only")
    parser.add_argument("--all", action="store_true", help="Show all available variables")
    parser.add_argument("--decimals", type=int, default=2, help="Set decimal places for numeric output (default: 2)")
    
    # Parse known args to handle variable flags
    args, remaining = parser.parse_known_args()
    
    # Extract variable flags (--variableName)
    variables = []
    for arg in remaining:
        if arg.startswith("--") and len(arg) > 2:
            variables.append(arg[2:])
    
    if not args.api_key:
        print("Error: No API key provided")
        parser.print_help()
        return
    
    # Create API client
    api = FoxESSStatsAPI(args.api_key, args.debug)
    
    try:
        # Just test the API key if requested
        if args.test:
            if api.test_authentication():
                print("API Key is valid")
            else:
                print("API Key is invalid or there was a connection problem")
            return
        
        # Authenticate with the API
        api.authenticate()
        
        # Get the device list
        if args.debug:
            print("DEBUG: Getting device list")
        devices = api.fetch_device_list()
        
        # Ensure at least one device exists
        if not devices:
            print("No devices found for this account")
            return
        
        device = devices[0]
        if args.debug:
            print(f"DEBUG: Found device: {device.station_name} ({device.device_sn})")
        
        # Get real-time data for the first device
        data = api.fetch_real_data(device.device_sn)
        
        if not variables and not args.all:
            # Default output - show primary power flow values
            solar = get_data_value(data, "generationPower") or 0
            pv_power = get_data_value(data, "pvPower") or 0
            grid_consumption = get_data_value(data, "gridConsumptionPower") or 0
            feed_in = get_data_value(data, "feedinPower") or 0
            home = get_data_value(data, "loadsPower") or 0
            grid_flow = grid_consumption - feed_in
            
            battery_charge = get_data_value(data, "batChargePower") or 0
            battery_discharge = get_data_value(data, "batDischargePower") or 0
            battery_flow = battery_charge - battery_discharge
            battery_soc = get_data_value(data, "SoC") or 0
            
            # Treat solar energy values of 0.02 or less as 0
            if solar <= 0.02:
                solar = 0
            if pv_power <= 0.02:
                pv_power = 0
            
            if args.debug:
                print("DEBUG: Raw values:")
                print(f"DEBUG: Solar: {solar} W")
                print(f"DEBUG: PVPower: {pv_power} W")
                print(f"DEBUG: GridConsumption: {grid_consumption} W")
                print(f"DEBUG: FeedIn: {feed_in} W")
                print(f"DEBUG: Home: {home} W")
                print(f"DEBUG: BatteryCharge: {battery_charge} W")
                print(f"DEBUG: BatteryDischarge: {battery_discharge} W")
            
            # Print a formatted summary of the system status
            print(f"Device: {device.station_name}")
            print(f"generationPower: {format_power_value(solar, args.decimals)}")
            print(f"pvPower: {format_power_value(pv_power, args.decimals)}")
            print(f"loadsPower: {format_power_value(home, args.decimals)}")
            print(f"Grid: {format_power_value(abs(grid_flow), args.decimals)} {'import' if grid_flow > 0 else 'export'}")
            
            if device.has_battery:
                print(f"Battery: {format_power_value(abs(battery_flow), args.decimals)} {'charging' if battery_flow > 0 else 'discharging'}")
                soc_formatted = f"{battery_soc:.{args.decimals}f}".rstrip('0').rstrip('.')
                print(f"SoC: {soc_formatted}%")
                
        elif args.all:
            # Show all available variables when --all flag is used
            dump_all_variables(data, args.decimals)
        else:
            # Show only the requested variables
            for variable in variables:
                value = get_data_value(data, variable)
                if isinstance(value, (int, float)):
                    # Apply the zero threshold for solar energy values
                    adjusted_value = 0.0 if (variable in ["generationPower", "pvPower"] and value <= 0.02) else value
                    unit = get_data_unit(data, variable)
                    value_str = f"{adjusted_value:.{args.decimals}f}".rstrip('0').rstrip('.')
                    print(f"{variable}: {value_str} {unit}")
                else:
                    print(f"{variable}: Not available")
        
    except Exception as e:
        print(f"Error: {e}")
        if args.debug:
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()