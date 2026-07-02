import SwiftUI
import TermPetCore

struct PetInfoPanel: View {
    @ObservedObject var model: AppModel
    @State private var customReminderText = ""
    @State private var customReminderMinutes = 15.0
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TermPet")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TabView {
                systemStatusTab
                    .tabItem {
                        Label("系统", systemImage: "gauge.with.dots.needle.33percent")
                    }
                eventsTab
                    .tabItem {
                        Label("事件", systemImage: "terminal")
                    }
                remindersTab
                    .tabItem {
                        Label("提醒", systemImage: "bell")
                    }
            }
            .frame(height: 280)
        }
        .frame(width: 340)
    }

    // MARK: - System Status

    private var systemStatusTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = model.latestSystemSnapshot {
                    StatusRow(
                        label: "CPU",
                        value: "\(Int(snapshot.cpuUsage * 100))%",
                        status: snapshot.cpuUsage > 0.85 ? .warning : .normal
                    )
                    StatusRow(
                        label: "内存",
                        value: snapshot.memoryPressure.title,
                        status: snapshot.memoryPressure == .high ? .warning : .normal
                    )
                    StatusRow(
                        label: "磁盘剩余",
                        value: "\(Int(snapshot.diskFreeFraction * 100))%",
                        status: snapshot.diskFreeFraction < 0.10 ? .warning : .normal
                    )
                    if let battery = snapshot.batteryLevel {
                        StatusRow(
                            label: "电池",
                            value: "\(Int(battery * 100))%\(snapshot.isCharging ? " ⚡" : "")",
                            status: battery < 0.20 && !snapshot.isCharging ? .warning : .normal
                        )
                    } else {
                        StatusRow(label: "电池", value: "未知", status: .normal)
                    }

                    Divider()

                    if !SystemMonitorLogic.warnings(for: snapshot).isEmpty {
                        Text("⚠️ 警告")
                            .font(.subheadline.weight(.semibold))
                        ForEach(SystemMonitorLogic.warnings(for: snapshot), id: \.self) { warning in
                            Text(warning.message)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("✅ 系统状态正常")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("正在采集系统数据...")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Events

    private var eventsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if model.recentEvents.isEmpty {
                    Text("还没有终端事件。")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(model.recentEvents.enumerated()), id: \.offset) { _, event in
                        eventRow(event)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func eventRow(_ event: TerminalEvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: event.type == .commandStarted ? "play.circle" : (event.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(event.type == .commandStarted ? .blue : (event.isSuccess ? .green : .red))
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.command)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                HStack {
                    if event.type == .commandFinished {
                        Text("退出码: \(event.exitCode ?? 0)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let ms = event.durationMs {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(ms))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("运行中...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if event.type == .commandFinished, let startedAt = event.startedAt {
                Text(startedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Reminders

    private var remindersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("快捷提醒")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ReminderPreset.allCases, id: \.self) { preset in
                        Button {
                            model.reminderStore.addPreset(preset)
                        } label: {
                            Text(preset.title)
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("自定义提醒")
                    .font(.subheadline.weight(.semibold))

                TextField("提醒内容", text: $customReminderText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                HStack {
                    Text("\(Int(customReminderMinutes)) 分钟后")
                        .font(.caption)
                    Slider(value: $customReminderMinutes, in: 1...120, step: 1)
                }

                Button {
                    guard !customReminderText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    model.reminderStore.addCustomReminder(
                        text: customReminderText,
                        seconds: customReminderMinutes * 60
                    )
                    customReminderText = ""
                    customReminderMinutes = 15
                } label: {
                    Text("添加提醒")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(customReminderText.trimmingCharacters(in: .whitespaces).isEmpty)

                if model.reminderStore.activeCount() > 0 {
                    Divider()
                    Text("待触发提醒")
                        .font(.subheadline.weight(.semibold))

                    ForEach(model.reminderStore.reminders.filter { !$0.isFired }) { reminder in
                        HStack {
                            Text(reminder.message)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(reminder.fireAt, style: .timer)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Button {
                                model.reminderStore.removeReminder(id: reminder.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else if ms < 60_000 {
            return String(format: "%.1fs", Double(ms) / 1000)
        } else {
            let minutes = ms / 60_000
            let seconds = (ms % 60_000) / 1000
            return "\(minutes)m\(seconds)s"
        }
    }
}

private struct StatusRow: View {
    enum Status {
        case normal
        case warning
    }

    let label: String
    let value: String
    let status: Status

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
            Spacer()
            Circle()
                .fill(status == .warning ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
        }
    }
}
