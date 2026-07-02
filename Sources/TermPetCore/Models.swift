import Foundation

public enum PetState: String, Codable, CaseIterable, Sendable {
    case idle
    case happy
    case shocked
    case working
    case sleeping
    case waiting
}

public enum PetMouseDirection: String, Sendable {
    case none
    case left
    case right
    case up
    case down
    case near
}

public enum PetPersonality: String, Codable, CaseIterable, Sendable {
    case gentle
    case sarcastic
    case technical

    public var title: String {
        switch self {
        case .gentle: "温柔"
        case .sarcastic: "毒舌"
        case .technical: "技术型"
        }
    }
}

public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case ruleBased
    case openAICompatible
    case ollama

    public var title: String {
        switch self {
        case .ruleBased: "本地规则"
        case .openAICompatible: "OpenAI Compatible"
        case .ollama: "Ollama"
        }
    }
}

public struct TermPetSettings: Codable, Equatable, Sendable {
    public var personality: PetPersonality
    public var petSize: Double
    public var doNotDisturb: Bool
    public var speechFrequencySeconds: Double
    public var aiProvider: AIProvider
    public var apiBaseURL: String
    public var apiKey: String
    public var openAIModel: String
    public var ollamaBaseURL: String
    public var ollamaModel: String
    public var isListeningPaused: Bool
    public var customPetImagePath: String

    public init(
        personality: PetPersonality = .gentle,
        petSize: Double = 180,
        doNotDisturb: Bool = false,
        speechFrequencySeconds: Double = 20,
        aiProvider: AIProvider = .ruleBased,
        apiBaseURL: String = "",
        apiKey: String = "",
        openAIModel: String = "gpt-4o-mini",
        ollamaBaseURL: String = "http://localhost:11434",
        ollamaModel: String = "llama3.2",
        isListeningPaused: Bool = false,
        customPetImagePath: String = "__bundled__"
    ) {
        self.personality = personality
        self.petSize = petSize
        self.doNotDisturb = doNotDisturb
        self.speechFrequencySeconds = speechFrequencySeconds
        self.aiProvider = aiProvider
        self.apiBaseURL = apiBaseURL
        self.apiKey = apiKey
        self.openAIModel = openAIModel
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
        self.isListeningPaused = isListeningPaused
        self.customPetImagePath = customPetImagePath
    }
}

public struct PetResponse: Equatable, Sendable {
    public var state: PetState
    public var message: String
    public var isUrgent: Bool

    public init(state: PetState, message: String, isUrgent: Bool = false) {
        self.state = state
        self.message = message
        self.isUrgent = isUrgent
    }
}

public struct ResponderContext: Equatable, Sendable {
    public var personality: PetPersonality
    public var repeatedFailureCount: Int

    public init(personality: PetPersonality, repeatedFailureCount: Int) {
        self.personality = personality
        self.repeatedFailureCount = repeatedFailureCount
    }
}

public enum MemoryPressure: String, Codable, Sendable {
    case normal
    case warning
    case high

    public var title: String {
        switch self {
        case .normal: "正常"
        case .warning: "偏高"
        case .high: "高"
        }
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public var cpuUsage: Double
    public var memoryPressure: MemoryPressure
    public var diskFreeFraction: Double
    public var batteryLevel: Double?
    public var isCharging: Bool

    public init(
        cpuUsage: Double,
        memoryPressure: MemoryPressure,
        diskFreeFraction: Double,
        batteryLevel: Double?,
        isCharging: Bool
    ) {
        self.cpuUsage = cpuUsage
        self.memoryPressure = memoryPressure
        self.diskFreeFraction = diskFreeFraction
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
    }
}

public enum SystemWarning: String, CaseIterable, Sendable {
    case highCPU
    case highMemoryPressure
    case lowDiskSpace
    case lowBattery

    public var message: String {
        switch self {
        case .highCPU: "CPU 有点烫手，看看是不是有任务跑飞了。"
        case .highMemoryPressure: "内存压力偏高，可以考虑关掉几个暂时不用的进程。"
        case .lowDiskSpace: "磁盘空间低于 10%，该清理一下缓存或大文件了。"
        case .lowBattery: "电量低于 20%，而且还没充电。"
        }
    }
}
