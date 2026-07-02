import Foundation

public protocol PetResponder {
    func respond(to event: TerminalEvent, context: ResponderContext) -> PetResponse
}

public struct RuleBasedResponder: PetResponder {
    public init() {}

    public func respond(to event: TerminalEvent, context: ResponderContext) -> PetResponse {
        if context.repeatedFailureCount >= 3 && event.isFailure {
            return PetResponse(
                state: .shocked,
                message: repeatedFailureMessage(count: context.repeatedFailureCount, personality: context.personality),
                isUrgent: true
            )
        }

        switch event.type {
        case .commandStarted:
            return PetResponse(state: .working, message: startedMessage(command: event.command))
        case .commandFinished:
            if event.isSuccess {
                return successResponse(for: event, personality: context.personality)
            }
            return failureResponse(for: event, personality: context.personality)
        }
    }

    // ── started ──

    private func startedMessage(command: String) -> String {
        pick([
            "👀 开始执行 `\(command)`，我看着呢。",
            "📡 收到，`\(command)` 走起。",
            "⚙️ `\(command)` 正在跑，别急。",
            "🫡 交给我盯着，`\(command)` 启动了。",
            "🧐 `\(command)` ... 希望你写对了。",
            "🎬 `\(command)` 开跑。",
            "🖥️ 终端正在忙碌中——`\(command)` 已启动。",
        ])
    }

    // ── success ──

    private func successResponse(for event: TerminalEvent, personality: PetPersonality) -> PetResponse {
        if event.isLongRunning {
            return PetResponse(state: .happy, message: pick(longSuccessMessages(for: personality)))
        }
        return PetResponse(state: .happy, message: pick(quickSuccessMessages(for: personality)))
    }

    private func quickSuccessMessages(for personality: PetPersonality) -> [String] {
        switch personality {
        case .gentle:
            return [
                "✅ 成功啦，一切顺利！",
                "🎉 完美执行，你好棒！",
                "✨ 顺利完成，没什么能难倒你。",
                "👍 命令跑通了，状态很好。",
                "🌸 这次很顺呢，继续保持～",
                "👏 一次过，nice！",
                "💚 成功！今天的终端很听话。",
            ]
        case .sarcastic:
            return [
                "✅ 居然一次过了，有点不习惯。",
                "🎉 成功！难得啊。",
                "✨ 还不错，不过别骄傲。",
                "👍 跑通了。我本来都准备好吐槽了。",
                "🫠 成功得有点可疑，你确定没偷懒？",
                "😏 可以可以，看来不是所有命令都炸。",
                "💅 行吧，这次我给及格分。",
            ]
        case .technical:
            return [
                "✅ 退出码 0，一切按预期执行。",
                "✅ 命令返回成功，没有异常。",
                "✅ 执行结束，退出状态正常。",
                "✅ 进程正常退出，耗时在合理范围内。",
                "✅ 运行完成，STDOUT/STDERR 没报错。",
                "✅ exit status 0，可以继续下一步了。",
                "✅ 编译 / 执行通过，没有 warning。",
            ]
        }
    }

    private func longSuccessMessages(for personality: PetPersonality) -> [String] {
        switch personality {
        case .gentle:
            return [
                "⏳ 终于跑完了，辛苦啦！",
                "🍵 漫长的等待结束了，喝口水休息下吧。",
                "🫶 等了这么久，终于出结果了。",
                "🌿 漫长的任务完成了，给自己点个赞。",
                "🏁 终点的曙光！任务完成。",
            ]
        case .sarcastic:
            return [
                "⏳ 终于跑完了，我差点以为它卡死了。",
                "🥱 总算结束了... 比我预期还慢了那么一点点。",
                "🐢 这个速度，怎么说呢，至少它完成了。",
                "⏰ 等得我快睡着了。不过结果是好的。",
                "🕯️ 漫长的等待画上句号。下次优化一下？",
            ]
        case .technical:
            return [
                "⏳ 长任务结束，总耗时在预期范围内。",
                "✅ 长时间任务正常退出，占用资源已释放。",
                "📊 任务完成，建议检查输出是否正确。",
                "🔬 长耗时任务结束，exit code 0，无异常。",
                "💾 重型任务完成，可以检查一下内存释放情况。",
            ]
        }
    }

    // ── failure ──

    private func failureResponse(for event: TerminalEvent, personality: PetPersonality) -> PetResponse {
        let exitCode = event.exitCode ?? -1
        let cmd = event.command
        let key = failureKey(exitCode: exitCode)

        let candidates = failurePool(for: personality, key: key, command: cmd, exitCode: exitCode)
        return PetResponse(state: .shocked, message: pick(candidates))
    }

    private func failureKey(exitCode: Int) -> String {
        switch exitCode {
        case 1: return "general"
        case 2: return "usage"
        case 126: return "permission"
        case 127: return "notFound"
        case 130: return "interrupted"
        case 137: return "killed"
        default: return "other"
        }
    }

    private func failurePool(for personality: PetPersonality, key: String, command: String, exitCode: Int) -> [String] {
        let cmd = command

        let general: [String]
        switch personality {
        case .gentle:
            general = [
                "❌ `\(cmd)` 没跑通（退出码 \(exitCode)），先看看路径对不对。",
                "💔 不要紧，`\(cmd)` 失败了。检查一下参数也许就好了。",
                "🫂 失败了没关系，换个思路试试 `\(cmd)`？",
                "🧸 出错了，不过 bugs 都是暂时的。`\(cmd)` 可能需要额外依赖。",
                "🌧️ 小小挫折，检查 `\(cmd)` 的用法：可能少了参数或文件不存在。",
            ]
        case .sarcastic:
            general = [
                "💥 它炸了。`\(cmd)` 退出码 \(exitCode)。又来？",
                "🤡 报错了。我就知道 `\(cmd)` 不会那么乖。",
                "💣 第 \(exitCode) 号炸弹已引爆，命令是 `\(cmd)`。",
                "🫠 `\(cmd)` 又双叒叕挂了。建议先别硬刚。",
                "🔥 烧起来了——`\(cmd)` 退出码 \(exitCode)。好戏继续。",
            ]
        case .technical:
            general = [
                "⚠️ `\(cmd)` 退出码 \(exitCode)，建议检查参数、路径和权限。",
                "🔍 `\(cmd)` 返回非零退出码 \(exitCode)。优先排查工作目录和最近变更。",
                "📋 `\(cmd)` 执行异常（exit \(exitCode)），检查输出的错误信息定位。",
                "🧪 `\(cmd)` 失败。尝试加 `--verbose` 或 `--debug` 看详细日志。",
                "📉 `\(cmd)` 退出码 \(exitCode)。如果是 shell 脚本，检查是否缺少 `#!/` 或引号不匹配。",
            ]
        }

        var pool = general

        switch key {
        case "usage":
            pool += [
                "📖 `\(cmd)` 可能参数不对。试试 `\(cmd) --help` 或 `man \(cmd)` 看看用法。",
                "❓ 退出码 2 通常表示参数有问题，确认一下 `\(cmd)` 的语法。",
            ]
        case "permission":
            pool += [
                "🔒 权限不够。试试 `chmod +x` 或者用 `sudo`（慎用）。",
                "🚫 看起来 `\(cmd)` 被拒绝了——检查文件权限和可执行属性。",
            ]
        case "notFound":
            pool += [
                "🔎 `\(cmd)` 没找到。是不是还没装，或者名字打错了？",
                "👻 命令不存在。也许是 typo，也许需要 `brew install`。",
            ]
        case "interrupted":
            pool += [
                "🛑 `\(cmd)` 被中断了（Ctrl+C？），需要重跑一次吗？",
                "⏹️ 命令被手动停止了。要不再来一次？",
            ]
        case "killed":
            pool += [
                "🪓 系统把 `\(cmd)` 杀掉了，可能内存飙了或者 OOM。",
                "💀 进程被 SIGKILL 干掉了——检查一下是不是吃太多资源了。",
            ]
        default:
            break
        }

        return pool
    }

    // ── repeated failure ──

    private func repeatedFailureMessage(count: Int, personality: PetPersonality) -> String {
        let prefix: String
        switch personality {
        case .gentle:
            prefix = pick([
                "先停一下，",
                "等一下，",
                "慢着慢着，",
                "观察到一个情况：",
            ])
        case .sarcastic:
            prefix = pick([
                "又来？！",
                "第 \(count) 次了！",
                "你还真执着啊，",
                "😮‍💨 我真服了。",
            ])
        case .technical:
            prefix = pick([
                "⚠️ 连续 \(count) 次相同错误。",
                "🔄 循环失败检测触发——",
                "📊 统计：同一条命令已失败 \(count) 次。",
            ])
        }

        let suffix: String
        switch personality {
        case .gentle:
            suffix = pick([
                "先别急着重复执行，换个角度排查一下参数、路径或者权限。",
                "不如静下心看看报错信息，也许问题不在命令本身。",
                "试试点开错误日志，或者把输出贴到搜索引擎里搜一下。",
            ])
        case .sarcastic:
            suffix = pick([
                "同一个命令疯狂报错。你是不是在指望它突然变好？",
                "建议喝口水，深呼吸，然后—别—再—跑—了—。",
                "同样的输入 → 同样的输出。你不期待奇迹对吧？去改代码。",
            ])
        case .technical:
            suffix = pick([
                "建议暂停，检查参数、依赖、工作目录和最近改动后再试。",
                "考虑加 `--dry-run` 或查看日志，确定根因后再重新执行。",
                "连续失败通常不是偶发问题。请 review 最近变更和配置差异。",
            ])
        }

        return "\(prefix)\(suffix)"
    }

    // ── idling ──

    public static func idleMessagesFor(personality: PetPersonality) -> [String] {
        switch personality {
        case .gentle:
            return idleKeywords + gentleIdleExtras
        case .sarcastic:
            return idleKeywords + sarcasticIdleExtras
        case .technical:
            return idleKeywords + technicalIdleExtras
        }
    }

    private static let idleKeywords = [
        "💡 戳我可以查看系统状态和最近事件。",
        "🐾 摸摸头？",
        "📋 想加个提醒？右滑看看面板。",
    ]

    private static let gentleIdleExtras = [
        "🌸 今天天气不错，写代码的好日子。",
        "🍵 记得喝水哦。",
        "🌿 代码写久了要起来走动走动～",
    ]

    private static let sarcasticIdleExtras = [
        "😏 你看着屏幕发呆已经好久了。",
        "🫠 还没开始写吗？我可是看着呢。",
        "💅 盯着我也解决不了 bug，对吧。",
    ]

    private static let technicalIdleExtras = [
        "⚙️ 需要检查系统资源吗？点我就行。",
        "📊 提醒列表在面板里可以设置。",
        "🖥️ 终端宠物已就绪——ALT+CMD+P 呼出/隐藏。",
    ]
}

public struct OpenAICompatibleResponder: PetResponder {
    private let fallback = RuleBasedResponder()
    public let baseURL: String
    public let apiKey: String
    public let model: String

    public init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    public func respond(to event: TerminalEvent, context: ResponderContext) -> PetResponse {
        let fallbackResponse = fallback.respond(to: event, context: context)
        guard event.isFailure,
              let reply = AIReplyClient.openAIReply(baseURL: baseURL, apiKey: apiKey, model: model, event: event, context: context)
        else {
            return fallbackResponse
        }
        return PetResponse(state: fallbackResponse.state, message: reply, isUrgent: fallbackResponse.isUrgent)
    }
}

public struct OllamaResponder: PetResponder {
    private let fallback = RuleBasedResponder()
    public let baseURL: String
    public let model: String

    public init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    public func respond(to event: TerminalEvent, context: ResponderContext) -> PetResponse {
        let fallbackResponse = fallback.respond(to: event, context: context)
        guard event.isFailure,
              let reply = AIReplyClient.ollamaReply(baseURL: baseURL, model: model, event: event, context: context)
        else {
            return fallbackResponse
        }
        return PetResponse(state: fallbackResponse.state, message: reply, isUrgent: fallbackResponse.isUrgent)
    }
}

public enum ResponderFactory {
    public static func makeResponder(settings: TermPetSettings) -> any PetResponder {
        switch settings.aiProvider {
        case .ruleBased:
            return RuleBasedResponder()
        case .openAICompatible:
            guard !settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return RuleBasedResponder()
            }
            return OpenAICompatibleResponder(baseURL: settings.apiBaseURL, apiKey: settings.apiKey, model: settings.openAIModel)
        case .ollama:
            guard !settings.ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return RuleBasedResponder()
            }
            return OllamaResponder(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
        }
    }
}

// ── helpers ──

private func pick(_ options: [String]) -> String {
    options.randomElement() ?? options[0]
}

private enum AIReplyClient {
    static func openAIReply(
        baseURL: String,
        apiKey: String,
        model: String,
        event: TerminalEvent,
        context: ResponderContext
    ) -> String? {
        guard let url = openAIChatURL(from: baseURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [
                ["role": "system", "content": "你是一个 macOS 终端宠物，只用中文给出一句简短、有帮助、不执行命令的回复。"],
                ["role": "user", "content": prompt(for: event, context: context)]
            ],
            "temperature": 0.7,
            "max_tokens": 120
        ])

        guard let data = perform(request) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            return nil
        }
        return cleaned(content)
    }

    static func ollamaReply(
        baseURL: String,
        model: String,
        event: TerminalEvent,
        context: ResponderContext
    ) -> String? {
        guard let url = URL(string: baseURL)?.appendingPathComponent("api/chat") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": "你是一个 macOS 终端宠物，只用中文给出一句简短、有帮助、不执行命令的回复。"],
                ["role": "user", "content": prompt(for: event, context: context)]
            ]
        ])

        guard let data = perform(request) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            return nil
        }
        return cleaned(content)
    }

    private static func openAIChatURL(from baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let path = components.path
        if !path.hasSuffix("/chat/completions") {
            components.path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
            if !components.path.hasPrefix("/") {
                components.path = "/" + components.path
            }
        }
        return components.url
    }

    private static func prompt(for event: TerminalEvent, context: ResponderContext) -> String {
        """
        性格: \(context.personality.title)
        命令: \(event.command)
        退出码: \(event.exitCode ?? -1)
        耗时毫秒: \(event.durationMs ?? 0)
        连续失败次数: \(context.repeatedFailureCount)
        请解释可能原因，并给一个简短排查方向。不要建议自动执行任何命令。
        """
    }

    private static func cleaned(_ content: String) -> String? {
        let value = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return String(value.prefix(180))
    }

    private static func perform(_ request: URLRequest) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResponseBox()
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: request) { data, _, error in
            box.set(error == nil ? data : nil)
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 6)
        task.cancel()
        session.invalidateAndCancel()
        return box.get()
    }
}

private final class ResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func set(_ value: Data?) {
        lock.lock()
        data = value
        lock.unlock()
    }

    func get() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
