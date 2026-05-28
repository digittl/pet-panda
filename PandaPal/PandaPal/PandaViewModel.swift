import SwiftUI
import Combine
import AppKit

enum PandaSize: String, CaseIterable {
    case tiny = "tiny"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case huge = "huge"

    var multiplier: CGFloat {
        switch self {
        case .tiny: return 0.55
        case .small: return 0.7
        case .medium: return 0.85
        case .large: return 1.0
        case .huge: return 1.25
        }
    }

    var label: String {
        switch self {
        case .tiny: return "Tiny"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .huge: return "Huge"
        }
    }
}

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
    @Published var bambooScale: CGFloat = 1.0
    @Published var bambooEntryOffset: CGSize = .zero
    @Published var walkStride: CGFloat = 0
    @Published var walkFootLift: CGFloat = 0
    @Published var leadingPawSide: CGFloat = -1
    @Published var walkDirection: CGFloat = 1
    @Published var isDragging: Bool = false
    @Published var dragSway: Double = 0
    @Published var size: PandaSize = .medium
    @Published var sitting: Bool = false
    @Published var cushionVisible: Bool = false
    @Published var pawsInLap: Bool = false
    @Published var greetingWave: Bool = false

    @Published var particles: [PandaParticleSpawn] = []

    // External hooks set by WindowController
    var onWander: ((CGFloat, CGFloat, TimeInterval) -> Void)?
    var onCaptureDragOffset: (() -> Void)?
    var onDragTrackMouse: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onSizeSelected: ((PandaSize) -> Void)?

    private var idleTimer: Timer?
    private var wanderTimer: Timer?
    private var activeTimers: [Timer] = []
    private var dragFlailTimer: Timer?
    private var isBusy = false

    private func registerTimer(_ timer: Timer) {
        activeTimers.append(timer)
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelActiveTimers() {
        for timer in activeTimers {
            timer.invalidate()
        }
        activeTimers.removeAll()
    }

    init() {
        scheduleNextIdle()
        scheduleNextWander(initial: true)
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
        resetTransientState()

        let reactions: [() -> Void] = [
            { self.reactHappy() },
            { self.reactGiggle() },
            { self.reactStarStruck() },
            { self.reactBoop() },
            { self.reactSurprised() },
            { self.reactDance() },
            { self.reactSpin() },
            { self.reactJump() },
            { self.reactBlowKiss() },
            { self.reactBackflip() },
            { self.reactRaspberry() },
            { self.reactHiccup() },
            { self.reactWiggleButt() },
            { self.reactShy() },
            { self.reactClap() },
            { self.reactFlex() },
            { self.reactThinking() },
            { self.reactStargaze() },
            { self.reactPhotoshoot() },
            { self.reactNuzzle() }
        ]
        reactions.randomElement()?()
    }

    func pet() {
        pat()
    }

    func feedBamboo() {
        guard !isDragging else { return }
        cancelTimers()
        resetTransientState()
        isBusy = true
        playBambooFeast(celebratory: true)
    }

    func waveHello() {
        guard !isDragging else { return }
        cancelTimers()
        resetTransientState()
        isBusy = true
        playFriendlyWave()
    }

    func danceNow() {
        guard !isDragging else { return }
        cancelTimers()
        resetTransientState()
        isBusy = true
        idleTikTokDance()
    }

    func requestSize(_ size: PandaSize) {
        onSizeSelected?(size)
    }

    // MARK: - Drag interaction

    func beginDrag() {
        cancelTimers()
        isBusy = true
        isDragging = true

        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            // Arms hang at the sides — the flail timer will swing them
            // wildly while she's airborne.
            leftArmRaised = false
            rightArmRaised = false
            eyesWide = true
            mouthShape = .ohh
            bodyOffsetY = -4
            squashScale = 1.04
        }

        startDragFlail()
    }

    private func startDragFlail() {
        dragFlailTimer?.invalidate()
        var tick = 0
        let timer = Timer(timeInterval: 0.09, repeats: true) { [weak self] _ in
            guard let self = self, self.isDragging else { return }
            tick += 1

            // Big alternating swings — both arms and both legs flail like
            // she's screaming AHHHH while being held in the air.
            let phase = tick % 2 == 0 ? 1.0 : -1.0
            let jitter = Double.random(in: -8...8)
            let legJitter = CGFloat.random(in: -3...3)

            withAnimation(.spring(response: 0.11, dampingFraction: 0.45)) {
                self.leftArmWave = phase * -34 + jitter
                self.rightArmWave = phase * 34 + jitter
                self.walkStride = CGFloat(phase) * 5 + legJitter
                self.walkFootLift = CGFloat(6 + abs(legJitter))
                self.leadingPawSide = phase > 0 ? -1 : 1
                self.headTilt = phase * 4
                self.earWiggle = CGFloat(phase * 3)
            }
        }
        dragFlailTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopDragFlail() {
        dragFlailTimer?.invalidate()
        dragFlailTimer = nil
    }

    func updateDrag(velocityX: CGFloat) {
        let clamped = max(min(velocityX, 30), -30)
        let target = Double(clamped) * 0.6
        withAnimation(.easeOut(duration: 0.12)) {
            dragSway = target
            lookDirection = CGFloat(max(min(clamped * 0.3, 8), -8))
        }
    }

    func endDrag() {
        isDragging = false
        onDragEnded?()
        stopDragFlail()

        // Sway and flailing settle to 0.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            dragSway = 0
            leftArmWave = 0
            rightArmWave = 0
            walkStride = 0
            walkFootLift = 0
            earWiggle = 0
            headTilt = 0
            lookDirection = 0
        }

        // Landing squish
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            squashScale = 0.85
            bodyOffsetY = 4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                self.squashScale = 1.06
                self.bodyOffsetY = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.squashScale = 1.0
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.eyesWide = false
                self.mouthShape = .grin
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { self.mouthShape = .smile }
            self.finishAnimation()
        }
    }

    // MARK: - Idle scheduling

    private func scheduleNextIdle() {
        idleTimer?.invalidate()
        let delay = Double.random(in: 2.5...5.5)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.playRandomIdle()
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func scheduleNextWander(initial: Bool = false) {
        wanderTimer?.invalidate()
        let delay = initial ? Double.random(in: 1.5...3.0) : Double.random(in: 8...16)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.wander()
        }
        RunLoop.main.add(timer, forMode: .common)
        wanderTimer = timer
    }

    func forceWander() {
        wander()
    }

    private func cancelTimers() {
        idleTimer?.invalidate()
        idleTimer = nil
        wanderTimer?.invalidate()
        wanderTimer = nil
        stopDragFlail()
        cancelActiveTimers()
    }

    private func finishAnimation() {
        isBusy = false
        scheduleNextIdle()
        scheduleNextWander()
    }

    private func resetTransientState() {
        withAnimation(.easeInOut(duration: 0.2)) {
            leftArmRaised = false
            rightArmRaised = false
            leftArmWave = 0
            rightArmWave = 0
            eyesClosed = false
            eyesWide = false
            eyesHeart = false
            eyesStarry = false
            mouthShape = .smile
            headTilt = 0
            bodyRoll = 0
            bodyOffsetY = 0
            squashScale = 1.0
            bounceScale = 1.0
            shadowScale = 1.0
            earWiggle = 0
            bambooVisible = false
            bambooScale = 1.0
            bambooEntryOffset = .zero
            walkStride = 0
            walkFootLift = 0
            leadingPawSide = -1
            walkDirection = 1
            blushVisible = false
            lookDirection = 0
            lookVertical = 0
            dragSway = 0
            sitting = false
            cushionVisible = false
            pawsInLap = false
            greetingWave = false
        }
    }

    private func playRandomIdle() {
        guard !isBusy else { return }
        isBusy = true

        // Repeat the light idles so they fire more often than the heavyweight
        // ones (especially the nap, which holds the panda still for a while).
        let light: [() -> Void] = [
            { self.idleBlink() },
            { self.idleDoubleBlink() },
            { self.idleWave() },
            { self.idleStretch() },
            { self.idleLookAround() },
            { self.idleYawn() },
            { self.idleEarWiggle() },
            { self.idleSneeze() },
            { self.idleHumTune() },
            { self.idleBounce() },
            { self.idleTikTokDance() }
        ]
        // idleSleep removed — napping always uses the cushion via
        // idleNapOnCushion so she's never sleeping standing on bare floor.
        let occasional: [() -> Void] = [
            { self.idleSit() },
            { self.idleRelax() },
            { self.idleNapOnCushion() }
        ]

        let pool = light + light + occasional
        pool.randomElement()?()
    }

    private func idleTikTokDance() {
        let duration: TimeInterval = 4.2
        let startedAt = Date()
        var sparkleBeat = 0

        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            mouthShape = .grin
            blushVisible = true
            eyesWide = false
            leftArmRaised = true
            rightArmRaised = true
            bodyOffsetY = -2
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let elapsed = Date().timeIntervalSince(startedAt)
            let progress = min(1.0, elapsed / duration)
            let fadeIn = min(1.0, progress / 0.12)
            let fadeOut = min(1.0, (1.0 - progress) / 0.16)
            let envelope = min(fadeIn, fadeOut)
            let shake = sin(elapsed * 2.0 * .pi * 3.4)
            let counterShake = sin(elapsed * 2.0 * .pi * 3.4 + .pi)
            let bounce = sin(elapsed * 2.0 * .pi * 1.7)
            let stepSide: CGFloat = bounce >= 0 ? -1 : 1

            self.leftArmWave = shake * 18 * envelope
            self.rightArmWave = counterShake * 18 * envelope
            self.bodyRoll = shake * 3 * envelope
            self.headTilt = counterShake * 4 * envelope
            self.bodyOffsetY = -2 - CGFloat(max(0, bounce)) * 3 * CGFloat(envelope)
            self.squashScale = 1.0 + CGFloat(abs(bounce)) * 0.035 * CGFloat(envelope)
            self.shadowScale = 1.0 - CGFloat(max(0, bounce)) * 0.12 * CGFloat(envelope)
            self.leadingPawSide = stepSide
            self.walkStride = stepSide * 4 * CGFloat(envelope)
            self.walkFootLift = CGFloat(max(0, abs(bounce))) * 4 * CGFloat(envelope)

            let currentSparkleBeat = Int(elapsed / 0.75)
            if currentSparkleBeat > sparkleBeat {
                sparkleBeat = currentSparkleBeat
                self.spawnParticle(.sparkle, at: CGSize(width: CGFloat.random(in: -22...22), height: -28))
            }

            if progress >= 1.0 {
                timer.invalidate()
                withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.leftArmWave = 0
                    self.rightArmWave = 0
                    self.bodyOffsetY = 0
                    self.headTilt = 0
                    self.bodyRoll = 0
                    self.squashScale = 1.0
                    self.shadowScale = 1.0
                    self.walkStride = 0
                    self.walkFootLift = 0
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // MARK: - Wander

    private func wander() {
        // Don't interrupt a drag; otherwise preempt idle animations so we
        // actually walk on schedule.
        if isDragging {
            scheduleNextWander()
            return
        }

        cancelTimers()
        resetTransientState()
        isBusy = true

        guard let onWander = onWander else {
            finishAnimation()
            return
        }

        let dx = CGFloat.random(in: -360 ... 360)
        let dy = CGFloat.random(in: -180 ... 180)
        let duration = Double.random(in: 1.8...2.8)
        let direction: CGFloat = dx >= 0 ? 1 : -1
        walkDirection = direction

        withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) {
            headTilt = Double(direction * 4)
            lookDirection = direction * 7
            squashScale = 0.96
            shadowScale = 1.08
            bodyOffsetY = 2
        }

        var step = 0
        let stepInterval = 0.18
        let totalSteps = max(10, Int(duration / stepInterval))
        let bobTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            step += 1
            let isEvenStep = step % 2 == 0
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                self.leadingPawSide = isEvenStep ? -1 : 1
                self.walkFootLift = isEvenStep ? 4 : 3
                self.walkStride = isEvenStep ? 3 : -3
                self.bodyOffsetY = isEvenStep ? -3 : -1
                self.squashScale = isEvenStep ? 1.01 : 0.99
                self.shadowScale = isEvenStep ? 0.9 : 1.02
                self.leftArmWave = isEvenStep ? 12 : -10
                self.rightArmWave = isEvenStep ? -12 : 10
                self.leftArmRaised = false
                self.rightArmRaised = false
            }
            if step >= totalSteps {
                timer.invalidate()
            }
        }
        registerTimer(bobTimer)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onWander(dx, dy, duration)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.32) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                self.bodyOffsetY = 0
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.headTilt = 0
                self.lookDirection = 0
                self.walkStride = 0
                self.walkFootLift = 0
                self.squashScale = 1.0
                self.shadowScale = 1.0
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
        playFriendlyWave()
    }

    private func playFriendlyWave() {
        let duration: TimeInterval = 1.8
        let startedAt = Date()

        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            greetingWave = true
            rightArmRaised = true
            mouthShape = .grin
            blushVisible = true
            headTilt = -2
            bodyOffsetY = -1
            squashScale = 1.01
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let progress = min(1.0, elapsed / duration)
            let fadeIn = min(1.0, progress / 0.18)
            let fadeOut = min(1.0, (1.0 - progress) / 0.22)
            let envelope = min(fadeIn, fadeOut)
            let wavePhase = elapsed * 2.0 * .pi * 2.7
            let bouncePhase = elapsed * 2.0 * .pi * 1.35

            self.rightArmWave = sin(wavePhase) * 10 * envelope
            self.headTilt = -2 + sin(bouncePhase) * 1.5 * envelope
            self.bodyOffsetY = -1 - CGFloat(max(0, sin(bouncePhase))) * 1.5 * CGFloat(envelope)

            if progress >= 1.0 {
                timer.invalidate()
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    self.greetingWave = false
                    self.rightArmRaised = false
                    self.rightArmWave = 0
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                    self.blushVisible = false
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    private func idleSleep() {
        withAnimation(.easeInOut(duration: 0.6)) {
            eyesClosed = true
            mouthShape = .smile
            bodyOffsetY = 4
            squashScale = 0.96
        }

        var breaths = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
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
        let timer = Timer.scheduledTimer(withTimeInterval: 0.225, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
    }

    private func idleEatBamboo() {
        playBambooFeast(celebratory: false)
    }

    private func playBambooFeast(celebratory: Bool) {
        // Bamboo flies in from upper-right toward her hands.
        bambooEntryOffset = CGSize(width: 70, height: -60)
        bambooTilt = -85
        bambooScale = 0.7
        bambooVisible = true

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            bambooEntryOffset = .zero
            bambooTilt = -20
            bambooScale = 1.0
            leftArmRaised = true
            rightArmRaised = true
            mouthShape = .ohh
            blushVisible = celebratory
            lookDirection = 4
            lookVertical = -2
            bodyOffsetY = -2
        }

        var chomps = 0
        let maxChomps = celebratory ? 8 : 6
        let timer = Timer.scheduledTimer(withTimeInterval: 0.39, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            chomps += 1
            let biteIn = chomps % 2 != 0
            withAnimation(.spring(response: 0.18, dampingFraction: 0.62)) {
                self.mouthShape = chomps % 2 == 0 ? .grin : .ohh
                self.bambooTilt = biteIn ? -30 : -16
                self.bambooScale = biteIn ? 0.92 : 1.04
                self.headTilt = biteIn ? 3 : -2
                self.bodyOffsetY = biteIn ? 1 : -3
                self.squashScale = biteIn ? 0.98 : 1.03
                self.lookDirection = biteIn ? -4 : 2
            }
            if chomps % 2 == 0 {
                self.spawnParticle(.bambooLeaf, at: CGSize(width: 8, height: -8))
            }
            if celebratory && chomps == maxChomps - 1 {
                self.spawnParticle(.sparkle, at: CGSize(width: -18, height: -28))
                self.spawnParticle(.sparkle, at: CGSize(width: 18, height: -32))
            }
            if chomps >= maxChomps {
                timer.invalidate()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    self.bambooVisible = false
                    self.bambooScale = 1.0
                    self.bambooEntryOffset = .zero
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.mouthShape = celebratory ? .grin : .smile
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                    self.lookDirection = 0
                    self.blushVisible = false
                }
                if celebratory {
                    self.spawnParticle(.heart, at: CGSize(width: 0, height: -38))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.mouthShape = .smile
                        }
                        self.finishAnimation()
                    }
                } else {
                    self.finishAnimation()
                }
            }
        }
        registerTimer(timer)
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
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
    }

    private func idleBounce() {
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.375, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
    }

    private func idleSit() {
        // Settle into zen lotus pose
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            cushionVisible = true
            sitting = true
            pawsInLap = true
            bodyOffsetY = 16
            squashScale = 0.92
            mouthShape = .smile
        }

        let sitDuration = Double.random(in: 18...28)

        // Occasional gentle head turns while sitting — zen contemplation
        let look1 = sitDuration * 0.25
        let look2 = sitDuration * 0.5
        let look3 = sitDuration * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + look1) {
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = -5
                self.lookVertical = -3
                self.eyesClosed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.eyesClosed = false
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + look2) {
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = 5
                self.lookVertical = 3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + look3) {
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = 0
                self.lookVertical = 0
                self.eyesClosed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.eyesClosed = false
                }
            }
        }

        // Stand back up
        DispatchQueue.main.asyncAfter(deadline: .now() + sitDuration) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                self.sitting = false
                self.cushionVisible = false
                self.pawsInLap = false
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.headTilt = 0
                self.lookVertical = 0
                self.eyesClosed = false
            }
            self.finishAnimation()
        }
    }

    private func idleNapOnCushion() {
        // Settle down, fold legs, eyes shut almost immediately.
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
            cushionVisible = true
            sitting = true
            pawsInLap = true
            bodyOffsetY = 16
            squashScale = 0.9
            eyesClosed = true
            mouthShape = .smile
            headTilt = 10
        }

        // Long, slow breathing with occasional 💤
        let napBreaths = Int.random(in: 70...110)
        var breaths = 0
        let timer = Timer(timeInterval: 2.7, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 1.6)) {
                self.bodyOffsetY = breaths % 2 == 0 ? 18 : 14
                self.squashScale = breaths % 2 == 0 ? 0.88 : 0.92
            }
            // Spawn 💤 every few breaths, not every one — feels less spammy
            if breaths % 3 == 0 {
                self.spawnParticle(.zzz, at: CGSize(width: 28, height: -34))
            }
            breaths += 1
            if breaths >= napBreaths {
                timer.invalidate()
                // Slowly wake
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.eyesClosed = true
                        self.headTilt = -2
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.eyesClosed = false
                        self.mouthShape = .yawn
                        self.squashScale = 0.95
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.mouthShape = .smile
                        self.headTilt = 0
                    }
                }
                // Stand up in stages — paws unfold first, then she pushes off
                // the cushion, then the cushion fades. Avoids the abrupt
                // "pop back to normal" snap.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        self.pawsInLap = false
                        self.squashScale = 0.96
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.9) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        self.sitting = false
                        self.bodyOffsetY = 4
                        self.squashScale = 1.04
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        self.cushionVisible = false
                        self.bodyOffsetY = 0
                        self.squashScale = 1.0
                    }
                    self.finishAnimation()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        registerTimer(timer)
    }

    private func idleRelax() {
        // Sit zen, slow blush + occasional heart
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            cushionVisible = true
            sitting = true
            pawsInLap = true
            bodyOffsetY = 16
            squashScale = 0.92
            headTilt = -3
            mouthShape = .smile
            blushVisible = true
        }

        let relaxDuration = Double.random(in: 14...20)

        // Drift the head gently
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.25) {
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.5) {
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = -4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.75) {
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = 2 }
        }

        // Hearts drift up occasionally
        let beats = 4
        for i in 0..<beats {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + Double(i) * (relaxDuration / Double(beats))) {
                self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -16...16), height: -28))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                self.sitting = false
                self.cushionVisible = false
                self.pawsInLap = false
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.headTilt = 0
                self.blushVisible = false
            }
            self.finishAnimation()
        }
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
        let timer = Timer.scheduledTimer(withTimeInterval: 0.27, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
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
        let timer = Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] timer in
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
        registerTimer(timer)
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

    private func reactBlowKiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            rightArmRaised = true
            rightArmWave = -40
            mouthShape = .ohh
            eyesClosed = true
            blushVisible = true
            headTilt = -5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.rightArmWave = 10
            }
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) {
                    self.spawnParticle(.heart, at: CGSize(width: 30 + CGFloat(i) * 8, height: -10 - CGFloat(i) * 12))
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.rightArmRaised = false
                self.rightArmWave = 0
                self.mouthShape = .smile
                self.eyesClosed = false
                self.blushVisible = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    private func reactBackflip() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
            squashScale = 0.85
            mouthShape = .ohh
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.6)) {
                self.bodyRoll = -360
                self.bodyOffsetY = -24
                self.squashScale = 1.05
                self.shadowScale = 0.65
                self.eyesClosed = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.bodyRoll = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                self.bodyOffsetY = 0
                self.shadowScale = 1.1
                self.squashScale = 0.92
                self.eyesClosed = false
                self.mouthShape = .grin
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -34))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.squashScale = 1.0
                self.shadowScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func reactRaspberry() {
        withAnimation(.easeInOut(duration: 0.25)) {
            mouthShape = .yawn
            eyesClosed = true
            headTilt = -10
            blushVisible = true
        }
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.1) {
                self.spawnParticle(.sparkle, at: CGSize(width: 15 + CGFloat(i) * 5, height: 4))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.mouthShape = .grin
                self.eyesClosed = false
                self.headTilt = 0
                self.blushVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func reactHiccup() {
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.675, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.spring(response: 0.16, dampingFraction: 0.4)) {
                self.bodyOffsetY = -12
                self.squashScale = 1.08
                self.eyesWide = true
                self.mouthShape = .ohh
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                    self.eyesWide = false
                    self.mouthShape = .smile
                }
            }
            i += 1
            if i >= 3 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.finishAnimation()
                }
            }
        }
        registerTimer(timer)
    }

    private func reactWiggleButt() {
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.24, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.14)) {
                self.bodyRoll = i % 2 == 0 ? 6 : -6
                self.headTilt = i % 2 == 0 ? -3 : 3
                self.mouthShape = .grin
            }
            i += 1
            if i >= 8 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.bodyRoll = 0
                    self.headTilt = 0
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    private func reactShy() {
        withAnimation(.easeInOut(duration: 0.35)) {
            blushVisible = true
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -50
            rightArmWave = 50
            mouthShape = .smile
            headTilt = 8
            lookDirection = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.leftArmWave = -30
                self.rightArmWave = 30
                self.lookDirection = 4
                self.headTilt = -4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.blushVisible = false
                self.headTilt = 0
                self.lookDirection = 0
            }
            self.finishAnimation()
        }
    }

    private func reactClap() {
        var i = 0
        withAnimation(.easeInOut(duration: 0.2)) {
            mouthShape = .grin
            leftArmRaised = true
            rightArmRaised = true
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 0.27, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.14)) {
                self.leftArmWave = i % 2 == 0 ? 30 : 0
                self.rightArmWave = i % 2 == 0 ? -30 : 0
                self.bodyOffsetY = i % 2 == 0 ? -4 : 0
            }
            if i % 2 == 1 {
                self.spawnParticle(.sparkle, at: CGSize(width: CGFloat.random(in: -20...20), height: 5))
            }
            i += 1
            if i >= 7 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.leftArmWave = 0
                    self.rightArmWave = 0
                    self.bodyOffsetY = 0
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    private func reactFlex() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -75
            rightArmWave = 75
            squashScale = 1.08
            mouthShape = .grin
            eyesWide = true
            headTilt = -3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.spawnParticle(.sparkle, at: CGSize(width: -32, height: -8))
            self.spawnParticle(.sparkle, at: CGSize(width: 32, height: -8))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.headTilt = 3
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -34))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.squashScale = 1.0
                self.mouthShape = .smile
                self.eyesWide = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    private func reactThinking() {
        withAnimation(.easeInOut(duration: 0.3)) {
            rightArmRaised = true
            rightArmWave = -20
            headTilt = -8
            lookVertical = -6
            mouthShape = .ohh
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.spawnParticle(.sparkle, at: CGSize(width: -22, height: -34))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.lookVertical = 4
                self.headTilt = 6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.rightArmRaised = false
                self.rightArmWave = 0
                self.headTilt = 0
                self.lookVertical = 0
                self.mouthShape = .grin
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -36))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.mouthShape = .smile }
                self.finishAnimation()
            }
        }
    }

    private func reactStargaze() {
        withAnimation(.easeInOut(duration: 0.5)) {
            lookVertical = -10
            headTilt = -8
            mouthShape = .ohh
            eyesStarry = true
        }
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                self.spawnParticle(.star, at: CGSize(width: CGFloat.random(in: -30...30), height: -50 + CGFloat.random(in: -10...10)))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.lookVertical = 0
                self.headTilt = 0
                self.eyesStarry = false
                self.mouthShape = .smile
            }
            self.finishAnimation()
        }
    }

    private func reactPhotoshoot() {
        // Pose 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            leftArmRaised = true
            leftArmWave = 20
            headTilt = -8
            mouthShape = .grin
            eyesClosed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.spawnParticle(.sparkle, at: CGSize(width: -30, height: -30))
        }
        // Pose 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                self.leftArmRaised = false
                self.rightArmRaised = true
                self.rightArmWave = -20
                self.headTilt = 8
                self.eyesClosed = false
                self.eyesWide = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            self.spawnParticle(.sparkle, at: CGSize(width: 30, height: -30))
        }
        // Pose 3 — finger guns / point
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                self.leftArmRaised = true
                self.rightArmRaised = true
                self.leftArmWave = -10
                self.rightArmWave = 10
                self.headTilt = -4
                self.eyesWide = false
                self.mouthShape = .ohh
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.headTilt = 0
                self.mouthShape = .smile
            }
            self.finishAnimation()
        }
    }

    private func reactNuzzle() {
        var i = 0
        withAnimation { mouthShape = .grin; blushVisible = true; eyesClosed = true }
        let timer = Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.headTilt = i % 2 == 0 ? -12 : 12
                self.bodyOffsetY = i % 2 == 0 ? -2 : 0
            }
            if i % 2 == 0 {
                self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -10...10), height: -30))
            }
            i += 1
            if i >= 6 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.eyesClosed = false
                    self.blushVisible = false
                    self.mouthShape = .smile
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
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
