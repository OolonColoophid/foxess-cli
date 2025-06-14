import Foundation

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
    
    /// Number of decimal places to show in numeric output
    var decimalPlaces = 2
    
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
            } else if arg.hasPrefix("--decimals=") {
                if let decimalValue = Int(arg.dropFirst("--decimals=".count)) {
                    decimalPlaces = decimalValue
                }
            } else if arg.hasPrefix("--") {
                // This is a variable the user wants to see (e.g., --generationPower)
                variables.append(String(arg.dropFirst(2)))
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
        print("  --decimals=N        Set decimal places for numeric output (default: 2)")
        print("")
        print("Variables (use with --<variable>):")
        print("  generationPower     Solar generation power")
        print("  pvPower             Solar power")
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
        print("  foxESS YOUR_API_KEY --decimals=3 --pvPower")
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
    func dumpVariables(decimalPlaces: Int = 2) {
        print("Available variables:")
        for item in self {
            let valueStr: String
            switch item.value {
            case .double(let d):
                // Apply the zero threshold for solar energy values
                let adjustedValue = (item.variable == "generationPower" || item.variable == "pvPower") && d <= 0.02 ? 0.0 : d
                let rawFormatted = String(format: "%.\(decimalPlaces)f", adjustedValue)
                valueStr = rawFormatted.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
            case .string(let s): 
                valueStr = s
            case .unknown: 
                valueStr = "unknown"
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
            "ambientTemperation", "invTemperation", "meterPower2", "pvPower"
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

/// Pure Swift MD5 implementation for Linux compatibility.
/// Used for generating API request signatures.
extension String {
    /// Calculates MD5 hash of the string using pure Swift implementation.
    ///
    /// - Returns: MD5 hash as a hexadecimal string
    func md5() -> String {
        let data = Data(self.utf8)
        return data.md5()
    }
}

extension Data {
    func md5() -> String {
        let h: [UInt32] = [
            0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476
        ]
        
        var message = Array(self)
        let originalLength = message.count
        
        message.append(0x80)
        
        while message.count % 64 != 56 {
            message.append(0)
        }
        
        let lengthInBits = UInt64(originalLength * 8)
        for i in 0..<8 {
            message.append(UInt8((lengthInBits >> (i * 8)) & 0xFF))
        }
        
        var hash = h
        
        for chunk in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 {
                let start = chunk + i * 4
                w[i] = UInt32(message[start]) |
                       (UInt32(message[start + 1]) << 8) |
                       (UInt32(message[start + 2]) << 16) |
                       (UInt32(message[start + 3]) << 24)
            }
            
            var a = hash[0]
            var b = hash[1]
            var c = hash[2]
            var d = hash[3]
            
            for i in 0..<64 {
                var f: UInt32
                var g: Int
                
                if i < 16 {
                    f = (b & c) | (~b & d)
                    g = i
                } else if i < 32 {
                    f = (d & b) | (~d & c)
                    g = (5 * i + 1) % 16
                } else if i < 48 {
                    f = b ^ c ^ d
                    g = (3 * i + 5) % 16
                } else {
                    f = c ^ (b | ~d)
                    g = (7 * i) % 16
                }
                
                let k: [UInt32] = [
                    0xD76AA478, 0xE8C7B756, 0x242070DB, 0xC1BDCEEE,
                    0xF57C0FAF, 0x4787C62A, 0xA8304613, 0xFD469501,
                    0x698098D8, 0x8B44F7AF, 0xFFFF5BB1, 0x895CD7BE,
                    0x6B901122, 0xFD987193, 0xA679438E, 0x49B40821,
                    0xF61E2562, 0xC040B340, 0x265E5A51, 0xE9B6C7AA,
                    0xD62F105D, 0x02441453, 0xD8A1E681, 0xE7D3FBC8,
                    0x21E1CDE6, 0xC33707D6, 0xF4D50D87, 0x455A14ED,
                    0xA9E3E905, 0xFCEFA3F8, 0x676F02D9, 0x8D2A4C8A,
                    0xFFFA3942, 0x8771F681, 0x6D9D6122, 0xFDE5380C,
                    0xA4BEEA44, 0x4BDECFA9, 0xF6BB4B60, 0xBEBFBC70,
                    0x289B7EC6, 0xEAA127FA, 0xD4EF3085, 0x04881D05,
                    0xD9D4D039, 0xE6DB99E5, 0x1FA27CF8, 0xC4AC5665,
                    0xF4292244, 0x432AFF97, 0xAB9423A7, 0xFC93A039,
                    0x655B59C3, 0x8F0CCC92, 0xFFEFF47D, 0x85845DD1,
                    0x6FA87E4F, 0xFE2CE6E0, 0xA3014314, 0x4E0811A1,
                    0xF7537E82, 0xBD3AF235, 0x2AD7D2BB, 0xEB86D391
                ]
                
                let s: [UInt32] = [
                    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
                    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
                    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
                ]
                
                f = f &+ w[g] &+ k[i]
                let temp = d
                d = c
                c = b
                b = b &+ leftRotate(a &+ f, by: s[i])
                a = temp
            }
            
            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
        }
        
        var result = ""
        for h in hash {
            result += String(format: "%02x%02x%02x%02x", 
                           h & 0xFF, (h >> 8) & 0xFF, (h >> 16) & 0xFF, (h >> 24) & 0xFF)
        }
        
        return result
    }
    
}

private func leftRotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
    return (value << amount) | (value >> (32 - amount))
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
            // Get raw values from data
            var solar = data.datas.double(for: "generationPower") ?? 0
            var pvPower = data.datas.double(for: "pvPower") ?? 0
            let gridConsumption = data.datas.double(for: "gridConsumptionPower") ?? 0
            let feedIn = data.datas.double(for: "feedinPower") ?? 0
            let home = data.datas.double(for: "loadsPower") ?? 0
            let gridFlow = gridConsumption - feedIn
            
            let batteryCharge = data.datas.double(for: "batChargePower") ?? 0
            let batteryDischarge = data.datas.double(for: "batDischargePower") ?? 0
            let batteryFlow = batteryCharge - batteryDischarge
            let batterySoC = data.datas.double(for: "SoC") ?? 0
            
            // Treat solar energy values of 0.02 or less as 0
            if solar <= 0.02 { solar = 0 }
            if pvPower <= 0.02 { pvPower = 0 }
            
            if args.debugMode {
                print("DEBUG: Raw values:")
                print("DEBUG: Solar: \(solar) W")
                print("DEBUG: PVPower: \(pvPower) W")
                print("DEBUG: GridConsumption: \(gridConsumption) W")
                print("DEBUG: FeedIn: \(feedIn) W")
                print("DEBUG: Home: \(home) W")
                print("DEBUG: BatteryCharge: \(batteryCharge) W")
                print("DEBUG: BatteryDischarge: \(batteryDischarge) W")
            }
            
            // Helper function to format power values in kW
            let formatValue = { (value: Double) -> String in
                let rawFormatted = String(format: "%.\(args.decimalPlaces)f", value)
                let trimmed = rawFormatted.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                return "\(trimmed) kW"
            }
            
            // Print a formatted summary of the system status
            print("Device: \(device.stationName)")
            print("generationPower: \(formatValue(solar))")
            print("pvPower: \(formatValue(pvPower))")
            print("loadsPower: \(formatValue(home))")
            print("Grid: \(formatValue(abs(gridFlow))) \(gridFlow > 0 ? "import" : "export")")
            
            if device.hasBattery {
                print("Battery: \(formatValue(abs(batteryFlow))) \(batteryFlow > 0 ? "charging" : "discharging")")
                let socFormatted = String(format: "%.\(args.decimalPlaces)f", batterySoC)
                let socTrimmed = socFormatted.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                print("SoC: \(socTrimmed)%")
            }
        } else if args.showAll {
            // Show all available variables when --all flag is used
            data.datas.dumpVariables(decimalPlaces: args.decimalPlaces)
        } else {
            // Show only the requested variables
            for variable in args.variables {
                if let value = data.datas.double(for: variable) {
                    // Apply the zero threshold for solar energy values
                    let adjustedValue = (variable == "generationPower" || variable == "pvPower") && value <= 0.02 ? 0.0 : value
                    
                    let unit = data.datas.getUnit(for: variable)
                    let rawFormatted = String(format: "%.\(args.decimalPlaces)f", adjustedValue)
                    let trimmed = rawFormatted.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                    print("\(variable): \(trimmed) \(unit)")
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
