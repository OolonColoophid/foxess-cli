import Foundation
import CryptoKit

// MARK: - Data Models

/// Represents a FoxESS device with its associated properties.
/// Core model for storing device information returned from the FoxESS Cloud API.
struct Device: Codable {
    /// Unique serial number for the device
    let deviceSN: String
    /// Name of the solar installation/station
    let stationName: String
    /// Unique ID for the station
    let stationID: String
    /// Battery information if available
    let battery: String?
    /// Serial number of the specific module
    let moduleSN: String
    /// Type of FoxESS device
    let deviceType: String
    /// Whether the system has photovoltaic panels
    let hasPV: Bool
    /// Whether the system has a battery installed
    let hasBattery: Bool
}

/// Generic wrapper for all FoxESS API responses.
/// All API responses are wrapped in this structure with an error code and result.
struct NetworkResponse<T: Decodable>: Decodable {
    /// Error number (0 means success)
    let errno: Int
    /// The actual data returned by the API
    let result: T?
}

/// Request parameters for fetching device list.
/// Controls pagination of results.
struct DeviceListRequest: Codable {
    /// The page number to retrieve
    var currentPage: Int
    /// Number of items per page
    var pageSize: Int
    
    init() {
        self.currentPage = 1
        self.pageSize = 10 // Default to 10 devices per page
    }
}

/// Response structure for paginated device list queries.
/// Contains pagination information and list of devices.
struct PagedDeviceListResponse: Codable {
    /// Number of items per page
    let pageSize: Int
    /// The current page number
    let currentPage: Int
    /// Total number of devices available
    let total: Int
    /// List of devices on this page
    let data: [DeviceSummaryResponse]
}

/// Summary information about a device.
/// Used in the device list response.
struct DeviceSummaryResponse: Codable {
    /// Unique serial number for the device
    let deviceSN: String
    /// Type of FoxESS device
    let deviceType: String
    /// ID of the station the device belongs to
    let stationID: String
    /// Name of the station
    let stationName: String
    /// Serial number of the specific module
    let moduleSN: String
    /// Whether the system has a battery installed
    let hasBattery: Bool
    /// Whether the system has photovoltaic panels
    let hasPV: Bool
}

/// Request parameters for querying device variables.
/// Used to fetch real-time data from a device.
struct OpenQueryRequest: Codable {
    /// Serial number of the device to query
    let deviceSN: String
    /// List of variable names to query
    let variables: [String]
}

/// Response structure for open queries.
/// Contains device information and requested data points.
struct OpenQueryResponse: Codable {
    /// Serial number of the device that was queried
    let deviceSN: String
    /// Array of data points returned from the device
    let datas: [OpenQueryData]
}

/// Individual data point from a device query.
/// Contains the variable name, value, human-readable name, and unit.
struct OpenQueryData: Codable {
    /// API variable name (e.g., "generationPower")
    let variable: String
    /// The actual value of the variable
    let value: QueryData
    /// Human-readable name of the variable
    let name: String
    /// Unit of measurement (e.g., "kW", "%")
    let unit: String?
    
    enum CodingKeys: String, CodingKey {
        case variable
        case value
        case name
        case unit
    }
}

/// Enum representing different types of data values.
/// Can be a double (numeric), string, or unknown type.
enum QueryData: Codable {
    /// Numeric value
    case double(Double)
    /// Text value
    case string(String)
    /// Unrecognized value type
    case unknown
    
    /// Custom decoder to handle different value types dynamically.
    /// Attempts to decode as double first, then string, falling back to unknown.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .unknown
        }
    }
    
    /// Custom encoder to properly encode the different value types.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .unknown:
            try container.encodeNil()
        }
    }
}

// MARK: - Command Line Argument Handling

/// Parses and stores command line arguments.
/// Handles API key, debug flags, and requested variables.
class CommandLineArgs {
    /// FoxESS API key for authentication
    var apiKey: String?
    /// Flag for enabling debug output
    var debugMode = false
    /// Flag for just testing the API key
    var testMode = false
    /// Flag for showing help text
    var showHelp = false
    /// List of variables to query
    var variables: [String] = []
    /// Flag to show all available variables
    var showAll = false
    
    /// Initializes by parsing command line arguments.
    /// Extracts API key, options, and variables.
    ///
    /// - Parameter args: Array of command line arguments
    init(args: [String]) {
        var i = 1  // Skip the program name
        while i < args.count {
            let arg = args[i]
            
            if arg == "--debug" {
                debugMode = true
            } else if arg == "--test" {
                testMode = true
            } else if arg == "--help" || arg == "-h" {
                showHelp = true
            } else if arg == "--all" {
                showAll = true
            } else if arg.hasPrefix("--") {
                // This is a variable the user wants to see (e.g., --generationPower)
                variables.append(arg.dropFirst(2).lowercased())
            } else if !arg.hasPrefix("-") {
                // Assume this is the API key
                apiKey = arg
            }
            
            i += 1
        }
    }
    
    /// Prints help information with usage instructions and available options.
    func printHelp() {
        print("foxESS - Command line tool to query FoxESS energy data")
        print("")
        print("Usage: foxESS <API_KEY> [options] [variables]")
        print("")
        print("Options:")
        print("  --help, -h          Display this help message")
        print("  --debug             Enable debug output")
        print("  --test              Test the API key only")
        print("  --all               Show all available variables")
        print("")
        print("Variables (use with --<variable>):")
        print("  generationPower     Solar generation power")
        print("  feedinPower         Power feeding into the grid")
        print("  gridConsumptionPower Power drawn from the grid")
        print("  loadsPower          Home consumption power")
        print("  batChargePower      Battery charging power")
        print("  batDischargePower   Battery discharging power")
        print("  SoC                 Battery state of charge")
        print("  batTemperature      Battery temperature")
        print("  ambientTemperation  Ambient temperature")
        print("  invTemperation      Inverter temperature")
        print("  meterPower2         CT2 power reading")
        print("")
        print("Example:")
        print("  foxESS YOUR_API_KEY --generationPower --SoC")
        print("  foxESS YOUR_API_KEY --all")
    }
}

// MARK: - Helper Extensions

/// Extends Array of OpenQueryData with convenient accessor methods.
/// Provides type-safe access to data values and metadata.
extension Array where Element == OpenQueryData {
    /// Gets a numeric value for a variable.
    ///
    /// - Parameter key: The variable name to look for
    /// - Returns: The numeric value if found and it's a number, nil otherwise
    func double(for key: String) -> Double? {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            if case .double(let value) = item.value {
                return value
            }
        }
        return nil
    }
    
    /// Gets a string value for a variable.
    ///
    /// - Parameter key: The variable name to look for
    /// - Returns: The string value if found and it's a string, nil otherwise
    func string(for key: String) -> String? {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            if case .string(let value) = item.value {
                return value
            }
        }
        return nil
    }
    
    /// Gets the unit of measurement for a variable.
    ///
    /// - Parameter key: The variable name to look for
    /// - Returns: The unit string or empty string if not found
    func getUnit(for key: String) -> String {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            var unit = item.unit ?? ""
            // Replace degrees-C symbol with just "C"
            unit = unit.replacingOccurrences(of: "°C", with: "C")
            return unit
        }
        return ""
    }
    
    /// Gets the human-readable name for a variable.
    ///
    /// - Parameter key: The variable name to look for
    /// - Returns: The human-readable name or the key itself if not found
    func getName(for key: String) -> String {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            return item.name
        }
        return key
    }
    
    /// Prints all available variables and their current values.
    /// Used with the --all flag.
    func dumpVariables() {
        print("Available variables:")
        for item in self {
            let valueStr: String
            switch item.value {
            case .double(let d): valueStr = "\(d)"
            case .string(let s): valueStr = s
            case .unknown: valueStr = "unknown"
            }
            print("  \(item.variable): \(valueStr) \(item.unit ?? "")")
        }
    }
}

// MARK: - FoxESS API Client

/// Main API client for communicating with FoxESS Cloud.
/// Handles authentication, signatures, and data fetching.
class FoxESSStatsAPI {
    /// FoxESS API key for authentication
    private let apiKey: String
    /// Authentication token (same as API key for FoxESS)
    private var token: String?
    /// Flag for enabling debug output
    private let debugMode: Bool
    
    /// Initializes the API client.
    ///
    /// - Parameters:
    ///   - apiKey: FoxESS API key for authentication
    ///   - debugMode: Whether to output debug information
    init(apiKey: String, debugMode: Bool = false) {
        self.apiKey = apiKey
        self.debugMode = debugMode
    }
    
    /// Adds required HTTP headers to a request.
    /// Includes authentication token, timestamps, and signature.
    ///
    /// - Parameter request: URLRequest to modify
    private func addHeaders(to request: inout URLRequest) {
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "token")
        }
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en", forHTTPHeaderField: "lang")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "timezone")
        request.setValue("FoxESSCmdLine/1.0", forHTTPHeaderField: "User-Agent")
        
        // Generate timestamp for signature
        let timestamp = Int64(round(Date().timeIntervalSince1970 * 1000))
        let timestampString = String(timestamp)
        request.setValue(timestampString, forHTTPHeaderField: "timestamp")
        
        let path = request.url?.path ?? ""
        
        if debugMode {
            print("DEBUG: Setting up headers for \(path)")
            print("DEBUG: Timestamp: \(timestampString)")
        }
        
        // Generate FoxESS signature using MD5
        // Format: path + token + timestamp, separated by \r\n
        let signatureParts = [path, token ?? "", timestampString]
        let signatureInput = signatureParts.joined(separator: "\\r\\n")
        let signature = signatureInput.md5()
        
        if debugMode {
            print("DEBUG: Signature: \(signature)")
        }
        
        request.setValue(signature, forHTTPHeaderField: "signature")
    }
    
    /// Generic method to fetch and decode API responses.
    /// Handles authentication headers, error checking, and JSON decoding.
    ///
    /// - Parameter request: The URLRequest to send
    /// - Returns: Decoded response of type T
    /// - Throws: Various errors that might occur during network operations or decoding
    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        if debugMode {
            print("DEBUG: Fetching \(request.url?.absoluteString ?? "unknown URL")")
        }
        
        var request = request
        request.timeoutInterval = 30  // Set timeout to 30 seconds
        addHeaders(to: &request)      // Add authentication headers
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = (response as? HTTPURLResponse) else {
                throw NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            let statusCode = httpResponse.statusCode
            if debugMode {
                print("DEBUG: Status code: \(statusCode)")
            }
            
            // Check for successful HTTP status code
            guard 200 ... 300 ~= statusCode else {
                if debugMode {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("DEBUG: Error response: \(responseString)")
                }
                throw NSError(domain: "InvalidStatusCode", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid status code \(statusCode)"])
            }
            
            // Decode the JSON response
            let networkResponse = try JSONDecoder().decode(NetworkResponse<T>.self, from: data)
            
            // Check for API-level errors
            if networkResponse.errno > 0 {
                throw NSError(domain: "FoxServerError", code: networkResponse.errno, userInfo: [NSLocalizedDescriptionKey: "Server error \(networkResponse.errno)"])
            }
            
            // Extract the actual result data
            if let result = networkResponse.result {
                return result
            }
            
            throw NSError(domain: "MissingResult", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing result in response"])
        } catch {
            if debugMode {
                print("DEBUG: Error fetching data: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Authenticate with the FoxESS API.
    /// For FoxESS, the API key is used directly as the token.
    func authenticate() async throws {
        if debugMode {
            print("DEBUG: Setting API key as token")
        }
        self.token = apiKey
    }
    
    /// Tests if the API key is valid by making a simple request.
    ///
    /// - Returns: True if authentication is successful, false otherwise
    func testAuthentication() async throws -> Bool {
        if debugMode {
            print("DEBUG: Testing authentication")
        }
        
        try await authenticate()
        
        var request = URLRequest(url: URL(string: "https://www.foxesscloud.com/op/v0/device/list")!)
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(DeviceListRequest())
        
        do {
            let _: PagedDeviceListResponse = try await fetch(request)
            return true
        } catch {
            if debugMode {
                print("DEBUG: Authentication test failed: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    /// Fetches the list of devices associated with this account.
    ///
    /// - Returns: Array of device summary information
    /// - Throws: Network or API errors
    func fetchDeviceList() async throws -> [DeviceSummaryResponse] {
        if debugMode {
            print("DEBUG: Fetching device list")
        }
        
        var request = URLRequest(url: URL(string: "https://www.foxesscloud.com/op/v0/device/list")!)
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(DeviceListRequest())
        
        let result: PagedDeviceListResponse = try await fetch(request)
        return result.data
    }
    
    /// Fetches real-time data from a specific device.
    /// Queries a standard set of variables for solar system status.
    ///
    /// - Parameter deviceSN: Serial number of the device to query
    /// - Returns: OpenQueryResponse containing requested data points
    /// - Throws: Network or API errors
    func fetchRealData(deviceSN: String) async throws -> OpenQueryResponse {
        let variables = [
            "generationPower", "feedinPower", "gridConsumptionPower", "loadsPower", 
            "batChargePower", "batDischargePower", "SoC", "batTemperature", 
            "ambientTemperation", "invTemperation", "meterPower2"
        ]
        
        if debugMode {
            print("DEBUG: Fetching real-time data for \(deviceSN)")
        }
        
        var request = URLRequest(url: URL(string: "https://www.foxesscloud.com/op/v0/device/real/query")!)
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(OpenQueryRequest(deviceSN: deviceSN, variables: variables))
        
        let result: [OpenQueryResponse] = try await fetch(request)
        if let deviceData = result.first(where: { $0.deviceSN == deviceSN }) {
            return deviceData
        } else {
            throw NSError(domain: "MissingData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data found for device"])
        }
    }
}

// MARK: - Utility Extensions

/// Extends String with an MD5 hash method.
/// Used for generating API request signatures.
extension String {
    /// Calculates MD5 hash of the string.
    ///
    /// - Returns: MD5 hash as a hexadecimal string
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Application Logic

/// Main application entry point.
/// Handles the overall flow of the program based on command line arguments.
///
/// - Parameter args: Parsed command line arguments
func run(args: CommandLineArgs) async {
    // Show help if requested
    guard !args.showHelp else {
        args.printHelp()
        return
    }
    
    // Ensure API key is provided
    guard let apiKey = args.apiKey else {
        print("Error: No API key provided")
        print("Use --help for usage information")
        return
    }
    
    // Create API client
    let api = FoxESSStatsAPI(apiKey: apiKey, debugMode: args.debugMode)
    
    do {
        // Just test the API key if requested
        if args.testMode {
            if try await api.testAuthentication() {
                print("API Key is valid")
            } else {
                print("API Key is invalid or there was a connection problem")
            }
            return
        }
        
        // Authenticate with the API
        try await api.authenticate()
        
        // Get the device list
        if args.debugMode {
            print("DEBUG: Getting device list")
        }
        let devices = try await api.fetchDeviceList()
        
        // Ensure at least one device exists
        guard let device = devices.first else {
            print("No devices found for this account")
            return
        }
        
        if args.debugMode {
            print("DEBUG: Found device: \(device.stationName) (\(device.deviceSN))")
        }
        
        // Get real-time data for the first device
        let data = try await api.fetchRealData(deviceSN: device.deviceSN)
        
        if args.variables.isEmpty && !args.showAll {
            // Default output - show primary power flow values
            let solar = data.datas.double(for: "generationPower") ?? 0
            let gridConsumption = data.datas.double(for: "gridConsumptionPower") ?? 0
            let feedIn = data.datas.double(for: "feedinPower") ?? 0
            let home = data.datas.double(for: "loadsPower") ?? 0
            let gridFlow = gridConsumption - feedIn
            
            let batteryCharge = data.datas.double(for: "batChargePower") ?? 0
            let batteryDischarge = data.datas.double(for: "batDischargePower") ?? 0
            let batteryFlow = batteryCharge - batteryDischarge
            let batterySoC = data.datas.double(for: "SoC") ?? 0
            
            // Helper function to format power values in kW
            let formatValue = { (value: Double) -> String in
                return String(format: "%.2f kW", value / 1000.0)
            }
            
            // Print a formatted summary of the system status
            print("Device: \(device.stationName)")
            print("Solar: \(formatValue(solar))")
            print("Home:  \(formatValue(home))")
            print("Grid:  \(formatValue(abs(gridFlow))) \(gridFlow > 0 ? "import" : "export")")
            
            if device.hasBattery {
                print("Battery: \(formatValue(abs(batteryFlow))) \(batteryFlow > 0 ? "charging" : "discharging")")
                print("Battery Level: \(String(format: "%.1f%%", batterySoC))")
            }
        } else if args.showAll {
            // Show all available variables when --all flag is used
            data.datas.dumpVariables()
        } else {
            // Show only the requested variables
            for variable in args.variables {
                if let value = data.datas.double(for: variable) {
                    let unit = data.datas.getUnit(for: variable)
                    let name = data.datas.getName(for: variable)
                    print("\(name): \(value) \(unit)")
                } else {
                    print("\(variable): Not available")
                }
            }
        }
        
    } catch {
        // Handle errors
        print("Error: \(error.localizedDescription)")
        if args.debugMode {
            print("Detailed error: \(error)")
        }
    }
}

// MARK: - Application Entry Point

// Parse command line arguments
let args = CommandLineArgs(args: CommandLine.arguments)
if args.debugMode {
    print("DEBUG: Starting application with arguments: \(CommandLine.arguments)")
}

// Run the main task asynchronously
let task = Task {
    await run(args: args)
    if args.debugMode {
        print("DEBUG: Task completed")
    }
    exit(0)
}

// Keep the application running until the task completes
// Set a 30-second timeout as a fallback
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
