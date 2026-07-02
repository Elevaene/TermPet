import AppKit
import SwiftUI
import TermPetCore

struct PetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            let petSize = min(max(CGFloat(model.settings.petSize), 150), 220)
            let bubbleWidth = min(max(petSize + 72, 260), 320)

            if !model.message.isEmpty {
                Text(model.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: bubbleWidth)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .allowsHitTesting(false)
            }

            PetBodyView(
                state: model.petState,
                gazeOffset: model.gazeOffset,
                customImagePath: model.settings.customPetImagePath
            )
            .frame(width: petSize, height: petSize)
            .contentShape(Rectangle())
            .onTapGesture {
                model.handleClick()
            }
        }
        .padding(8)
        .background(Color.clear)
    }
}

private struct PetBodyView: View {
    let state: PetState
    let gazeOffset: CGSize
    let customImagePath: String

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 260

            ZStack {
                if let image = petImage {
                    CustomPetImageView(image: image, state: state, gazeOffset: gazeOffset)
                        .frame(width: 220, height: 220)
                } else {
                    MissingPetImageView(state: state)
                        .frame(width: 220, height: 220)
                }
            }
            .frame(width: 260, height: 260)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private var petImage: NSImage? {
        if (customImagePath.isEmpty || customImagePath == "__bundled__"),
           let url = Bundle.module.url(forResource: "default-pet", withExtension: "png")
        {
            return NSImage(contentsOf: url)
        }

        if !customImagePath.hasPrefix("__"),
           let image = NSImage(contentsOfFile: customImagePath)
        {
            return image
        }

        return nil
    }
}

private struct CustomPetImageView: View {
    let image: NSImage
    let state: PetState
    let gazeOffset: CGSize
    @State private var floatPhase = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.20), radius: 8, y: 4)
                .scaleEffect(
                    x: floatPhase ? 1.018 : 0.994,
                    y: floatPhase ? 0.992 : 1.018,
                    anchor: .bottom
                )
                .rotationEffect(.degrees(rotationDegrees))
                .offset(
                    x: gazeOffset.width * 2.2,
                    y: (floatPhase ? -7 : 3) + gazeOffset.height * 1.2
                )

            StatusGlyphView(state: state)
                .offset(x: 6, y: -8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                floatPhase.toggle()
            }
        }
        .animation(.easeOut(duration: 0.12), value: gazeOffset)
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private var rotationDegrees: Double {
        let gazeTilt = Double(gazeOffset.width) * 0.75
        switch state {
        case .happy:
            return gazeTilt + (floatPhase ? 2.8 : -2.2)
        case .working, .waiting:
            return gazeTilt + (floatPhase ? 1.4 : -1.4)
        case .shocked:
            return gazeTilt + (floatPhase ? 3.2 : -3.2)
        case .sleeping:
            return -4
        case .idle:
            return gazeTilt
        }
    }
}

private struct MissingPetImageView: View {
    let state: PetState

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.16), radius: 8, y: 4)

            Text(symbol)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var symbol: String {
        switch state {
        case .working, .waiting: ">"
        case .happy: "OK"
        case .shocked: "!"
        case .sleeping: "Z"
        case .idle: "_"
        }
    }
}

private struct StatusGlyphView: View {
    let state: PetState

    var body: some View {
        Group {
            switch state {
            case .working, .waiting:
                ProgressView()
                    .controlSize(.small)
            case .shocked:
                Text("!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.cyan)
            case .sleeping:
                Text("Z")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.cyan)
            case .happy:
                Text("♪")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.cyan)
            case .idle:
                EmptyView()
            }
        }
    }
}
