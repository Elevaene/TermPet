import Foundation
import TermPetCore

enum SystemSampler {
    static func sample() -> SystemSnapshot {
        SystemSnapshot(
            cpuUsage: cpuUsageEstimate(),
            memoryPressure: memoryPressureEstimate(),
            diskFreeFraction: diskFreeFraction(),
            batteryLevel: batteryLevel(),
            isCharging: isCharging()
        )
    }

    private static func cpuUsageEstimate() -> Double {
        var loads = [Double](repeating: 0, count: 1)
        let count = getloadavg(&loads, 1)
        guard count == 1 else { return 0 }
        let cores = max(ProcessInfo.processInfo.processorCount, 1)
        return min(max(loads[0] / Double(cores), 0), 1)
    }

    private static func memoryPressureEstimate() -> MemoryPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical:
            return .high
        case .fair:
            return .warning
        default:
            return .normal
        }
    }

    private static func diskFreeFraction() -> Double {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]),
              let available = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity,
              total > 0
        else {
            return 1
        }
        return min(max(Double(available) / Double(total), 0), 1)
    }

    private static func batteryLevel() -> Double? {
        let output = pmsetBatteryOutput()
        guard let percentRange = output.range(of: #"(\d+)%"#, options: .regularExpression) else {
            return nil
        }
        let number = output[percentRange].dropLast()
        guard let percent = Double(number) else { return nil }
        return percent / 100.0
    }

    private static func isCharging() -> Bool {
        pmsetBatteryOutput().localizedCaseInsensitiveContains("AC Power")
    }

    private static func pmsetBatteryOutput() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
