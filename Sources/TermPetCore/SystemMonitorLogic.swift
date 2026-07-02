import Foundation

public enum SystemMonitorLogic {
    public static func warnings(for snapshot: SystemSnapshot) -> [SystemWarning] {
        var warnings: [SystemWarning] = []

        if snapshot.cpuUsage > 0.85 {
            warnings.append(.highCPU)
        }

        if snapshot.memoryPressure == .high {
            warnings.append(.highMemoryPressure)
        }

        if snapshot.diskFreeFraction < 0.10 {
            warnings.append(.lowDiskSpace)
        }

        if let batteryLevel = snapshot.batteryLevel, batteryLevel < 0.20, !snapshot.isCharging {
            warnings.append(.lowBattery)
        }

        return warnings
    }
}
