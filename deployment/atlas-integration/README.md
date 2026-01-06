# Atlas App Integration Guide

Complete guide for integrating your Atlas iOS app with the Heating Design API running on Unraid.

## Table of Contents

1. [Overview](#overview)
2. [API Configuration](#api-configuration)
3. [Authentication](#authentication)
4. [Core Integration Flows](#core-integration-flows)
5. [Data Mapping](#data-mapping)
6. [Error Handling](#error-handling)
7. [Offline Support](#offline-support)
8. [Testing](#testing)

---

## Overview

The Atlas app integrates with the Heating Design API to:
- Import survey data and floor plans
- Trigger heat loss calculations
- Retrieve calculation results
- Export reports for client delivery

**Architecture:**

```
┌─────────────────┐
│   Atlas App     │
│   (iOS/iPad)    │
└────────┬────────┘
         │ HTTPS/HTTP
         │ (LAN)
         ▼
┌─────────────────┐
│  Unraid Server  │
│  192.168.1.XXX  │
├─────────────────┤
│ Heating API     │
│ Port: 3001      │
└────────┬────────┘
         │
         ▼
    PostgreSQL DB
```

---

## API Configuration

### 1. Environment Setup

Create a configuration file in your Atlas project:

**`Config/HeatingAPI.swift`**

```swift
import Foundation

struct HeatingAPIConfig {
    // MARK: - Server Configuration

    // Change this to your Unraid server IP
    static let baseURL = "http://192.168.1.100:3001"

    // API key from your Unraid deployment .env file
    static let apiKey = "your_api_key_from_env_file"

    // Request timeout
    static let timeout: TimeInterval = 30.0

    // MARK: - Endpoints

    enum Endpoint {
        case health
        case atlasImport
        case projectCreate
        case projectDetail(String)
        case projectCalculate(String)
        case projectResults(String)
        case exportPDF(String)

        var path: String {
            switch self {
            case .health:
                return "/health"
            case .atlasImport:
                return "/api/atlas/import"
            case .projectCreate:
                return "/api/projects"
            case .projectDetail(let id):
                return "/api/projects/\(id)"
            case .projectCalculate(let id):
                return "/api/projects/\(id)/calculate"
            case .projectResults(let id):
                return "/api/projects/\(id)/results"
            case .exportPDF(let id):
                return "/api/projects/\(id)/export/pdf"
            }
        }

        var url: URL {
            URL(string: baseURL + path)!
        }
    }
}
```

### 2. Network Client

Create a reusable API client:

**`Services/HeatingAPIClient.swift`**

```swift
import Foundation

class HeatingAPIClient {
    static let shared = HeatingAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = HeatingAPIConfig.timeout
        config.timeoutIntervalForResource = HeatingAPIConfig.timeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Request Methods

    func get<T: Decodable>(
        endpoint: HeatingAPIConfig.Endpoint,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(HeatingAPIConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        return try await performRequest(request, responseType: responseType)
    }

    func post<T: Encodable, U: Decodable>(
        endpoint: HeatingAPIConfig.Endpoint,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(HeatingAPIConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequest(request, responseType: responseType)
    }

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HeatingAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(
                APIErrorResponse.self,
                from: data
            ) {
                throw HeatingAPIError.apiError(errorResponse)
            }
            throw HeatingAPIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Error Types

enum HeatingAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(APIErrorResponse)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let response):
            return response.message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
    let message: String
    let statusCode: Int
}
```

---

## Authentication

### Health Check

Always verify connectivity before making requests:

```swift
func checkAPIConnection() async -> Bool {
    do {
        let health = try await HeatingAPIClient.shared.get(
            endpoint: .health,
            responseType: HealthResponse.self
        )
        return health.status == "ok"
    } catch {
        print("API health check failed: \(error)")
        return false
    }
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
}
```

---

## Core Integration Flows

### Flow 1: Import Survey Data

When a user completes a survey in Atlas, send it to the Heating Design API:

**`Services/HeatingIntegration.swift`**

```swift
import Foundation

class HeatingIntegration {

    /// Import Atlas survey data to create a heating design project
    func importSurveyData(_ survey: Survey) async throws -> String {

        // 1. Convert Atlas survey to API format
        let importRequest = AtlasImportRequest(
            surveyId: survey.id,
            clientName: survey.clientName,
            address: survey.address,
            rooms: survey.rooms.map { room in
                RoomImportData(
                    name: room.name,
                    roomType: mapRoomType(room.type),
                    area: room.area,
                    volume: room.volume,
                    ceilingHeight: room.ceilingHeight,
                    exteriorWalls: room.exteriorWallCount,
                    windowArea: room.windowArea,
                    doorCount: room.doorCount,
                    targetTemperature: 20.0,
                    coordinates: room.coordinates
                )
            },
            buildingData: BuildingImportData(
                constructionYear: survey.building.yearBuilt,
                wallType: survey.building.wallConstruction,
                insulationType: survey.building.insulation,
                windowType: survey.building.windowType,
                heatingSystem: survey.building.existingHeating
            ),
            floorPlanUrl: survey.floorPlan?.uploadedURL
        )

        // 2. Send to API
        let response = try await HeatingAPIClient.shared.post(
            endpoint: .atlasImport,
            body: importRequest,
            responseType: ProjectCreatedResponse.self
        )

        // 3. Store project ID in Atlas database
        try await survey.updateHeatingProjectId(response.projectId)

        return response.projectId
    }

    /// Map Atlas room types to Heating Design API room types
    private func mapRoomType(_ atlasType: String) -> String {
        switch atlasType.lowercased() {
        case "living room", "lounge":
            return "living_room"
        case "bedroom", "bed room":
            return "bedroom"
        case "kitchen":
            return "kitchen"
        case "bathroom", "toilet", "wc":
            return "bathroom"
        case "hallway", "hall", "corridor":
            return "hallway"
        case "office", "study":
            return "office"
        default:
            return "other"
        }
    }
}

// MARK: - Request/Response Models

struct AtlasImportRequest: Codable {
    let surveyId: String
    let clientName: String
    let address: String
    let rooms: [RoomImportData]
    let buildingData: BuildingImportData
    let floorPlanUrl: String?
}

struct RoomImportData: Codable {
    let name: String
    let roomType: String
    let area: Double
    let volume: Double
    let ceilingHeight: Double
    let exteriorWalls: Int
    let windowArea: Double
    let doorCount: Int
    let targetTemperature: Double
    let coordinates: [Coordinate]?
}

struct BuildingImportData: Codable {
    let constructionYear: Int?
    let wallType: String?
    let insulationType: String?
    let windowType: String?
    let heatingSystem: String?
}

struct Coordinate: Codable {
    let x: Double
    let y: Double
}

struct ProjectCreatedResponse: Codable {
    let projectId: String
    let message: String
    let roomsCreated: Int
}
```

### Flow 2: Trigger Calculations

After importing data, trigger heat loss calculations:

```swift
/// Trigger heat loss calculations for a project
func calculateHeatLoss(projectId: String, parameters: CalculationParameters) async throws {

    let request = CalculationRequest(
        outdoorTemp: parameters.outdoorTemp,
        indoorTemp: parameters.indoorTemp,
        wallUValue: parameters.wallUValue,
        windowUValue: parameters.windowUValue,
        floorUValue: parameters.floorUValue,
        ceilingUValue: parameters.ceilingUValue,
        airChangeRate: parameters.airChangeRate
    )

    let response = try await HeatingAPIClient.shared.post(
        endpoint: .projectCalculate(projectId),
        body: request,
        responseType: CalculationStartedResponse.self
    )

    print("Calculation started: \(response.message)")
}

struct CalculationParameters {
    let outdoorTemp: Double      // e.g., -3.0°C for UK design temp
    let indoorTemp: Double        // e.g., 20.0°C
    let wallUValue: Double        // e.g., 0.30 W/m²K for modern insulation
    let windowUValue: Double      // e.g., 1.4 W/m²K for double glazing
    let floorUValue: Double       // e.g., 0.25 W/m²K
    let ceilingUValue: Double     // e.g., 0.16 W/m²K
    let airChangeRate: Double     // e.g., 0.5 ACH
}

struct CalculationRequest: Codable {
    let outdoorTemp: Double
    let indoorTemp: Double
    let wallUValue: Double
    let windowUValue: Double
    let floorUValue: Double
    let ceilingUValue: Double
    let airChangeRate: Double
}

struct CalculationStartedResponse: Codable {
    let message: String
    let calculationIds: [String]
}
```

### Flow 3: Retrieve Results

Poll for calculation results:

```swift
/// Get calculation results for a project
func getCalculationResults(projectId: String) async throws -> ProjectResults {

    let results = try await HeatingAPIClient.shared.get(
        endpoint: .projectResults(projectId),
        responseType: ProjectResults.self
    )

    return results
}

/// Poll for results with timeout
func waitForResults(
    projectId: String,
    timeout: TimeInterval = 30.0
) async throws -> ProjectResults {

    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
        let results = try await getCalculationResults(projectId: projectId)

        // Check if all calculations are complete
        let allComplete = results.rooms.allSatisfy { room in
            room.calculation?.status == "completed"
        }

        if allComplete {
            return results
        }

        // Wait before next poll
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }

    throw HeatingAPIError.apiError(
        APIErrorResponse(
            error: "Timeout",
            message: "Calculation did not complete within \(timeout) seconds",
            statusCode: 408
        )
    )
}

struct ProjectResults: Codable {
    let projectId: String
    let projectName: String
    let totalHeatLoss: Double
    let rooms: [RoomResults]
}

struct RoomResults: Codable {
    let roomId: String
    let roomName: String
    let area: Double
    let calculation: CalculationResults?
}

struct CalculationResults: Codable {
    let status: String
    let transmissionLoss: Double
    let ventilationLoss: Double
    let totalHeatLoss: Double
    let designHeatLoad: Double
    let recommendedRadiatorSize: String?
}
```

### Flow 4: Export PDF Report

Generate and download PDF reports:

```swift
/// Export project as PDF
func exportPDF(projectId: String) async throws -> URL {

    // Request PDF generation
    let response = try await HeatingAPIClient.shared.post(
        endpoint: .exportPDF(projectId),
        body: EmptyRequest(),
        responseType: ExportResponse.self
    )

    // Download PDF file
    guard let pdfURL = URL(string: response.fileUrl) else {
        throw HeatingAPIError.invalidResponse
    }

    let (localURL, _) = try await URLSession.shared.download(from: pdfURL)

    // Move to documents directory
    let documentsPath = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]

    let destinationURL = documentsPath.appendingPathComponent(
        "heating_\(projectId).pdf"
    )

    try? FileManager.default.removeItem(at: destinationURL)
    try FileManager.default.moveItem(at: localURL, to: destinationURL)

    return destinationURL
}

struct EmptyRequest: Codable {}

struct ExportResponse: Codable {
    let fileUrl: String
    let fileName: String
    let fileSize: Int
}
```

---

## Data Mapping

### Survey → Project Mapping

| Atlas Survey Field | Heating Design Field | Notes |
|-------------------|---------------------|-------|
| `survey.id` | `surveyId` | Reference |
| `survey.clientName` | `clientName` | Direct |
| `survey.address` | `address` | Direct |
| `room.name` | `room.name` | Direct |
| `room.area` | `room.area` | m² |
| `room.volume` | `room.volume` | m³ |
| `room.ceilingHeight` | `room.ceilingHeight` | meters |
| `room.windowArea` | `room.windowArea` | m² |
| `room.exteriorWallCount` | `room.exteriorWalls` | Count |

### Recommended Default Values

```swift
struct HeatingDefaults {
    // UK Building Regulations Part L defaults
    static let wallUValue = 0.30        // W/m²K
    static let windowUValue = 1.4       // W/m²K (double glazed)
    static let floorUValue = 0.25       // W/m²K
    static let ceilingUValue = 0.16     // W/m²K
    static let airChangeRate = 0.5      // ACH

    // UK design temperatures
    static let outdoorDesignTemp = -3.0 // °C
    static let indoorDesignTemp = 20.0  // °C (living spaces)
    static let bathroomTemp = 22.0      // °C
    static let bedroomTemp = 18.0       // °C
}
```

---

## Error Handling

### Comprehensive Error Handling

```swift
func performHeatingCalculation(survey: Survey) async {
    do {
        // 1. Check connectivity
        guard await checkAPIConnection() else {
            showError("Cannot connect to Heating Design server. Check network.")
            return
        }

        // 2. Import data
        showProgress("Importing survey data...")
        let projectId = try await importSurveyData(survey)

        // 3. Trigger calculation
        showProgress("Calculating heat loss...")
        try await calculateHeatLoss(
            projectId: projectId,
            parameters: CalculationParameters(
                outdoorTemp: HeatingDefaults.outdoorDesignTemp,
                indoorTemp: HeatingDefaults.indoorDesignTemp,
                wallUValue: HeatingDefaults.wallUValue,
                windowUValue: HeatingDefaults.windowUValue,
                floorUValue: HeatingDefaults.floorUValue,
                ceilingUValue: HeatingDefaults.ceilingUValue,
                airChangeRate: HeatingDefaults.airChangeRate
            )
        )

        // 4. Wait for results
        showProgress("Waiting for results...")
        let results = try await waitForResults(projectId: projectId)

        // 5. Display results
        showResults(results)

        // 6. Optional: Export PDF
        if userWantsPDF {
            let pdfURL = try await exportPDF(projectId: projectId)
            sharePDF(url: pdfURL)
        }

    } catch HeatingAPIError.networkError(let error) {
        showError("Network error: \(error.localizedDescription)")
    } catch HeatingAPIError.apiError(let apiError) {
        showError("API error: \(apiError.message)")
    } catch {
        showError("Unexpected error: \(error.localizedDescription)")
    }
}
```

---

## Offline Support

### Queue Requests for Later

```swift
class OfflineQueue {
    static let shared = OfflineQueue()

    private let queue = UserDefaults.standard
    private let queueKey = "heating_api_queue"

    func enqueue(survey: Survey) {
        var pending = getPendingUploads()
        pending.append(survey.id)
        queue.set(pending, forKey: queueKey)
    }

    func processPendingUploads() async {
        guard await checkAPIConnection() else { return }

        let pending = getPendingUploads()

        for surveyId in pending {
            if let survey = fetchSurvey(id: surveyId) {
                do {
                    _ = try await HeatingIntegration().importSurveyData(survey)
                    removePending(surveyId)
                } catch {
                    print("Failed to upload \(surveyId): \(error)")
                }
            }
        }
    }

    private func getPendingUploads() -> [String] {
        queue.stringArray(forKey: queueKey) ?? []
    }

    private func removePending(_ id: String) {
        var pending = getPendingUploads()
        pending.removeAll { $0 == id }
        queue.set(pending, forKey: queueKey)
    }
}
```

---

## Testing

### Mock API for Development

```swift
class MockHeatingAPIClient: HeatingAPIClient {

    override func post<T, U>(
        endpoint: HeatingAPIConfig.Endpoint,
        body: T,
        responseType: U.Type
    ) async throws -> U where T : Encodable, U : Decodable {

        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Return mock data based on endpoint
        switch endpoint {
        case .atlasImport:
            return ProjectCreatedResponse(
                projectId: UUID().uuidString,
                message: "Project created successfully",
                roomsCreated: 5
            ) as! U

        case .projectCalculate:
            return CalculationStartedResponse(
                message: "Calculations started",
                calculationIds: ["calc-1", "calc-2"]
            ) as! U

        default:
            throw HeatingAPIError.invalidResponse
        }
    }
}
```

### Unit Tests

```swift
import XCTest

class HeatingIntegrationTests: XCTestCase {

    func testImportSurveyData() async throws {
        let survey = createMockSurvey()
        let integration = HeatingIntegration()

        let projectId = try await integration.importSurveyData(survey)

        XCTAssertFalse(projectId.isEmpty)
    }

    func testCalculationResults() async throws {
        let projectId = "test-project-id"
        let integration = HeatingIntegration()

        let results = try await integration.getCalculationResults(
            projectId: projectId
        )

        XCTAssertGreaterThan(results.totalHeatLoss, 0)
    }
}
```

---

## Example: Complete Integration Flow

```swift
/// Complete flow from survey to PDF export
@MainActor
class HeatingWorkflow: ObservableObject {

    @Published var progress: String = ""
    @Published var isProcessing: Bool = false
    @Published var results: ProjectResults?
    @Published var error: String?

    private let integration = HeatingIntegration()

    func processS survey(_ survey: Survey) async {
        isProcessing = true
        error = nil

        do {
            // Step 1: Import
            progress = "Importing survey data..."
            let projectId = try await integration.importSurveyData(survey)

            // Step 2: Calculate
            progress = "Calculating heat loss..."
            try await integration.calculateHeatLoss(
                projectId: projectId,
                parameters: CalculationParameters(
                    outdoorTemp: -3.0,
                    indoorTemp: 20.0,
                    wallUValue: 0.30,
                    windowUValue: 1.4,
                    floorUValue: 0.25,
                    ceilingUValue: 0.16,
                    airChangeRate: 0.5
                )
            )

            // Step 3: Get results
            progress = "Retrieving results..."
            let projectResults = try await integration.waitForResults(
                projectId: projectId,
                timeout: 30.0
            )

            results = projectResults
            progress = "Complete!"

        } catch {
            self.error = error.localizedDescription
            progress = "Failed"
        }

        isProcessing = false
    }
}
```

---

**Integration Complete!** Your Atlas app can now communicate with the Heating Design API running on your Unraid server.
