import SwiftUI
import TermPetCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var draft: TermPetSettings
    private let onSave: () -> Void

    init(model: AppModel, onSave: @escaping () -> Void = {}) {
        self.model = model
        self.onSave = onSave
        _draft = State(initialValue: model.settings)
    }

    var body: some View {
        Form {
            Picker("性格", selection: $draft.personality) {
                ForEach(PetPersonality.allCases, id: \.self) { personality in
                    Text(personality.title).tag(personality)
                }
            }

            Slider(value: $draft.petSize, in: 150...220, step: 10) {
                Text("大小")
            }

            Toggle("免打扰", isOn: $draft.doNotDisturb)

            Stepper(value: $draft.speechFrequencySeconds, in: 5...120, step: 5) {
                Text("发言间隔 \(Int(draft.speechFrequencySeconds)) 秒")
            }

            Picker("AI", selection: $draft.aiProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.title).tag(provider)
                }
            }

            TextField("API Base URL", text: $draft.apiBaseURL)
            SecureField("API Key", text: $draft.apiKey)
            TextField("OpenAI 模型名", text: $draft.openAIModel)
            TextField("Ollama URL", text: $draft.ollamaBaseURL)
            TextField("Ollama 模型名", text: $draft.ollamaModel)

            Toggle("暂停监听", isOn: $draft.isListeningPaused)

            HStack {
                Button("选择贴纸图片") {
                    selectPetImage()
                }

                Button("恢复默认贴纸") {
                    model.useDefaultPetImage()
                }
            }

            if !draft.customPetImagePath.isEmpty && !draft.customPetImagePath.hasPrefix("__") {
                Text(URL(fileURLWithPath: draft.customPetImagePath).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("正在使用默认贴纸")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("保存") {
                    model.updateSettings(draft)
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 430)
        .onReceive(model.$settings) { settings in
            draft = settings
        }
    }

    private func selectPetImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try model.importCustomPetImage(from: url)
            } catch {
                NSSound.beep()
            }
        }
    }
}
