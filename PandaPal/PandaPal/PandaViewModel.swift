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

enum PandaGender: String, CaseIterable {
    case girl
    case boy

    var label: String {
        switch self {
        case .girl: return "Girl"
        case .boy: return "Boy"
        }
    }
}

// Which animal is currently on screen. The view-model is shared across all
// kinds — each PetKind picks a different SwiftUI body to render but reads the
// same eyes / mouth / arm-wave / drag state, so all the existing animations
// translate directly. Pet-specific accessories (panda's bamboo + cushion,
// turtle's shell retract, budgie's wings, puppy's tail) are layered on top.
enum PetKind: String, CaseIterable {
    case panda
    case puppy
    case turtle
    case budgie

    var label: String {
        switch self {
        case .panda: return "Panda"
        case .puppy: return "Puppy"
        case .turtle: return "Turtle"
        case .budgie: return "Budgie"
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
    @Published var gender: PandaGender = .girl
    @Published var kind: PetKind = .panda
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
    // The controller owns mouse + window access, so it drives the chase loop:
    // it walks the window toward the live cursor and calls back into the model
    // (updateChaseFacing / catchPrey) for the matching leg + pounce animation.
    var onChaseStart: (() -> Void)?

    private var idleTimer: Timer?
    private var wanderTimer: Timer?
    private var blinkTimer: Timer?
    // True only while an ambient blink owns the eyelids, so the auto-reopen
    // never fights an animation that deliberately closed/opened her eyes.
    private var ambientBlinkActive = false
    private var activeTimers: [Timer] = []
    private var dragFlailTimer: Timer?
    private var chaseWalkTimer: Timer?
    private var isBusy = false
    // Timestamp of her last self-initiated cursor hunt, used to keep autonomous
    // chases to at most one every 45 minutes. (Menu "Chase" ignores this.)
    private var lastAutoChase: Date?
    private let autoChaseCooldown: TimeInterval = 45 * 60

    // True while she's resting on the cushion (sit / relax / nap). The cushion
    // poses run on dispatch chains rather than cancellable timers, so they check
    // this before each staged step and bail if she's been woken early.
    private var isResting = false

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
        scheduleNextBlink()
    }

    deinit {
        idleTimer?.invalidate()
        wanderTimer?.invalidate()
        blinkTimer?.invalidate()
    }

    // MARK: - Public interactions

    func pat() {
        // A tap while she's resting on the cushion startles her awake instead
        // of running a normal pat reaction.
        if isResting || sitting || cushionVisible {
            wakeStartled()
            return
        }

        guard !isBusy else {
            // Quick extra squish for repeated taps
            quickSquish()
            return
        }
        isBusy = true
        cancelTimers()
        resetTransientState()

        // Clicking her is petting her — every tap is a little burst of
        // affection. The 15 reactions below are all cuddly by design; the
        // showier tricks (spin, backflip, flex, …) live in the idle pool now
        // so she does them on her own time, not when she's being loved on.
        let pettingReactions: [() -> Void] = [
            { self.reactHappy() },
            { self.reactGiggle() },
            { self.reactStarStruck() },
            { self.reactBoop() },
            { self.reactBlowKiss() },
            { self.reactShy() },
            { self.reactNuzzle() },
            { self.petMelt() },
            { self.petLeanIn() },
            { self.petPurr() },
            { self.petEarFlutter() },
            { self.petChinUp() },
            { self.petSnuggle() },
            { self.petSwoon() },
            { self.petTippyTaps() },
            { self.petHeartEyes() },
            { self.petWiggleHappy() },
            { self.petHop() },
            { self.petSpinJoy() },
            { self.petPeekaboo() },
            { self.petBlep() },
            { self.petRollOver() },
            { self.petStarryGaze() },
            { self.petHumSway() },
            { self.petBounceClaps() },
            { self.petBigStretch() },
            { self.petShiver() },
            { self.petHeadBob() },
            { self.petFlop() }
        ]
        pettingReactions.randomElement()?()
    }

    func pet() {
        pat()
    }

    func feedBamboo() {
        guard !isDragging else { return }
        cancelTimers()
        resetTransientState()
        isBusy = true
        playBambooFeast()
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

    func chaseNow() {
        chaseMouse()
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

    // An ambient blink runs on its own clock at a natural human rate (~every
    // 3–5s), completely independent of the animation lifecycle — she keeps
    // blinking no matter what else she's doing. cancelTimers() never touches it.
    private func scheduleNextBlink() {
        blinkTimer?.invalidate()
        let delay = Double.random(in: 2.8...5.4)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.ambientBlink()
            self?.scheduleNextBlink()
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func ambientBlink() {
        // Only blink from her normal open-eyed state — never override an
        // animation that's deliberately holding her eyes closed/heart/starry,
        // and never blink while she's resting with her eyes already shut.
        guard !eyesClosed, !eyesHeart, !eyesStarry, !isResting else { return }

        ambientBlinkActive = true
        withAnimation(.easeInOut(duration: 0.07)) {
            eyesClosed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // If anything else grabbed the eyelids during the blink, leave them be.
            guard self.ambientBlinkActive else { return }
            self.ambientBlinkActive = false
            withAnimation(.easeInOut(duration: 0.07)) {
                self.eyesClosed = false
            }
        }
    }

    private func scheduleNextWander(initial: Bool = false) {
        wanderTimer?.invalidate()
        // Roam more often than the original 8...16s, but not constantly.
        let delay = initial ? Double.random(in: 1.5...3.0) : Double.random(in: 6...12)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.roam()
        }
        RunLoop.main.add(timer, forMode: .common)
        wanderTimer = timer
    }

    // Decide what a scheduled roam does: almost always a casual stroll, but
    // every once in a while she locks onto the cursor and hunts it down.
    private func roam() {
        // Never cut a cushion session short — let her finish resting and try
        // again later. (Explicit menu Walk/Chase can still interrupt.)
        if sitting || cushionVisible {
            scheduleNextWander()
            return
        }

        // Only hunt if the cooldown has elapsed, and even then only some of the
        // time so it doesn't fire like clockwork right on the hour.
        let cooldownElapsed = lastAutoChase.map { Date().timeIntervalSince($0) >= autoChaseCooldown } ?? true
        if onChaseStart != nil && cooldownElapsed && Int.random(in: 0..<5) == 0 {
            lastAutoChase = Date()
            chaseMouse()
        } else {
            wander()
        }
    }

    func forceWander() {
        wander()
    }

    private func cancelTimers() {
        idleTimer?.invalidate()
        idleTimer = nil
        wanderTimer?.invalidate()
        wanderTimer = nil
        chaseWalkTimer?.invalidate()
        chaseWalkTimer = nil
        stopDragFlail()
        cancelActiveTimers()
    }

    private func finishAnimation() {
        isBusy = false
        scheduleNextIdle()
        scheduleNextWander()
    }

    private func resetTransientState() {
        // A starting animation owns the eyelids now — drop any pending blink
        // reopen so it can't flicker mid-animation.
        ambientBlinkActive = false

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
        isResting = false
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

        // The showy tricks used to fire on tap; now that tapping is petting,
        // they live here so she performs them spontaneously while idle.
        let tricks: [() -> Void] = [
            { self.reactSurprised() },
            { self.reactDance() },
            { self.reactSpin() },
            { self.reactJump() },
            { self.reactBackflip() },
            { self.reactRaspberry() },
            { self.reactHiccup() },
            { self.reactWiggleButt() },
            { self.reactClap() },
            { self.reactFlex() },
            { self.reactThinking() },
            { self.reactStargaze() },
            { self.reactPhotoshoot() }
        ]

        let pool = light + light + tricks + occasional
        pool.randomElement()?()
    }

    private func idleTikTokDance() {
        let duration: TimeInterval = 5.4
        let startedAt = Date()
        var sparkleBeat = 0

        // She never dances on the cushion — clear any lingering rest pose first.
        if sitting || cushionVisible || pawsInLap {
            sitting = false
            cushionVisible = false
            pawsInLap = false
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            mouthShape = .grin
            blushVisible = true
            eyesWide = false
            leftArmRaised = true
            rightArmRaised = true
            bodyOffsetY = -3
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let elapsed = Date().timeIntervalSince(startedAt)
            let progress = min(1.0, elapsed / duration)
            let fadeIn = min(1.0, progress / 0.1)
            let fadeOut = min(1.0, (1.0 - progress) / 0.14)
            let envelope = min(fadeIn, fadeOut)
            let armFreq = 4.2
            let bounceFreq = 2.1
            let hipFreq = 1.05
            let shake = sin(elapsed * 2.0 * .pi * armFreq)
            let counterShake = sin(elapsed * 2.0 * .pi * armFreq + .pi)
            let bounce = sin(elapsed * 2.0 * .pi * bounceFreq)
            let hipSway = sin(elapsed * 2.0 * .pi * hipFreq)
            let stepSide: CGFloat = hipSway >= 0 ? 1 : -1

            self.leftArmWave = shake * 24 * envelope
            self.rightArmWave = counterShake * 24 * envelope
            self.bodyRoll = hipSway * 7 * envelope
            self.headTilt = -hipSway * 9 * envelope + shake * 2 * envelope
            self.bodyOffsetY = -3 - CGFloat(max(0, bounce)) * 6 * CGFloat(envelope)
            self.squashScale = 1.0 + CGFloat(max(0, -bounce)) * 0.06 * CGFloat(envelope)
            self.shadowScale = 1.0 - CGFloat(max(0, bounce)) * 0.18 * CGFloat(envelope)
            self.leadingPawSide = stepSide
            self.walkStride = CGFloat(hipSway) * 7 * CGFloat(envelope)
            self.walkFootLift = CGFloat(max(0, bounce)) * 6 * CGFloat(envelope)

            let currentSparkleBeat = Int(elapsed / 0.4)
            if currentSparkleBeat > sparkleBeat {
                sparkleBeat = currentSparkleBeat
                self.spawnParticle(.sparkle, at: CGSize(width: CGFloat.random(in: -28...28), height: CGFloat.random(in: -34 ... -10)))
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

    // MARK: - Chase the cursor

    private func chaseMouse() {
        // Don't interrupt a drag — try again later.
        if isDragging {
            scheduleNextWander()
            return
        }

        cancelTimers()
        resetTransientState()
        isBusy = true

        guard let onChaseStart = onChaseStart else {
            finishAnimation()
            return
        }

        // Lock on: wide eyes, determined grin, low pounce-ready crouch.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            eyesWide = true
            mouthShape = .grin
            bodyOffsetY = 2
            shadowScale = 1.08
        }

        startChaseWalkCycle()
        onChaseStart()
    }

    private func startChaseWalkCycle() {
        chaseWalkTimer?.invalidate()

        var step = 0

        // Faster, more urgent stride than the casual wander bob.
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            step += 1
            let isEvenStep = step % 2 == 0
            withAnimation(.spring(response: 0.16, dampingFraction: 0.86)) {
                self.leadingPawSide = isEvenStep ? -1 : 1
                self.walkFootLift = isEvenStep ? 7 : 5
                self.walkStride = isEvenStep ? 6 : -6
                self.bodyOffsetY = isEvenStep ? -4 : -1
                self.squashScale = isEvenStep ? 1.02 : 0.98
                self.shadowScale = isEvenStep ? 0.88 : 1.04
                self.leftArmWave = isEvenStep ? 18 : -16
                self.rightArmWave = isEvenStep ? -18 : 16
            }
        }
        chaseWalkTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // Called by the controller each frame so she always faces where she's headed.
    func updateChaseFacing(_ direction: CGFloat) {
        guard direction != 0, direction != walkDirection else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            walkDirection = direction
            headTilt = Double(direction * 4)
            lookDirection = direction * 7
        }
    }

    // Called by the controller once she's on top of the cursor — the pounce.
    func catchPrey() {
        chaseWalkTimer?.invalidate()
        chaseWalkTimer = nil
        playPounce()
    }

    private func playPounce() {
        // 1. Crouch low and coil up — eyes locked on, paws planted.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            walkStride = 0
            walkFootLift = 0
            leftArmRaised = false
            rightArmRaised = false
            leftArmWave = 0
            rightArmWave = 0
            squashScale = 0.78
            bodyOffsetY = 12
            eyesWide = true
            mouthShape = .grin
            lookDirection = 0
            lookVertical = 4
            headTilt = 0
        }

        // 2. Wind-up: the little cat butt-wiggle right before the leap.
        let wiggles: [(Double, Double, CGFloat)] = [
            (0.14, 5, 3),
            (0.26, -5, -3),
            (0.38, 4, 2)
        ]
        for (delay, roll, ears) in wiggles {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.bodyRoll = roll
                    self.earWiggle = ears
                    self.squashScale = 0.76
                }
            }
        }

        // 3. LEAP — explode up and forward, arms thrown wide to grab.
        // Kept within the same vertical envelope as reactJump so her head and
        // raised paws don't clip the top of the window during the leap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) {
                self.bodyRoll = 0
                self.earWiggle = 0
                self.bodyOffsetY = -26
                self.squashScale = 1.1
                self.shadowScale = 0.5
                self.leftArmRaised = true
                self.rightArmRaised = true
                self.leftArmWave = 48
                self.rightArmWave = -48
                self.mouthShape = .open
                self.lookVertical = -2
            }
        }

        // 4. SLAM — crash down onto it, arms clamp shut, impact dust flies.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.52)) {
                self.bodyOffsetY = 14
                self.squashScale = 0.72
                self.shadowScale = 1.22
                self.leftArmWave = 4
                self.rightArmWave = -4
                self.mouthShape = .grin
                self.eyesClosed = true
                self.lookVertical = 6
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -8))
            self.spawnParticle(.sparkle, at: CGSize(width: -22, height: 6))
            self.spawnParticle(.sparkle, at: CGSize(width: 22, height: 6))
        }

        // 5. Rebound and peek down into her clasped paws — did she get it?
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.bodyOffsetY = 4
                self.squashScale = 1.04
                self.shadowScale = 1.06
                self.eyesClosed = false
                self.eyesWide = true
                self.mouthShape = .ohh
                self.headTilt = -6
                self.lookVertical = 8
            }
        }

        // 6. GOT IT! An excited celebration — heart eyes, arms thrown up, a
        // shower of hearts and a star.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                self.bodyOffsetY = -12
                self.squashScale = 1.1
                self.shadowScale = 0.85
                self.eyesWide = false
                self.eyesHeart = true
                self.blushVisible = true
                self.mouthShape = .grin
                self.headTilt = 0
                self.lookVertical = 0
                self.leftArmRaised = true
                self.rightArmRaised = true
                self.leftArmWave = -30
                self.rightArmWave = 30
            }
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -26...26), height: -36))
                }
            }
            self.spawnParticle(.star, at: CGSize(width: 0, height: -46))
        }

        // Two quick, giddy bounces in place — she can't contain herself.
        for (idx, delay) in [1.78, 2.06].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                    self.bodyOffsetY = -16
                    self.headTilt = idx % 2 == 0 ? -5 : 5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        self.bodyOffsetY = -6
                        self.headTilt = 0
                    }
                }
            }
        }

        // 7. Then she brings the caught bamboo up and happily munches it down.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.eatCaughtBamboo()
        }
    }

    // After the excited catch she settles her pose and tucks into the bamboo
    // she just bagged — the celebratory feast (chomps, leaves, a final heart)
    // owns the wind-down and resumes normal scheduling.
    private func eatCaughtBamboo() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            eyesHeart = false
            eyesStarry = false
            eyesWide = false
            bounceScale = 1.0
            bodyOffsetY = 0
            shadowScale = 1.0
            squashScale = 1.0
            leftArmRaised = false
            rightArmRaised = false
            leftArmWave = 0
            rightArmWave = 0
            headTilt = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.playBambooFeast()
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
        let duration: TimeInterval = 2.2
        let startedAt = Date()

        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            greetingWave = true
            rightArmRaised = true
            mouthShape = .grin
            blushVisible = true
            headTilt = -3
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
            let fadeIn = min(1.0, progress / 0.14)
            let fadeOut = min(1.0, (1.0 - progress) / 0.18)
            let envelope = min(fadeIn, fadeOut)
            let wavePhase = elapsed * 2.0 * .pi * 2.2
            let bouncePhase = elapsed * 2.0 * .pi * 1.1

            self.rightArmWave = sin(wavePhase) * 23 * envelope
            self.headTilt = -3 + sin(bouncePhase) * 3 * envelope
            self.bodyOffsetY = -1 - CGFloat(max(0, sin(bouncePhase))) * 2 * CGFloat(envelope)

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

    // She only ever eats bamboo when you feed her or when she catches it on a
    // hunt — never as a spontaneous idle, so there's no "she's just snacking
    // again" filler. Bamboo flies in from the upper-right toward her hands and
    // she happily chomps it down.
    private func playBambooFeast() {
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
            blushVisible = true
            lookDirection = 4
            lookVertical = -2
            bodyOffsetY = -2
        }

        var chomps = 0
        let maxChomps = 8
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
            if chomps == maxChomps - 1 {
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
                    self.mouthShape = .grin
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                    self.lookDirection = 0
                    self.blushVisible = false
                }
                self.spawnParticle(.heart, at: CGSize(width: 0, height: -38))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.mouthShape = .smile
                    }
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
        isResting = true
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            cushionVisible = true
            sitting = true
            pawsInLap = true
            bodyOffsetY = 16
            squashScale = 0.92
            mouthShape = .smile
        }

        let sitDuration = Double.random(in: 30...46)

        // Occasional gentle head turns while sitting — zen contemplation
        let look1 = sitDuration * 0.25
        let look2 = sitDuration * 0.5
        let look3 = sitDuration * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + look1) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = -5
                self.lookVertical = -3
                self.eyesClosed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard self.isResting else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.eyesClosed = false
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + look2) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = 5
                self.lookVertical = 3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + look3) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.headTilt = 0
                self.lookVertical = 0
                self.eyesClosed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard self.isResting else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.eyesClosed = false
                }
            }
        }

        // Stand back up
        DispatchQueue.main.asyncAfter(deadline: .now() + sitDuration) {
            guard self.isResting else { return }
            self.isResting = false
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
        isResting = true
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
        let napBreaths = Int.random(in: 30...46)
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
                    self.isResting = false
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
        isResting = true
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

        let relaxDuration = Double.random(in: 24...34)

        // Drift the head gently
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.25) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.5) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = -4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration * 0.75) {
            guard self.isResting else { return }
            withAnimation(.easeInOut(duration: 1.5)) { self.headTilt = 2 }
        }

        // Hearts drift up occasionally
        let beats = 4
        for i in 0..<beats {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + Double(i) * (relaxDuration / Double(beats))) {
                guard self.isResting else { return }
                self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -16...16), height: -28))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + relaxDuration) {
            guard self.isResting else { return }
            self.isResting = false
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

    // Tapped awake mid-rest: she startles, the cushion poofs away, then she
    // shakes it off and gives a sleepy little smile.
    private func wakeStartled() {
        isResting = false
        cancelTimers()
        isBusy = true

        // Startle — eyes snap open, a surprised hop up off the cushion.
        withAnimation(.spring(response: 0.18, dampingFraction: 0.42)) {
            eyesClosed = false
            eyesWide = true
            mouthShape = .ohh
            sitting = false
            pawsInLap = false
            bodyOffsetY = -16
            squashScale = 1.12
            headTilt = 0
            lookVertical = 0
            blushVisible = false
        }
        spawnParticle(.sparkle, at: CGSize(width: -20, height: -30))
        spawnParticle(.sparkle, at: CGSize(width: 20, height: -32))

        // Cushion poofs out from under her.
        withAnimation(.easeOut(duration: 0.3)) {
            cushionVisible = false
        }

        // Land back down.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                self.bodyOffsetY = 0
                self.squashScale = 1.0
            }
        }

        // A quick "huh?" head shake to shake off the sleep.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.16)) { self.headTilt = -9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            withAnimation(.easeInOut(duration: 0.16)) { self.headTilt = 9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.86) {
            withAnimation(.easeInOut(duration: 0.2)) { self.headTilt = 0 }
        }

        // Sleepy-but-happy: soften the eyes, blush, little heart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.eyesWide = false
                self.mouthShape = .grin
                self.blushVisible = true
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -34))
        }

        // Settle back to neutral.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.blushVisible = false
                self.mouthShape = .smile
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

    // MARK: - Petting reactions (random, tap-only)

    // She goes limp with bliss — sinks down, eyes shut into happy arcs, sighs
    // out a heart.
    private func petMelt() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            eyesClosed = true
            mouthShape = .grin
            blushVisible = true
            bodyOffsetY = 6
            squashScale = 0.9
            headTilt = 6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -30))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                self.eyesClosed = false
                self.mouthShape = .smile
                self.blushVisible = false
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // Tips her head into the hand and squints, melting into the touch.
    private func petLeanIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            headTilt = -16
            lookVertical = -3
            eyesClosed = true
            mouthShape = .grin
            blushVisible = true
            bodyOffsetY = -1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                self.headTilt = -10
                self.earWiggle = 3
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.headTilt = 0
                self.lookVertical = 0
                self.earWiggle = 0
                self.eyesClosed = false
                self.mouthShape = .smile
                self.blushVisible = false
            }
            self.finishAnimation()
        }
    }

    // A blissful purr — a fast, tiny vibration with closed happy eyes and
    // little hearts drifting up.
    private func petPurr() {
        withAnimation(.easeInOut(duration: 0.2)) {
            eyesClosed = true
            mouthShape = .smile
            blushVisible = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.06)) {
                self.bodyRoll = i % 2 == 0 ? 1.5 : -1.5
                self.bodyOffsetY = i % 2 == 0 ? -1 : 1
            }
            if i % 6 == 0 {
                self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -12...12), height: -28))
            }
            i += 1
            if i >= 16 {
                timer.invalidate()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.bodyRoll = 0
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

    // Half-lidded contentment with softly fluttering ears.
    private func petEarFlutter() {
        withAnimation(.easeInOut(duration: 0.3)) {
            eyesClosed = true
            mouthShape = .grin
            blushVisible = true
            headTilt = 4
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.12)) {
                self.earWiggle = i % 2 == 0 ? 4 : -4
                self.headTilt = i % 2 == 0 ? 4 : 2
            }
            i += 1
            if i >= 7 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.earWiggle = 0
                    self.headTilt = 0
                    self.eyesClosed = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Lifts her chin and gazes up adoringly at whoever's petting her.
    private func petChinUp() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            lookVertical = -9
            headTilt = -4
            mouthShape = .grin
            blushVisible = true
            bodyOffsetY = -2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -38))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                self.lookVertical = 0
                self.headTilt = 0
                self.mouthShape = .smile
                self.blushVisible = false
                self.bodyOffsetY = 0
            }
            self.finishAnimation()
        }
    }

    // Hugs her own arms in and snuggles into the warmth.
    private func petSnuggle() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -42
            rightArmWave = 42
            eyesClosed = true
            mouthShape = .grin
            blushVisible = true
            headTilt = 8
            squashScale = 0.96
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.headTilt = -6
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -30))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.eyesClosed = false
                self.mouthShape = .smile
                self.blushVisible = false
                self.headTilt = 0
                self.squashScale = 1.0
            }
            self.finishAnimation()
        }
    }

    // Swoons — head lolls back, a happy sigh, sparkles and a heart.
    private func petSwoon() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            headTilt = -14
            lookVertical = -6
            mouthShape = .ohh
            eyesClosed = true
            blushVisible = true
            bodyOffsetY = -3
            squashScale = 1.03
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.spawnParticle(.sparkle, at: CGSize(width: -20, height: -30))
            self.spawnParticle(.heart, at: CGSize(width: 14, height: -34))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.headTilt = 8
                self.mouthShape = .grin
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                self.headTilt = 0
                self.lookVertical = 0
                self.mouthShape = .smile
                self.eyesClosed = false
                self.blushVisible = false
                self.bodyOffsetY = 0
                self.squashScale = 1.0
            }
            self.finishAnimation()
        }
    }

    // A happy little tippy-tap dance of the feet while she beams.
    private func petTippyTaps() {
        withAnimation(.easeInOut(duration: 0.2)) {
            mouthShape = .grin
            blushVisible = true
            eyesWide = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                self.leadingPawSide = i % 2 == 0 ? -1 : 1
                self.walkFootLift = 5
                self.walkStride = i % 2 == 0 ? 3 : -3
                self.bodyOffsetY = -3
                self.headTilt = i % 2 == 0 ? 3 : -3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
                    self.walkFootLift = 0
                    self.bodyOffsetY = 0
                }
            }
            i += 1
            if i >= 8 {
                timer.invalidate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.walkStride = 0
                    self.walkFootLift = 0
                    self.headTilt = 0
                    self.eyesWide = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.spawnParticle(.heart, at: CGSize(width: 0, height: -32))
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Eyes burst into hearts, a big delighted grin and a shower of hearts.
    private func petHeartEyes() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            eyesHeart = true
            mouthShape = .grin
            blushVisible = true
            bounceScale = 1.16
            headTilt = -4
        }

        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                self.spawnParticle(.heart, at: CGSize(width: CGFloat.random(in: -26...26), height: -38))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.bounceScale = 1.0
                self.headTilt = 3
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.eyesHeart = false
                self.mouthShape = .smile
                self.blushVisible = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // A happy wiggle — eyes wide and bright, whole body rocking side to side.
    private func petWiggleHappy() {
        withAnimation(.easeInOut(duration: 0.2)) {
            eyesWide = true
            mouthShape = .grin
            blushVisible = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.16)) {
                self.bodyRoll = i % 2 == 0 ? 9 : -9
                self.headTilt = i % 2 == 0 ? 5 : -5
                self.bodyOffsetY = i % 2 == 0 ? -3 : 0
            }
            i += 1
            if i >= 7 {
                timer.invalidate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.bodyRoll = 0
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.eyesWide = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Springs up with a delighted little hop, arms flung up.
    private func petHop() {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
            squashScale = 0.86
            mouthShape = .ohh
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                self.bodyOffsetY = -22
                self.squashScale = 1.1
                self.shadowScale = 0.6
                self.eyesWide = true
                self.blushVisible = true
                self.leftArmRaised = true
                self.rightArmRaised = true
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -30))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                self.bodyOffsetY = 0
                self.squashScale = 0.94
                self.shadowScale = 1.1
                self.mouthShape = .grin
                self.leftArmRaised = false
                self.rightArmRaised = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.squashScale = 1.0
                self.shadowScale = 1.0
                self.eyesWide = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
    }

    // A giddy little twirl of joy.
    private func petSpinJoy() {
        withAnimation(.easeInOut(duration: 0.6)) {
            bodyRoll = 360
            mouthShape = .grin
            blushVisible = true
            bodyOffsetY = -6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -36))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            self.bodyRoll = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.bodyOffsetY = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.mouthShape = .smile
                self.blushVisible = false
            }
            self.finishAnimation()
        }
    }

    // Hides behind her paws, then peeks out wide-eyed and giggly.
    private func petPeekaboo() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -55
            rightArmWave = 55
            eyesClosed = true
            mouthShape = .smile
            headTilt = 4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.leftArmWave = -30
                self.rightArmWave = 30
                self.eyesClosed = false
                self.eyesWide = true
                self.blushVisible = true
                self.mouthShape = .grin
                self.headTilt = -3
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -32))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.eyesWide = false
                self.blushVisible = false
                self.mouthShape = .smile
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // A goofy, blissed-out blep — tips her head back with a little tongue-out
    // yawn shape before blinking back to a happy smile.
    private func petBlep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            mouthShape = .yawn
            eyesClosed = true
            headTilt = 10
            blushVisible = true
            squashScale = 1.04
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.spawnParticle(.sparkle, at: CGSize(width: 18, height: -10))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.eyesClosed = false
                self.eyesWide = true
                self.headTilt = -4
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                self.mouthShape = .smile
                self.eyesWide = false
                self.headTilt = 0
                self.blushVisible = false
                self.squashScale = 1.0
            }
            self.finishAnimation()
        }
    }

    // Flops onto her back for belly rubs — paws up, blissed right out.
    private func petRollOver() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            bodyRoll = -22
            bodyOffsetY = 8
            squashScale = 1.06
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -20
            rightArmWave = 20
            eyesClosed = true
            mouthShape = .grin
            blushVisible = true
            headTilt = -10
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.bodyRoll = -16
                self.leftArmWave = -32
                self.rightArmWave = 32
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -26))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                self.bodyRoll = 0
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.eyesClosed = false
                self.mouthShape = .smile
                self.blushVisible = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // Gazes up with big starry eyes, swaying gently — utterly smitten.
    private func petStarryGaze() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            eyesStarry = true
            lookVertical = -8
            mouthShape = .ohh
            blushVisible = true
            headTilt = -6
        }
        spawnParticle(.star, at: CGSize(width: -16, height: -40))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) {
                self.headTilt = 6
            }
            self.spawnParticle(.star, at: CGSize(width: 18, height: -42))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.headTilt = -2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                self.eyesStarry = false
                self.lookVertical = 0
                self.mouthShape = .smile
                self.blushVisible = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // Closes her eyes and hums, swaying her head dreamily to her own tune.
    private func petHumSway() {
        withAnimation(.easeInOut(duration: 0.3)) {
            eyesClosed = true
            mouthShape = .ohh
            blushVisible = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            withAnimation(.easeInOut(duration: 0.4)) {
                self.headTilt = i % 2 == 0 ? 7 : -7
                self.bodyOffsetY = i % 2 == 0 ? -2 : 1
            }
            self.spawnParticle(.musicNote, at: CGSize(width: i % 2 == 0 ? 20 : -20, height: -30))
            i += 1
            if i >= 5 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.headTilt = 0
                    self.bodyOffsetY = 0
                    self.eyesClosed = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Claps her paws and bounces, giddy with delight.
    private func petBounceClaps() {
        withAnimation(.easeInOut(duration: 0.2)) {
            mouthShape = .grin
            blushVisible = true
            eyesWide = true
            leftArmRaised = true
            rightArmRaised = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.26, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let together = i % 2 == 0
            withAnimation(.spring(response: 0.13, dampingFraction: 0.5)) {
                self.leftArmWave = together ? 30 : 0
                self.rightArmWave = together ? -30 : 0
                self.bodyOffsetY = together ? -8 : 0
                self.squashScale = together ? 0.96 : 1.02
            }
            if together {
                self.spawnParticle(.musicNote, at: CGSize(width: CGFloat.random(in: -18...18), height: -28))
            }
            i += 1
            if i >= 6 {
                timer.invalidate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.leftArmRaised = false
                    self.rightArmRaised = false
                    self.leftArmWave = 0
                    self.rightArmWave = 0
                    self.bodyOffsetY = 0
                    self.squashScale = 1.0
                    self.eyesWide = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // A luxurious cat-stretch into the petting, then she melts down content.
    private func petBigStretch() {
        withAnimation(.easeInOut(duration: 0.5)) {
            leftArmRaised = true
            rightArmRaised = true
            leftArmWave = -20
            rightArmWave = 20
            bodyOffsetY = -10
            squashScale = 1.1
            mouthShape = .yawn
            eyesClosed = true
            headTilt = -4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.bodyOffsetY = 4
                self.squashScale = 0.94
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.leftArmWave = 0
                self.rightArmWave = 0
                self.mouthShape = .grin
                self.blushVisible = true
                self.headTilt = 5
            }
            self.spawnParticle(.heart, at: CGSize(width: 0, height: -28))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.bodyOffsetY = 0
                self.squashScale = 1.0
                self.eyesClosed = false
                self.mouthShape = .smile
                self.blushVisible = false
                self.headTilt = 0
            }
            self.finishAnimation()
        }
    }

    // A happy little full-body shiver of delight, eyes wide and sparkly.
    private func petShiver() {
        withAnimation(.easeInOut(duration: 0.15)) {
            eyesWide = true
            mouthShape = .grin
            blushVisible = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let dir: CGFloat = i % 2 == 0 ? 1 : -1
            withAnimation(.linear(duration: 0.04)) {
                self.bodyRoll = Double(dir) * 2.5
                self.headTilt = Double(dir) * 2
            }
            if i == 6 {
                self.spawnParticle(.sparkle, at: CGSize(width: -18, height: -26))
                self.spawnParticle(.sparkle, at: CGSize(width: 18, height: -28))
            }
            i += 1
            if i >= 16 {
                timer.invalidate()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.bodyRoll = 0
                    self.headTilt = 0
                    self.eyesWide = false
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.spawnParticle(.heart, at: CGSize(width: 0, height: -30))
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Bobs her head to a happy little beat, ears bouncing along.
    private func petHeadBob() {
        withAnimation(.easeInOut(duration: 0.2)) {
            mouthShape = .grin
            blushVisible = true
        }

        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let down = i % 2 == 0
            withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
                self.bodyOffsetY = down ? -5 : 1
                self.headTilt = down ? 5 : -5
                self.earWiggle = down ? 3 : -3
            }
            if i % 2 == 0 {
                self.spawnParticle(.musicNote, at: CGSize(width: down ? 18 : -18, height: -30))
            }
            i += 1
            if i >= 7 {
                timer.invalidate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.bodyOffsetY = 0
                    self.headTilt = 0
                    self.earWiggle = 0
                    self.mouthShape = .smile
                    self.blushVisible = false
                }
                self.finishAnimation()
            }
        }
        registerTimer(timer)
    }

    // Lets her head loll all the way to one side, totally relaxed.
    private func petFlop() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headTilt = 22
            bodyRoll = 6
            eyesClosed = true
            mouthShape = .smile
            blushVisible = true
            squashScale = 0.97
            lookVertical = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.spawnParticle(.heart, at: CGSize(width: 16, height: -24))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                self.headTilt = 0
                self.bodyRoll = 0
                self.eyesClosed = false
                self.blushVisible = false
                self.squashScale = 1.0
                self.lookVertical = 0
            }
            self.finishAnimation()
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
