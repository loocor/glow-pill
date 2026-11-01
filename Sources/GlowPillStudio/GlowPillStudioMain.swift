import SwiftUI
import GlowPill

private extension Color {
    var rgb: SIMD3<Float> {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return SIMD3(Float(ns.redComponent), Float(ns.greenComponent), Float(ns.blueComponent))
    }
}

@main
struct GlowPillDemoApp: App {
    var body: some Scene {
        WindowGroup { StudioView() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
    }
}

private struct SliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

private struct StudioView: View {
    @State private var phrase0 = "Glow AI."
    @State private var phrase1 = "More personal."
    @State private var phrase2 = "More powerful."
    @State private var glow = 1.0
    @State private var surge = 1.0
    @State private var speed = 1.0
    @State private var typeSpeed = 53.0
    @State private var hold = 744.0
    @State private var pillWidth = 420.0
    @State private var pillHeight = 160.0
    @State private var thickness = 1.0
    @State private var tint = 100.0
    @State private var still = false
    @State private var paused = false
    @State private var loop = true
    @State private var lights = true
    @State private var run = 0
    @State private var backgroundStyle = 0
    @State private var customBackground = Color(red: 0.12, green: 0.15, blue: 0.2)

    @State private var preset = 0
    @State private var warm = Color(red: 143 / 255, green: 95 / 255, blue: 80 / 255)
    @State private var core = Color.white
    @State private var teal = Color(red: 95 / 255, green: 122 / 255, blue: 108 / 255)
    @State private var cool = Color(red: 74 / 255, green: 90 / 255, blue: 150 / 255)

    private let presets: [(String, Color, Color, Color, Color)] = [
        ("Reference", Color(red: 143 / 255, green: 95 / 255, blue: 80 / 255), .white,
         Color(red: 95 / 255, green: 122 / 255, blue: 108 / 255),
         Color(red: 74 / 255, green: 90 / 255, blue: 150 / 255)),
        ("Ember", Color(red: 180 / 255, green: 85 / 255, blue: 58 / 255),
         Color(red: 1.0, green: 241 / 255, blue: 220 / 255),
         Color(red: 138 / 255, green: 106 / 255, blue: 60 / 255),
         Color(red: 122 / 255, green: 63 / 255, blue: 92 / 255)),
        ("Ice", Color(red: 79 / 255, green: 111 / 255, blue: 160 / 255),
         Color(red: 238 / 255, green: 248 / 255, blue: 1.0),
         Color(red: 79 / 255, green: 138 / 255, blue: 150 / 255),
         Color(red: 90 / 255, green: 79 / 255, blue: 160 / 255)),
    ]

    private var phrases: [String] {
        [phrase0, phrase1, phrase2].filter { !$0.isEmpty }
    }

    private var palette: GlowPillPalette {
        GlowPillPalette(warm: warm.rgb, core: core.rgb, teal: teal.rgb, cool: cool.rgb)
    }

    var body: some View {
        HStack(spacing: 0) {
            preview
            controls
                .frame(width: 300)
                .padding(16)
                .background(Color.black.opacity(0.001))
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var preview: some View {
        ZStack {
            backdrop
            GlowPill(
                phrases: phrases.isEmpty ? ["Glow AI."] : phrases,
                width: pillWidth,
                height: pillHeight,
                timing: GlowPillTiming(typeSpeed: typeSpeed, hold: hold),
                glow: Float(glow),
                surge: Float(surge),
                speed: speed,
                still: still,
                loop: loop,
                paused: paused,
                lights: lights,
                thickness: Float(thickness),
                tint: Float(tint / 100),
                backdrop: backdrop,
                palette: palette
            )
            .id(run)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var backdrop: some View {
        if backgroundStyle == 3 {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.95, green: 0.55, blue: 0.25), location: 0),
                    .init(color: Color(red: 0.85, green: 0.25, blue: 0.45), location: 0.35),
                    .init(color: Color(red: 0.30, green: 0.35, blue: 0.90), location: 0.7),
                    .init(color: Color(red: 0.15, green: 0.75, blue: 0.70), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        } else {
            background
        }
    }

    private var background: Color {
        switch backgroundStyle {
        case 1: return .white
        case 2: return customBackground
        default: return .black
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    Text("Phrases").font(.system(size: 11, weight: .semibold))
                    TextField("Phrase 1", text: $phrase0).textFieldStyle(.roundedBorder)
                    TextField("Phrase 2", text: $phrase1).textFieldStyle(.roundedBorder)
                    TextField("Phrase 3", text: $phrase2).textFieldStyle(.roundedBorder)

                    Picker("Palette", selection: $preset) {
                        ForEach(0..<presets.count, id: \.self) { Text(presets[$0].0) }
                    }
                    .onChange(of: preset) { _, newValue in
                        let p = presets[newValue]
                        warm = p.1; core = p.2; teal = p.3; cool = p.4
                    }
                    HStack {
                        ColorPicker("Warm", selection: $warm).font(.system(size: 11))
                        ColorPicker("Core", selection: $core).font(.system(size: 11))
                    }
                    HStack {
                        ColorPicker("Teal", selection: $teal).font(.system(size: 11))
                        ColorPicker("Cool", selection: $cool).font(.system(size: 11))
                    }
                }

                Divider().overlay(Color.white.opacity(0.15))

                Group {
                    Text("Background").font(.system(size: 11, weight: .semibold))
                    Picker("Background", selection: $backgroundStyle) {
                        Text("Black").tag(0)
                        Text("White").tag(1)
                        Text("Custom").tag(2)
                        Text("Gradient").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if backgroundStyle == 2 {
                        ColorPicker("Surface color", selection: $customBackground)
                            .font(.system(size: 11))
                    }
                    SliderRow(title: "Glass darkening", value: $tint, range: 0...100, format: "%.0f%%")
                }

                Divider().overlay(Color.white.opacity(0.15))

                Group {
                    Toggle("Light curtain", isOn: $lights).font(.system(size: 11))
                    Toggle("Still (frozen liquid)", isOn: $still).font(.system(size: 11))
                    Toggle("Loop phrases", isOn: $loop).font(.system(size: 11))
                    Toggle("Paused", isOn: $paused).font(.system(size: 11))
                }

                Divider().overlay(Color.white.opacity(0.15))

                Group {
                    SliderRow(title: "Glow", value: $glow, range: 0...2, format: "%.0f%%")
                    SliderRow(title: "Surge", value: $surge, range: 0...1.5, format: "%.0f%%")
                    SliderRow(title: "Liquid speed", value: $speed, range: 0...3, format: "%.1fx")
                    SliderRow(title: "Per char", value: $typeSpeed, range: 20...200, format: "%.0f ms")
                    SliderRow(title: "Hold", value: $hold, range: 200...4000, format: "%.0f ms")
                    SliderRow(title: "Length", value: $pillWidth, range: 160...720, format: "%.0f pt")
                    SliderRow(title: "Height", value: $pillHeight, range: 48...260, format: "%.0f pt")
                    SliderRow(title: "Curtain thickness", value: $thickness, range: 0.5...2, format: "%.2fx")
                }

                Divider().overlay(Color.white.opacity(0.15))

                Button("Replay") { run += 1 }
                    .buttonStyle(.bordered)
            }
            .padding(.vertical, 2)
        }
    }
}
