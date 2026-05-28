import SwiftUI
import Combine

enum PandaAnimationState: CaseIterable {
    case idle
    case blinking
    case waving
    case sleeping
    case stretching
    case lookingAround
    case reacting
}

final class PandaViewModel: ObservableObject {
    @Published var animationState: PandaAnimationState = .idle
    @Published var eyesClosed: Bool = false
    @Published var mouthOpen: Bool = false
    @Published var leftArmRaised: Bool = false
    @Published var rightArmRaised: Bool = false
    @Published var bodyOffsetY: CGFloat = 0
    @Published var headTilt: Double = 0
    @Published var lookDirection: CGFloat = 0
    @Published var blushVisible: Bool = false
    @Published var zzzVisible: Bool = false
    @Published var heartVisible: Bool = false
    @Published var bounceScale: CGFloat = 1.0

    private var idleTimer: Timer?
    private var animationTimer: Timer?
    private var isReacting = false

    init() {
        startIdleCycle()
    }

    func pat() {
        guard !isReacting else { return }
        isReacting = true

        stopIdleCycle()
        animationState = .reacting

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            bounceScale = 1.2
            heartVisible = true
            blushVisible = true
            mouthOpen = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                self.bounceScale = 0.9
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.bounceScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.heartVisible = false
                self.blushVisible = false
                self.mouthOpen = false
            }
            self.isReacting = false
            self.animationState = .idle
            self.startIdleCycle()
        }
    }

    private func startIdleCycle() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...6), repeats: false) { [weak self] _ in
            self?.playRandomIdleAnimation()
        }
    }

    private func stopIdleCycle() {
        idleTimer?.invalidate()
        idleTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func playRandomIdleAnimation() {
        guard !isReacting else { return }

        let animations: [PandaAnimationState] = [.blinking, .waving, .sleeping, .stretching, .lookingAround]
        let chosen = animations.randomElement() ?? .blinking
        animationState = chosen

        switch chosen {
        case .blinking:
            playBlink()
        case .waving:
            playWave()
        case .sleeping:
            playSleep()
        case .stretching:
            playStretch()
        case .lookingAround:
            playLookAround()
        default:
            break
        }
    }

    private func playBlink() {
        withAnimation(.easeInOut(duration: 0.1)) { eyesClosed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.1)) { self.eyesClosed = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { self.eyesClosed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.1)) { self.eyesClosed = false }
                    self.animationState = .idle
                    self.startIdleCycle()
                }
            }
        }
    }

    private func playWave() {
        withAnimation(.easeInOut(duration: 0.3)) {
            rightArmRaised = true
        }

        var waveCount = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            waveCount += 1
            withAnimation(.easeInOut(duration: 0.2)) {
                self.headTilt = waveCount % 2 == 0 ? 5 : -5
            }
            if waveCount >= 4 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.rightArmRaised = false
                    self.headTilt = 0
                }
                self.animationState = .idle
                self.startIdleCycle()
            }
        }
    }

    private func playSleep() {
        withAnimation(.easeInOut(duration: 0.5)) {
            eyesClosed = true
            zzzVisible = true
            bodyOffsetY = 5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.eyesClosed = false
                self.zzzVisible = false
                self.bodyOffsetY = 0
            }
            self.animationState = .idle
            self.startIdleCycle()
        }
    }

    private func playStretch() {
        withAnimation(.easeInOut(duration: 0.4)) {
            leftArmRaised = true
            rightArmRaised = true
            bodyOffsetY = -8
            bounceScale = 1.05
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.leftArmRaised = false
                self.rightArmRaised = false
                self.bodyOffsetY = 0
                self.bounceScale = 1.0
            }
            self.animationState = .idle
            self.startIdleCycle()
        }
    }

    private func playLookAround() {
        withAnimation(.easeInOut(duration: 0.4)) {
            lookDirection = -8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.lookDirection = 8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.lookDirection = 0
            }
            self.animationState = .idle
            self.startIdleCycle()
        }
    }
}
