import SwiftUI
import Combine
import AppKit

enum MouthShape {
    case smile
    case open
    case grin
    case ohh
    case yawn
}

enum PandaParticle: String, Identifiable {
    case heart
    case sparkle
    case musicNote
    case star
    case bambooLeaf
    case zzz

    var id: String { rawValue }

    var glyph: String {
        switch self {
        case .heart: return "❤️"
        case .sparkle: return "✨"
        case .musicNote: return "♪"
        case .star: return "⭐️"
        case .bambooLeaf: return "🍃"
        case .zzz: return "💤"
        }
    }
}

struct PandaParticleSpawn: Identifiable {
    let id = UUID()
    let particle: PandaParticle
    let offset: CGSize
    let driftX: CGFloat
    let lifetime: Double
}

final class PandaViewModel: ObservableObject {
    // Face / pose
    @Published var eyesClosed: Bool = false
    @Published var eyesWide: Bool = false
    @Published var eyesHeart: Bool = false
    @Published var eyesStarry: Bool = false
    @Published var mouthShape: MouthShape = .smile
    @Published var leftArmRaised: Bool = false
    @Published var rightArmRaised: Bool = false
    @Published var leftArmWave: Double = 0
    @Published var rightArmWave: Double = 0
    @Published var bodyOffsetY: CGFloat = 0
    @Published var headTilt: Double = 0
    @Published var bodyRoll: Double = 0
    @Published var lookDirection: CGFloat = 0
    @Published var lookVertical: CGFloat = 0
    @Published var blushVisible: Bool = false
    @Published var bounceScale: CGFloat = 1.0
    @Published var squashScale: CGFloat = 1.0
    @Published var earWiggle: CGFloat = 0
    @Published var shadowScale: CGFloat = 1.0
    @Published var bambooVisible: Bool = false
    @Published var bambooTilt: Double = 0

    @Published var particles: [PandaParticleSpawn] = []

    // External hook for moving the window (set by WindowController)
    var onWander: ((CGFloat, CGFloat, TimeInterval) -> Void)?

    private var idleTimer: Timer?
    private var wanderTimer: Timer?
    private var isBusy = false

    init() {
        scheduleNextIdle()
        scheduleNextWander()
    }

    deinit {
        idleTimer?.invalidate()
        wanderTimer?.invalidate()
    }

    // MARK: - Public interactions

    func pat() {
        guard !isBusy else {
            // Quick extra squish for repeated taps
            quickSquish()
            return
        }
        isBusy = true
        cancelTimers()

        let reactions: [() -> Void] = [
            { self.reactHappy() },
            { self.reactGiggle() },
            { self.reactStarStruck() },
            { self.reactBoop() },
            { self.reactSurprised() },
            { self.reactDance() },
            { self.reactSpin() },
            { self.reactJump() }
        ]
        reactions.randomElement()?()
    }

    // MARK: - Idle scheduling

    private func scheduleNextIdle() {
        idleTimer?.invalidate()
        let delay = Double.random(in: 2.5...5.5)
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.playRandomIdle()
        }
    }

    private func scheduleNextWander() {
        wanderTimer?.invalidate()
        let delay = Double.random(in: 15...35)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.wander()
        }
    }

    private func cancelTimers() {
        idleTimer?.invalidate()
        idleTimer = nil
        wanderTimer?.invalidate()
        wanderTimer = nil
    }

    private func finishAnimation() {
        isBusy = false
        scheduleNextIdle()
        scheduleNextWander()
    }

    private func playRandomIdle() {
        guard !isBusy else { return }
        isBusy = true

        let pool: [() -> Void] = [
            { self.idleBlink() },
            { self.idleDoubleBlink() },
            { self.idleWave() },
            { self.idleSleep() },
            { self.idleStretch() },
            { self.idleLookAround() },
            { self.idleYawn() },
            { self.idleEarWiggle() },
            { self.idleEatBamboo() },
            { self.idlePeekABoo() },
            { self.idleSneeze() },
            { self.idleHumTune() },
            { self.idleBounce() }
        ]
        pool.randomElement()?()
    }

    // MARK: - Wander

    private func wander() {
        guard !isBusy else {
            scheduleNextWander()
            return
        }
        isBusy = true

        guard let onWander = onWander else {
            finishAnimation()
            return
        }

        let dx = CGFloat.random(in: -260 ... 260)
        let dy = CGFloat.random(in: -120 ... 120)
        let duration = Double.random(in: 1.6...2.8)

        // Walk-cycle bob & little arm swing
        withAnimation(.easeInOut(duration: 0.2)) {
            headTilt = dx > 0 ? 5 : -5
            lookDirection = dx > 0 ? 6 : -6
        }

        var step = 0
        let totalSteps = Int(duration / 0.18)
        let bobTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            step += 1
            withAnimation(.easeInOut(duration: 0.18)) {
                self.bodyOffsetY = step % 2 == 0 ? -3 : 0
                self.leftArmWave = step % 2 == 0 ? 12 : -12
                self.rightArmWave = step % 2 == 0 ? -12 : 12
                self.leftArmRaised = false
                self.rightArmRaised = false
            }
            if step >= totalSteps {
                timer.invalidate()
            }
        }
        RunLoop.main.add(bobTimer, forMode: .common)

        onWander(dx, dy, duration)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.bodyOffsetY = 0
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.headTilt = 0
                self.lookDirection = 0
            }
            self.finishAnimation()
        }
    }

    // MARK: - Idle animations

    private func idleBlink() {
        blinkOnce {
            self.finishAnimation()
        }
    }

    private func idleDoubleBlink() {
        blinkOnce {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.blinkOnce { self.finishAnimation() }
            }
        }
    }

    private func blinkOnce(completion: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.08)) { eyesClosed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.08)) { self.eyesClosed = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { completion() }
        }
    }

    private func idleWave() {
        withAnimation(.easeInOut(duration: 0.3)) {
            rightArmRaised = true
            mouthShape = .grin
        }
        var waves = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            waves += 1
            withAnimation(.easeInOut(duration: 0.22)) {
                self.rightArmWave = waves % 2 == 0 ? 25 : -25
                self.headTilt = waves % 2 == 0 ? 4 : -4
            }
            if waves >= 5 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.rightArmRaised = false
                    self.rightArmWave = 0
                    self.headTilt = 0
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func idleSleep() {
        withAnimation(.easeInOut(duration: 0.6)) {
            eyesClosed = true
            mouthShape = .smile
            bodyOffsetY = 4
            squashScale = 0.96
        }

        var breaths = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.9)) {
                self.bodyOffsetY = breaths % 2 == 0 ? 6 : 4
                self.squashScale = breaths % 2 == 0 ? 0.94 : 0.97
            }
            self.spawnParticle(.zzz, at: CGSize(width: 30, height: -38))
            breaths += 1
            if breaths >= 4 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.eyesClosed = false
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func idleStretch() {
        withAnimation(.easeInOut(duration: 0.45)) {
            leftArmRaised = true
            rightArmRaised = true
            bodyOffsetY = -10
            squashScale = 1.08
            mouthShape = .ohh
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.mouthShape = .smile
            }
            self.finishAnimation()
        }
    }

    private func idleLookAround() {
        let path: [(CGFloat, CGFloat, Double)] = [
            (-9, -2, 0.5),
            (9, -2, 0.6),
            (0, 6, 0.5),
            (0, 0, 0.4)
        ]
        runLookPath(path, index: 0)
    }

    private func runLookPath(_ path: [(CGFloat, CGFloat, Double)], index: Int) {
        guard index < path.count else {
            finishAnimation()
            return
        }
        let step = path[index]
        withAnimation(.easeInOut(duration: step.2)) {
            lookDirection = step.0
            lookVertical = step.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + step.2 + 0.15) {
            self.runLookPath(path, index: index + 1)
        }
    }

    private func idleYawn() {
        withAnimation(.easeInOut(duration: 0.5)) {
            mouthShape = .yawn
            eyesClosed = true
            squashScale = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.mouthShape = .smile
                self.eyesClosed = false
                self.squashScale = 1.0
            }
            self.finishAnimation()
        }
    }

    private func idleEarWiggle() {
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.14)) {
                self.earWiggle = i % 2 == 0 ? 3 : -3
            }
            i += 1
            if i >= 6 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.2)) { self.earWiggle = 0 }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func idleEatBamboo() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bambooVisible = true
            bambooTilt = -20
            leftArmRaised = true
            rightArmRaised = true
            mouthShape = .grin
        }

        var chomps = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            chomps += 1
            withAnimation(.easeInOut(duration: 0.18)) {
                self.mouthShape = chomps % 2 == 0 ? .grin : .ohh
                self.bambooTilt = chomps % 2 == 0 ? -20 : -28
                self.headTilt = chomps % 2 == 0 ? -2 : 2
            }
            if chomps % 2 == 0 {
                self.spawnParticle(.bambooLeaf, at: CGSize(width: 8, height: -8))
            }
            if chomps >= 6 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.bambooVisible = false
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.mouthShape = .smile
                    self.headTilt = 0
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func idlePeekABoo() {
        withAnimation(.easeInOut(duration: 0.35)) {
            leftArmRaised = true
            rightArmRaised = true
            eyesClosed = true
            leftArmWave = -60
            rightArmWave = 60
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.eyesClosed = false
                self.eyesWide = true
                self.leftArmWave = -30
                self.rightArmWave = 30
                self.mouthShape = .ohh
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.eyesWide = false
                self.mouthShape = .grin
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func idleSneeze() {
        // Wind up
        withAnimation(.easeInOut(duration: 0.5)) {
            squashScale = 1.1
            headTilt = -20
            eyesClosed = true
            mouthShape = .ohh
        }
        // Achoo!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
                self.squashScale = 0.9
                self.headTilt = 25
                self.bodyOffsetY = -6
                self.mouthShape = .open
            }
            for i in 0..<5 {
                self.spawnParticle(.sparkle, at: CGSize(width: CGFloat.random(in: -20...20), height: -30 - CGFloat(i) * 4))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.squashScale = 1.0
                self.headTilt = 0
                self.bodyOffsetY = 0
                self.eyesClosed = false
                self.mouthShape = .smile
            }
            self.finishAnimation()
        }
    }

    private func idleHumTune() {
        withAnimation(.easeInOut(duration: 0.3)) {
            mouthShape = .ohh
        }
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.35)) {
                self.headTilt = i % 2 == 0 ? 6 : -6
                self.bodyOffsetY = i % 2 == 0 ? -2 : 2
            }
            self.spawnParticle(.musicNote, at: CGSize(width: i % 2 == 0 ? 22 : -22, height: -30))
            i += 1
            if i >= 5 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func idleBounce() {
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                self.bodyOffsetY = -10
                self.squashScale = 0.95
                self.shadowScale = 0.7
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                    self.bodyOffsetY = 0
                    self.squashScale = 1.08
                    self.shadowScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.squashScale = 1.0
                        self.shadowScale = 1.0
                    }
                }
            }
            i += 1
            if i >= 3 {
                timer.invalidate()
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Pat reactions (random)

    private func reactHappy() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            bounceScale = 1.18
            blushVisible = true
            mouthShape = .grin
        }
        for _ in 0..<3 {
            spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -25...25), height: -40))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { self.bounceScale = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.blushVisible = false
                self.mouthShape = .smile
            }
            self.finishAnimation()
        }
    }

    private func reactGiggle() {
        withAnimation { mouthShape = .grin; eyesClosed = true; blushVisible = true }
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.16)) {
                self.headTilt = i % 2 == 0 ? 7 : -7
                self.bounceScale = i % 2 == 0 ? 1.08 : 0.96
            }
            i += 1
            if i >= 6 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headTilt = 0
                    self.bounceScale = 1.0
                    self.eyesClosed = false
                    self.blushVisible = false
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func reactStarStruck() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            eyesStarry = true
            mouthShape = .ohh
            bounceScale = 1.12
        }
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                self.spawnParticle(.sparkle, at: CGSize(width: CGFloat.random(in: -30...30), height: CGFloat.random(in: -50 ... -10)))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.eyesStarry = false
                self.mouthShape = .smile
                self.bounceScale = 1.0
            }
            self.finishAnimation()
        }
    }

    private func reactBoop() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            squashScale = 0.85
            eyesWide = true
            mouthShape = .ohh
            headTilt = -8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                self.squashScale = 1.05
                self.headTilt = 4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.squashScale = 1.0
                self.eyesWide = false
                self.mouthShape = .grin
                self.headTilt = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func reactSurprised() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
            bodyOffsetY = -14
            squashScale = 1.12
            eyesWide = true
            mouthShape = .ohh
            leftArmRaised = true
            rightArmRaised = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.eyesWide = false
                self.mouthShape = .smile
                self.leftArmRaised = false
                self.rightArmRaised = false
            }
            self.finishAnimation()
        }
    }

    private func reactDance() {
        withAnimation { mouthShape = .grin; blushVisible = true }
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.headTilt = i % 2 == 0 ? 10 : -10
                self.bodyRoll = i % 2 == 0 ? 4 : -4
                self.leftArmRaised = i % 2 == 0
                self.rightArmRaised = i % 2 == 1
                self.bodyOffsetY = i % 2 == 0 ? -6 : 0
            }
            if i % 2 == 0 {
                self.spawnParticle(.musicNote, at: CGSize(width: -28, height: -32))
            } else {
                self.spawnParticle(.musicNote, at: CGSize(width: 28, height: -32))
            }
            i += 1
            if i >= 8 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headTilt = 0
                    self.bodyRoll = 0
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.bodyOffsetY = 0
                    self.blushVisible = false
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func reactSpin() {
        withAnimation(.easeInOut(duration: 0.7)) {
            bodyRoll = 360
            mouthShape = .grin
            eyesClosed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.bodyRoll = 0
            withAnimation(.easeInOut(duration: 0.3)) {
                self.eyesClosed = false
                self.mouthShape = .smile
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -40))
            self.finishAnimation()
        }
    }

    private func reactJump() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
            squashScale = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.bodyOffsetY = -28
                self.squashScale = 1.1
                self.shadowScale = 0.6
                self.mouthShape = .ohh
                self.leftArmRaised = true
                self.rightArmRaised = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                self.bodyOffsetY = 0
                self.squashScale = 0.95
                self.shadowScale = 1.1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.squashScale = 1.0
                self.shadowScale = 1.0
                self.mouthShape = .grin
                self.leftArmRaised = false
                self.rightArmRaised = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func quickSquish() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
            squashScale = 0.92
            bounceScale = 1.06
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.squashScale = 1.0
                self.bounceScale = 1.0
            }
        }
    }

    // MARK: - Particles

    private func spawnParticle(_ kind: PandaParticle, at offset: CGSize) {
        let spawn = PandaParticleSpawn(
            particle: kind,
            offset: offset,
            driftX: CGFloat.random(in: -15...15),
            lifetime: Double.random(in: 1.0...1.6)
        )
        particles.append(spawn)
        DispatchQueue.main.asyncAfter(deadline: .now() + spawn.lifetime + 0.1) {
            self.particles.removeAll { $0.id == spawn.id }
        }
    }
}
