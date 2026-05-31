import SwiftUI
import Combine

/// Frame-animation player for illustrated image-sprite pets.
///
/// The view model emits a `spriteClip` (look_around, tail_wag, excited_jumping,
/// …) and bumps `spriteClipNonce` to (re)trigger it; this view plays that clip's
/// frames from the asset catalog (`<asset>_<clip>_<n>`) on a fixed-rate ticker:
///   • look_around / head_tilt / tail_wag → ping-pong loop (back-and-forth)
///   • everything else                    → play once, hold, fall back to idle
///
/// The frames already encode the motion, so the procedural squash/bob knobs are
/// not applied here — only a horizontal flip to face the walking direction.
struct PetSpriteView: View {
    @ObservedObject var viewModel: PandaViewModel
    let assetName: String

    @State private var clip: PetClip = .lookAround
    @State private var position: Double = 0
    @State private var holdTicks: Int = 0

    // Clips ship all 241 source frames. The ticker MUST be @State: a
    // plain `let` is recreated on every view update, and onReceive then stacks a
    // fresh timer subscription each time — firing advance() many times per tick
    // and running the animation way too fast. @State keeps a single timer.
    private let refreshRate: Double = 60
    @State private var ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // Cache of detected frame counts per clip asset prefix, probed by walking
    // <asset>_<clip>_<n> until the asset is missing.
    private static var frameCountCache: [String: Int] = [:]

    private var frameCount: Int {
        let key = "\(assetName)_\(clip.rawValue)"
        if let cached = PetSpriteView.frameCountCache[key] {
            return cached
        }
        var n = 0
        while NSImage(named: "\(key)_\(n + 1)") != nil {
            n += 1
        }
        let count = max(n, 1)
        PetSpriteView.frameCountCache[key] = count
        return count
    }

    // Every clip ships all 241 source frames, so they play back at the native
    // 24fps with no skipping — the 60fps ticker just samples this rate smoothly.
    private func clipFps(_ clip: PetClip) -> Double {
        24
    }

    private func frameName(_ clip: PetClip, _ index: Int) -> String {
        "\(assetName)_\(clip.rawValue)_\(index + 1)"
    }

    // The looping "resting" clips ping-pong (smooth back-and-forth); the action
    // clips (excited jumping, laying down) are directional, so they play once and
    // fall back to idle.
    private var pingPongClips: Set<PetClip> { [.lookAround, .headTilt, .tailWag] }
    private var forwardLoopClips: Set<PetClip> { [] }

    private var hasFrames: Bool {
        NSImage(named: frameName(.lookAround, 0)) != nil
    }

    var body: some View {
        ZStack {
            if hasFrames {
                Image(frameName(clip, currentFrame))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 176, height: 190)
                    .scaleEffect(x: CGFloat(viewModel.walkDirection), y: 1)
            } else {
                placeholder
            }
        }
        .frame(width: 180, height: 200)
        .onAppear {
            clip = viewModel.spriteClip
        }
        .onChange(of: viewModel.spriteClipNonce) { _ in
            startClip(viewModel.spriteClip)
        }
        .onReceive(ticker) { _ in
            advance()
        }
    }

    // The frame index to show, derived from the fractional play position so each
    // clip can run at its own speed off the shared 60fps ticker.
    private var currentFrame: Int {
        let last = frameCount - 1

        if pingPongClips.contains(clip) {
            let span = Double(last)
            let cycle = position.truncatingRemainder(dividingBy: span * 2)
            let f = cycle <= span ? cycle : span * 2 - cycle
            return min(last, max(0, Int(f.rounded())))
        }

        if forwardLoopClips.contains(clip) {
            return Int(position) % frameCount
        }

        return min(last, Int(position))
    }

    private func startClip(_ newClip: PetClip) {
        clip = newClip
        position = 0
        holdTicks = 0
    }

    private func advance() {
        guard hasFrames else { return }
        position += clipFps(clip) / refreshRate

        let isOneShot = !pingPongClips.contains(clip) && !forwardLoopClips.contains(clip)
        if isOneShot && currentFrame >= frameCount - 1 {
            holdTicks += 1
            if holdTicks > 18 {
                startClip(.lookAround)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 34, weight: .light))
            Text(assetName.capitalized)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .frame(width: 150, height: 184)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        )
    }
}
