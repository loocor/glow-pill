// Swift replica of the movements.dev "Glow Pill" component
// (@movements/react-glow-pill). The liquid light lives in
// GlowPillShader.metal; this file owns the typewriter schedule, the rainbow
// cursor, and the SwiftUI shell.

import SwiftUI

// MARK: - Palette

public struct GlowPillPalette: Equatable, Sendable {
    public var warm: SIMD3<Float>
    public var core: SIMD3<Float>
    public var teal: SIMD3<Float>
    public var cool: SIMD3<Float>

    public init(warm: SIMD3<Float>, core: SIMD3<Float>, teal: SIMD3<Float>, cool: SIMD3<Float>) {
        self.warm = warm
        self.core = core
        self.teal = teal
        self.cool = cool
    }

    public init(hexWarm: UInt32, hexCore: UInt32, hexTeal: UInt32, hexCool: UInt32) {
        self.init(
            warm: Self.linear(hexWarm),
            core: Self.linear(hexCore),
            teal: Self.linear(hexTeal),
            cool: Self.linear(hexCool))
    }

    public static let reference = GlowPillPalette(
        hexWarm: 0x8F5F50, hexCore: 0xFFFFFF, hexTeal: 0x5F7A6C, hexCool: 0x4A5A96)

    public static let ember = GlowPillPalette(
        hexWarm: 0xB4553A, hexCore: 0xFFF1DC, hexTeal: 0x8A6A3C, hexCool: 0x7A3F5C)

    public static let ice = GlowPillPalette(
        hexWarm: 0x4F6FA0, hexCore: 0xEEF8FF, hexTeal: 0x4F8A96, hexCool: 0x5A4FA0)

    private static func linear(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(
            Float((hex >> 16) & 0xFF) / 255,
            Float((hex >> 8) & 0xFF) / 255,
            Float(hex & 0xFF) / 255)
    }
}

// MARK: - Timing

public struct GlowPillTiming: Equatable, Sendable {
    public var startDelay: Double
    public var typeSpeed: Double
    public var hold: Double

    public init(startDelay: Double = 600, typeSpeed: Double = 53, hold: Double = 744) {
        self.startDelay = startDelay
        self.typeSpeed = typeSpeed
        self.hold = hold
    }
}

// MARK: - Frame state

struct GlowPillFrame: Equatable {
    var index: Int = 0
    var phrase: String = ""
    var chars: Int = 0
    var cursor: Bool = false
    var surge: Float = 0
    var warp: Float = 0
    var front: Float = 0
    var side: Float = 0
    var time: Float = 2.4
}

/// Surge envelope around a phrase swap. `e` is milliseconds relative to the
/// swap; the surge starts 240 ms before the swap and decays by +400 ms.
private func surgeEnvelope(_ e: Double) -> (surge: Double, warp: Double, front: Double) {
    if e < -240 || e > 400 { return (0, 0, 0) }
    let t = (e + 240) * 0.0032
    if e <= 40 {
        let r = (e + 240) / 280
        return (pow(r, 1.8), r, t)
    }
    let r = (e - 40) / 360
    return (pow(1 - r, 1.25), pow(1 - r, 2.2), t)
}

private func parity(_ e: Double) -> Double {
    floor(e / 2).truncatingRemainder(dividingBy: 2)
}

/// Interpolates the palette direction (warm <-> cool) between swaps.
private func sideLerp(_ e: Double, _ t: Double) -> Double {
    let r = parity(e - 1)
    let a = parity(e)
    let i = min(max((t + 150) / 300, 0), 1)
    return r + i * i * (3 - 2 * i) * (a - r)
}

/// Cursor schedule: always visible while a segment is young, then blinks
/// 600 ms on / 600 ms off once the typing has finished.
private func cursorVisible(_ e: Double, length: Int, typeSpeed: Double) -> Bool {
    if e < 0 { return false }
    let a = e - (67 + Double(max(length - 1, 0)) * typeSpeed)
    if a < 200 { return true }
    return (a - 200).truncatingRemainder(dividingBy: 1200) >= 600
}

private func scheduleFrame(
    elapsed ms: Double, lengths: [Int], phrases: [String], timing: GlowPillTiming, loop: Bool
) -> GlowPillFrame {
    let count = lengths.count
    guard count > 1, ms >= 0 else {
        return GlowPillFrame(index: 0, phrase: phrases.first ?? "", chars: lengths.first ?? 0)
    }

    if ms < timing.startDelay {
        let env = surgeEnvelope(ms - timing.startDelay)
        return GlowPillFrame(
            index: 0,
            phrase: phrases[0],
            chars: lengths[0],
            surge: Float(env.surge),
            warp: Float(env.warp),
            front: Float(env.front),
            side: Float(sideLerp(1, ms - timing.startDelay)))
    }

    var order = Array(1..<count)
    if loop { order.append(0) }
    let durations = order.map {
        67 + Double(max(lengths[$0] - 1, 0)) * timing.typeSpeed + timing.hold
    }
    let total = durations.reduce(0, +)

    var g = ms - timing.startDelay
    var loops = 0.0
    if loop {
        loops = floor(g / total)
        g -= loops * total
    } else if g >= total {
        let last = order.count - 1
        let index = order[last]
        let a = g - (total - durations[last])
        return GlowPillFrame(
            index: index,
            phrase: phrases[index],
            chars: lengths[index],
            cursor: cursorVisible(a, length: lengths[index], typeSpeed: timing.typeSpeed),
            side: Float(parity(Double(order.count))))
    }

    var step = 0
    while step < durations.count - 1, g >= durations[step] {
        g -= durations[step]
        step += 1
    }

    let index = order[step]
    let length = lengths[index]
    let chars = g < 67 ? 0 : min(length, Int(floor((g - 67) / timing.typeSpeed)) + 1)
    let remaining = durations[step] - g
    let willAdvance = loop || step < order.count - 1

    let forward = surgeEnvelope(g)
    let backward = willAdvance
        ? surgeEnvelope(-remaining)
        : (surge: 0.0, warp: 0.0, front: 0.0)
    let env = forward.surge >= backward.surge ? forward : backward

    let visit = 1 + loops * Double(order.count) + Double(step)
    let side = (willAdvance && remaining < 150)
        ? sideLerp(visit + 1, -remaining)
        : sideLerp(visit, g)

    return GlowPillFrame(
        index: index,
        phrase: phrases[index],
        chars: chars,
        cursor: cursorVisible(g, length: length, typeSpeed: timing.typeSpeed),
        surge: Float(env.surge),
        warp: Float(env.warp),
        front: Float(env.front),
        side: Float(side))
}

// MARK: - Clock

final class GlowPillClock {
    private var lastDate: Date?
    private var typingClock: Double = 0
    private var liquidClock: Double = 0

    func frame(
        at now: Date, phrases: [String], timing: GlowPillTiming, speed: Double,
        paused: Bool, loop: Bool, still: Bool, reducedMotion: Bool
    ) -> GlowPillFrame {
        if let last = lastDate {
            let delta = min(now.timeIntervalSince(last), 0.1) * 1000
            if !paused {
                typingClock += delta
                liquidClock += delta * speed
            }
        }
        lastDate = now

        let lengths = phrases.map(\.count)
        var frame = scheduleFrame(
            elapsed: typingClock, lengths: lengths, phrases: phrases,
            timing: timing, loop: loop)
        if reducedMotion {
            frame.chars = lengths[min(frame.index, lengths.count - 1)]
            frame.cursor = false
            frame.surge = 0
            frame.warp = 0
        }
        frame.time = still || reducedMotion ? 2.4 : Float(liquidClock / 1000)
        return frame
    }
}

// MARK: - View

public struct GlowPill: View {
    public var phrases: [String]
    public var width: CGFloat
    public var height: CGFloat?
    public var timing: GlowPillTiming
    public var glow: Float
    public var surge: Float
    public var speed: Double
    public var still: Bool
    public var loop: Bool
    public var paused: Bool
    public var lights: Bool
    public var thickness: Float
    public var tint: Float
    var backdrop: AnyView
    public var palette: GlowPillPalette

    @State private var clock = GlowPillClock()
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    public init(
        phrases: [String] = ["Glow AI.", "More personal.", "More powerful."],
        width: CGFloat = 320,
        height: CGFloat? = nil,
        timing: GlowPillTiming = GlowPillTiming(),
        glow: Float = 1,
        surge: Float = 1,
        speed: Double = 1,
        still: Bool = false,
        loop: Bool = true,
        paused: Bool = false,
        lights: Bool = true,
        thickness: Float = 1,
        tint: Float = 1,
        backdrop: (any View)? = nil,
        palette: GlowPillPalette = .reference
    ) {
        self.phrases = phrases
        self.width = width
        self.height = height
        self.timing = timing
        self.glow = glow
        self.surge = surge
        self.speed = speed
        self.still = still
        self.loop = loop
        self.paused = paused
        self.lights = lights
        self.thickness = thickness
        self.tint = tint
        self.backdrop = backdrop.map { AnyView($0) } ?? AnyView(Color.black)
        self.palette = palette
    }

    private static let aspect: CGFloat = 2.92

    public var body: some View {
        let height = self.height ?? width / Self.aspect
        TimelineView(.animation(minimumInterval: nil, paused: paused)) { timeline in
            let frame = clock.frame(
                at: timeline.date,
                phrases: phrases,
                timing: timing,
                speed: speed,
                paused: paused,
                loop: loop,
                still: still,
                reducedMotion: reducedMotion)

            ZStack {
                backdrop
                    .frame(width: width, height: height)
                    .layerEffect(
                        Shader(
                            function: ShaderLibrary.bundle(.module).glowPill,
                            arguments: [
                                .boundingRect,
                                .float(frame.time),
                                .float(frame.surge),
                                .float(frame.warp),
                                .float(frame.front),
                                .float(frame.side),
                                .float(glow),
                                .float(surge),
                                .float3(palette.warm.x, palette.warm.y, palette.warm.z),
                                .float3(palette.core.x, palette.core.y, palette.core.z),
                                .float3(palette.teal.x, palette.teal.y, palette.teal.z),
                                .float3(palette.cool.x, palette.cool.y, palette.cool.z),
                                .float(lights ? 1 : 0),
                                .float(thickness),
                                .float(tint),
                            ]),
                        maxSampleOffset: CGSize(width: 16, height: 16))

                textLayer(frame: frame, height: height)
                    .layerEffect(
                        Shader(
                            function: ShaderLibrary.bundle(.module).glowPillText,
                            arguments: [
                                .boundingRect,
                                .float(frame.time),
                                .float(frame.warp),
                                .float(surge),
                            ]),
                        maxSampleOffset: CGSize(width: 16, height: 16))
            }
            .frame(width: width, height: height)
        }
    }

    // The typed text is laid out against the hidden full phrase so the pill
    // center never shifts while characters appear.
    private func textLayer(frame: GlowPillFrame, height: CGFloat) -> some View {
        let fontSize = 0.31 * height
        let kerning = -0.012 * fontSize
        let base = Font.system(size: fontSize, weight: .medium)
        let typed = String(frame.phrase.prefix(frame.chars))
        return Text(frame.phrase)
            .font(base)
            .kerning(kerning)
            .hidden()
            .overlay(alignment: .leading) {
                HStack(spacing: 0.02 * height) {
                    Text(typed)
                        .font(base)
                        .kerning(kerning)
                        .foregroundColor(.white)
                    if frame.cursor {
                        RainbowCursor(height: height)
                    }
                }
                .fixedSize()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rainbow cursor

struct RainbowCursor: View {
    var height: CGFloat

    private static let rainbow = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 150 / 255, blue: 60 / 255), location: 0),
            .init(color: Color(red: 200 / 255, green: 160 / 255, blue: 190 / 255), location: 0.3),
            .init(color: Color(red: 110 / 255, green: 150 / 255, blue: 235 / 255), location: 0.55),
            .init(color: Color(red: 60 / 255, green: 210 / 255, blue: 215 / 255), location: 0.8),
            .init(color: Color(red: 90 / 255, green: 200 / 255, blue: 110 / 255), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom)

    private static let core = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 246 / 255, blue: 236 / 255), location: 0),
            .init(color: Color(red: 246 / 255, green: 250 / 255, blue: 1.0), location: 0.5),
            .init(color: Color(red: 242 / 255, green: 1.0, blue: 250 / 255), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom)

    var body: some View {
        let w = 0.037 * height
        let h = 0.44 * height
        ZStack {
            ForEach((1...7).reversed(), id: \.self) { ring in
                let spread = CGFloat(ring) / 7 * w * 0.8
                RoundedRectangle(cornerRadius: w)
                    .fill(Self.rainbow)
                    .opacity(0.09)
                    .frame(width: w + 2 * spread, height: h + 0.5 * spread)
            }
            RoundedRectangle(cornerRadius: w / 2)
                .fill(Self.core)
                .frame(width: w, height: h)
        }
    }
}
