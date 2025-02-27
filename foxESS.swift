import Foundation
import CryptoKit

// Models
struct Device: Codable {
    let deviceSN: String
    let stationName: String
    let stationID: String
    let battery: String?
    let moduleSN: String
    let deviceType: String
    let hasPV: Bool
    let hasBattery: Bool
}

struct NetworkResponse<T: Decodable>: Decodable {
    let errno: Int
    let result: T?
}

struct DeviceListRequest: Codable {
    var currentPage: Int
    var pageSize: Int
    
    init() {
        self.currentPage = 1
        self.pageSize = 10
    }
}

struct PagedDeviceListResponse: Codable {
    let pageSize: Int
    let currentPage: Int
    let total: Int
    let data: [DeviceSummaryResponse]
}

struct DeviceSummaryResponse: Codable {
    let deviceSN: String
    let deviceType: String
    let stationID: String
    let stationName: String
    let moduleSN: String
    let hasBattery: Bool
    let hasPV: Bool
}

struct OpenQueryRequest: Codable {
    let deviceSN: String
    let variables: [String]
}

struct OpenQueryResponse: Codable {
    let deviceSN: String
    let datas: [OpenQueryData]
}

struct OpenQueryData: Codable {
    let variable: String
    let value: QueryData
    let name: String
    let unit: String?
    
    enum CodingKeys: String, CodingKey {
        case variable
        case value
        case name
        case unit
    }
}

enum QueryData: Codable {
    case double(Double)
    case string(String)
    case unknown
    
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

// Command line arguments parser
class CommandLineArgs {
    var apiKey: String?
    var debugMode = false
    var testMode = false
    var showHelp = false
    var variables: [String] = []
    var showAll = false
    
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
                // This is a variable the user wants to see
                variables.append(arg.dropFirst(2).lowercased())
            } else if !arg.hasPrefix("-") {
                // Assume this is the API key
                apiKey = arg
            }
            
            i += 1
        }
    }
    
    func printHelp() {
        print("EnergyStatsCmd - Command line tool to query FoxESS energy data")
        print("")
        print("Usage: EnergyStatsCmd <API_KEY> [options] [variables]")
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
        print("  EnergyStatsCmd YOUR_API_KEY --generationPower --SoC")
        print("  EnergyStatsCmd YOUR_API_KEY --all")
    }
}

// Extensions
extension Array where Element == OpenQueryData {
    func double(for key: String) -> Double? {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            if case .double(let value) = item.value {
                return value
            }
        }
        return nil
    }
    
    func string(for key: String) -> String? {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            if case .string(let value) = item.value {
                return value
            }
        }
        return nil
    }
    
    func getUnit(for key: String) -> String {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            return item.unit ?? ""
        }
        return ""
    }
    
    func getName(for key: String) -> String {
        if let item = self.first(where: { $0.variable.lowercased() == key.lowercased() }) {
            return item.name
        }
        return key
    }
    
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

// EnergyStatsAPI
class EnergyStatsAPI {
    private let apiKey: String
    private var token: String?
    private let debugMode: Bool
    
    init(apiKey: String, debugMode: Bool = false) {
        self.apiKey = apiKey
        self.debugMode = debugMode
    }
    
    private func addHeaders(to request: inout URLRequest) {
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "token")
        }
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en", forHTTPHeaderField: "lang")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "timezone")
        request.setValue("EnergyStatsCmdLine/1.0", forHTTPHeaderField: "User-Agent")
        
        let timestamp = Int64(round(Date().timeIntervalSince1970 * 1000))
        let timestampString = String(timestamp)
        request.setValue(timestampString, forHTTPHeaderField: "timestamp")
        
        let path = request.url?.path ?? ""
        
        if debugMode {
            print("DEBUG: Setting up headers for \(path)")
            print("DEBUG: Timestamp: \(timestampString)")
        }
        
        // FoxESS signature format
        let signatureParts = [path, token ?? "", timestampString]
        let signatureInput = signatureParts.joined(separator: "\\r\\n")
        let signature = signatureInput.md5()
        
        if debugMode {
            print("DEBUG: Signature: \(signature)")
        }
        
        request.setValue(signature, forHTTPHeaderField: "signature")
    }
    
    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        if debugMode {
            print("DEBUG: Fetching \(request.url?.absoluteString ?? "unknown URL")")
        }
        
        var request = request
        request.timeoutInterval = 30
        addHeaders(to: &request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = (response as? HTTPURLResponse) else {
                throw NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            let statusCode = httpResponse.statusCode
            if debugMode {
                print("DEBUG: Status code: \(statusCode)")
            }
            
            guard 200 ... 300 ~= statusCode else {
                if debugMode {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("DEBUG: Error response: \(responseString)")
                }
                throw NSError(domain: "InvalidStatusCode", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid status code \(statusCode)"])
            }
            
            let networkResponse = try JSONDecoder().decode(NetworkResponse<T>.self, from: data)
            
            if networkResponse.errno > 0 {
                throw NSError(domain: "FoxServerError", code: networkResponse.errno, userInfo: [NSLocalizedDescriptionKey: "Server error \(networkResponse.errno)"])
            }
            
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
    
    func authenticate() async throws {
        if debugMode {
            print("DEBUG: Setting API key as token")
        }
        self.token = apiKey
    }
    
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

// String MD5 extension
extension String {
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

// This is the main application logic
func run(args: CommandLineArgs) async {
    guard !args.showHelp else {
        args.printHelp()
        return
    }
    
    guard let apiKey = args.apiKey else {
        print("Error: No API key provided")
        print("Use --help for usage information")
        return
    }
    
    let api = EnergyStatsAPI(apiKey: apiKey, debugMode: args.debugMode)
    
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
        
        try await api.authenticate()
        
        // Get the device list
        if args.debugMode {
            print("DEBUG: Getting device list")
        }
        let devices = try await api.fetchDeviceList()
        
        guard let device = devices.first else {
            print("No devices found for this account")
            return
        }
        
        if args.debugMode {
            print("DEBUG: Found device: \(device.stationName) (\(device.deviceSN))")
        }
        
        // Get real-time data
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
            
            let formatValue = { (value: Double) -> String in
                return String(format: "%.2f kW", value / 1000.0)
            }
            
            print("Device: \(device.stationName)")
            print("Solar: \(formatValue(solar))")
            print("Home:  \(formatValue(home))")
            print("Grid:  \(formatValue(abs(gridFlow))) \(gridFlow > 0 ? "import" : "export")")
            
            if device.hasBattery {
                print("Battery: \(formatValue(abs(batteryFlow))) \(batteryFlow > 0 ? "charging" : "discharging")")
                print("Battery Level: \(String(format: "%.1f%%", batterySoC))")
            }
        } else if args.showAll {
            // Show all available variables
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
        print("Error: \(error.localizedDescription)")
        if args.debugMode {
            print("Detailed error: \(error)")
        }
    }
}

// Parse command line arguments
let args = CommandLineArgs(args: CommandLine.arguments)
if args.debugMode {
    print("DEBUG: Starting application with arguments: \(CommandLine.arguments)")
}

// Run the main task
let task = Task {
    await run(args: args)
    if args.debugMode {
        print("DEBUG: Task completed")
    }
    exit(0)
}

// Wait for the task to complete
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))