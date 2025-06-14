# FoxESS CLI

A command-line tool to query FoxESS energy data from solar inverters. Available in both Swift and Python versions for cross-platform compatibility.

## Features

- Query real-time data from your FoxESS inverter
- Display power generation, grid consumption, battery status, and more
- View all available data points or filter to specific metrics

## Installation

### Swift Version (macOS/Linux with Swift)

```bash
# Direct compilation
swiftc -o foxESS foxESS.swift

# Or using Swift Package Manager
swift build
```

### Python Version (Linux/Cross-platform)

The Python version (`foxESS.py`) requires Python 3.6+ and uses only standard library modules - no additional dependencies needed.

```bash
# Make executable (optional)
chmod +x foxESS.py
```

## Usage

### Swift Version

```bash
# Basic usage
./foxESS YOUR_API_KEY

# Show specific variables
./foxESS YOUR_API_KEY --generationPower --pvPower --SoC

# Display all available variables
./foxESS YOUR_API_KEY --all

# Test API key validity
./foxESS YOUR_API_KEY --test

# Enable debug output
./foxESS YOUR_API_KEY --debug
```

### Python Version

```bash
# Basic usage
python3 foxESS.py YOUR_API_KEY

# Or if made executable
./foxESS.py YOUR_API_KEY

# Show specific variables
python3 foxESS.py YOUR_API_KEY --generationPower --pvPower --SoC

# Display all available variables
python3 foxESS.py YOUR_API_KEY --all

# Test API key validity
python3 foxESS.py YOUR_API_KEY --test

# Enable debug output
python3 foxESS.py YOUR_API_KEY --debug
```

## Available Variables

- `generationPower` - Solar generation power
- `pvPower` - Solar power
- `feedinPower` - Power feeding into the grid
- `gridConsumptionPower` - Power drawn from the grid
- `loadsPower` - Home consumption power
- `batChargePower` - Battery charging power
- `batDischargePower` - Battery discharging power
- `SoC` - Battery state of charge
- `batTemperature` - Battery temperature
- `ambientTemperation` - Ambient temperature
- `invTemperation` - Inverter temperature
- `meterPower2` - CT2 power reading

## API Key

You need a valid FoxESS API key to use this tool. Visit the FoxESS Cloud portal to obtain your API key.

## Acknowledgments

This project leveraged [Alistair Priest's Energy Stats](https://github.com/alpriest/EnergyStats) for understanding the method for accessing the FoxESS API.

## License

This project is open source and available under the MIT License.