# FoxESS CLI

A Swift command-line tool to query FoxESS energy data from solar inverters.

## Features

- Query real-time data from your FoxESS inverter
- Display power generation, grid consumption, battery status, and more
- View all available data points or filter to specific metrics

## Installation

### Compile from source

```bash
# Direct compilation
swiftc -o foxESS foxESS.swift

# Or using Swift Package Manager
swift build
```

## Usage

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