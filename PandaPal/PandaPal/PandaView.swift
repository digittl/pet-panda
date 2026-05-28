import SwiftUI

struct PandaView: View {
    @ObservedObject var viewModel: PandaViewModel

    private let bodyFill = LinearGradient(
        colors: [
            Color(red: 1.0, green: 1.0, blue: 0.98),
            Color(red: 0.97, green: 0.96, blue: 0.92),
            Color(red: 0.9, green: 0.9, blue: 0.86)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let darkFill = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.18, blue: 0.17),
            Color(red: 0.04, green: 0.045, blue: 0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let outline = Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.85)
    private let muzzleFill = LinearGradient(
        colors: [Color.white.opacity(0.96), Color(red: 0.92, green: 0.91, blue: 0.86)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            pandaBody
        }
        .rotationEffect(.degrees(viewModel.headTilt))
        .rotationEffect(.degrees(viewModel.bodyRoll))
        .rotationEffect(.degrees(viewModel.dragSway), anchor: .top)
    }

    private var pandaBody: some View {
        ZStack {
            // Cushion (when sitting / napping / relaxing)
            if viewModel.cushionVisible {
                Cushion()
                    .offset(y: 56)
                    .transition(.scale.combined(with: .opacity))
            }

            // Soft drop shadow under the panda
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 76, height: 10)
                .blur(radius: 4)
                .offset(y: 62)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Body
            Ellipse()
                .fill(bodyFill)
                .frame(width: 66, height: 76)
                .offset(y: 20)
                .shadow(color: Color.white.opacity(0.55), radius: 4, x: -2, y: -3)
                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 1.5, y: 2.5)
                .overlay(
                    Ellipse()
                        .stroke(outline, lineWidth: 1.8)
                        .frame(width: 66, height: 76)
                        .offset(y: 20)
                )

            // Belly highlight (subtle lighter spot)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.08)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 24
                    )
                )
                .frame(width: 34, height: 40)
                .offset(x: -6, y: 18)
                .blur(radius: 2.5)

            // Legs — normal stance when standing, crossed lotus when sitting
            if viewModel.sitting {
                CrossedLegs()
                    .offset(y: 46)
                    .transition(.scale.combined(with: .opacity))
            } else {
                leg(side: -1)
                leg(side: 1)
            }

            // Arms — folded together in lap when zen, otherwise normal
            if viewModel.pawsInLap {
                PawsInLap()
                    .offset(y: 30)
                    .transition(.opacity)
            } else {
                arm(side: -1, raised: viewModel.leftArmRaised, wave: viewModel.leftArmWave)
                arm(side: 1, raised: viewModel.rightArmRaised, wave: viewModel.rightArmWave)
            }

            // Bamboo (held during eating)
            if viewModel.bambooVisible {
                BambooStick()
                    .offset(x: 0, y: -2)
                    .rotationEffect(.degrees(viewModel.bambooTilt))
                    .scaleEffect(viewModel.bambooScale)
                    .transition(.scale.combined(with: .opacity))
            }

            // Head
            head
        }
        .scaleEffect(y: viewModel.squashScale, anchor: .bottom)
    }

    private var head: some View {
        ZStack {
            // Ears
            ear(side: -1)
            ear(side: 1)

            // Cute pink bow on top of head (always-on accessory)
            PandaBow()
                .offset(x: 15, y: -49)
                .rotationEffect(.degrees(-10))

            // Head shape
            Circle()
                .fill(bodyFill)
                .frame(width: 70, height: 70)
                .offset(y: -12)
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: -2, y: -3)
                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 1.5, y: 2)
                .overlay(
                    Circle()
                        .stroke(outline, lineWidth: 1.8)
                        .frame(width: 70, height: 70)
                        .offset(y: -12)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        .frame(width: 62, height: 62)
                        .offset(x: -3, y: -17)
                        .blur(radius: 1.2)
                )

            // Eye patches
            eyePatch(side: -1)
            eyePatch(side: 1)

            // Eyes
            eye(side: -1)
            eye(side: 1)

            // Cheeks (always faintly visible)
            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.6 : 0.32))
                .frame(width: 13, height: 10)
                .offset(x: -22, y: -2)
                .blur(radius: 1)

            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.6 : 0.32))
                .frame(width: 13, height: 10)
                .offset(x: 22, y: -2)
                .blur(radius: 1)

            // Soft muzzle keeps the mouth crisp against the face.
            Ellipse()
                .fill(muzzleFill)
                .frame(width: 28, height: 20)
                .offset(y: 2)
                .overlay(
                    Ellipse()
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                        .frame(width: 28, height: 20)
                        .offset(y: 2)
                )

            // Nose
            ZStack {
                Ellipse()
                    .fill(Color(white: 0.12))
                    .frame(width: 9, height: 6)
                Ellipse()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3, height: 1.5)
                    .offset(x: -1.5, y: -1)
            }
            .offset(y: -3)

            // Mouth
            mouth
        }
    }

    private func ear(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(darkFill)
                .frame(width: 25, height: 25)
                .overlay(
                    Circle()
                        .stroke(outline, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.pink.opacity(0.5), Color.pink.opacity(0.18)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 8
                    )
                )
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 8, height: 4)
                .offset(x: -4, y: -5)
        }
        .offset(x: 23 * side, y: -38 + (viewModel.earWiggle * (side == -1 ? 1 : -1)))
    }

    private func eyePatch(side: CGFloat) -> some View {
        Ellipse()
            .fill(darkFill)
            .frame(width: 23, height: 25)
            .rotationEffect(.degrees(side == -1 ? -15 : 15))
            .overlay(
                Ellipse()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 18, height: 20)
                    .rotationEffect(.degrees(side == -1 ? -15 : 15))
                    .offset(x: -2 * side, y: -2)
            )
            .offset(x: 13 * side + viewModel.lookDirection * 0.3, y: -14)
    }

    @ViewBuilder
    private func eye(side: CGFloat) -> some View {
        let baseX = 13 * side
        let lookX = viewModel.lookDirection
        let lookY = viewModel.lookVertical

        if viewModel.eyesClosed {
            // Happy closed eye — upward curve
            HappyEyeShape()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 14, height: 6)
                .offset(x: baseX, y: -14)
        } else if viewModel.eyesHeart {
            Text("♥")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.5))
                .offset(x: baseX, y: -14)
        } else if viewModel.eyesStarry {
            Text("✦")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.2))
                .offset(x: baseX, y: -14)
        } else {
            ZStack {
                // Sclera
                Circle()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)

                // Pupil
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: viewModel.eyesWide ? 9 : 7, height: viewModel.eyesWide ? 9 : 7)
                    .offset(x: lookX * 0.4, y: lookY * 0.4)

                // Big highlight
                Circle()
                    .fill(Color.white)
                    .frame(width: 4.2, height: 4.2)
                    .offset(x: -1.6 + lookX * 0.3, y: -1.6 + lookY * 0.3)

                // Tiny secondary highlight
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2.2, height: 2.2)
                    .offset(x: 2.0 + lookX * 0.3, y: 1.6 + lookY * 0.3)
            }
            .offset(x: baseX + lookX * 0.5, y: -14 + lookY * 0.5)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch viewModel.mouthShape {
        case .smile:
            SmilePath()
                .stroke(Color(white: 0.15), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 14, height: 5)
                .offset(y: 3)
        case .open:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.5))
                    .frame(width: 12, height: 9)
                    .overlay(
                        Ellipse()
                            .stroke(Color(white: 0.12), lineWidth: 1)
                    )
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.7, blue: 0.75))
                    .frame(width: 6, height: 3)
                    .offset(y: 2)
            }
            .offset(y: 4)
        case .grin:
            ZStack {
                GrinPath()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.5))
                    .frame(width: 17, height: 8)
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 12, height: 2)
                    .offset(y: -1)
                GrinPath()
                    .stroke(Color(white: 0.15), lineWidth: 1.4)
                    .frame(width: 17, height: 8)
            }
            .offset(y: 4)
        case .ohh:
            Circle()
                .fill(Color(red: 0.9, green: 0.4, blue: 0.45))
                .frame(width: 7, height: 7)
                .offset(y: 4)
        case .yawn:
            Ellipse()
                .fill(Color(red: 0.9, green: 0.4, blue: 0.45))
                .frame(width: 10, height: 14)
                .offset(y: 5)
        }
    }

    private func leg(side: CGFloat) -> some View {
        let isLeading = side == viewModel.leadingPawSide
        let stride = viewModel.walkStride * side * viewModel.walkDirection
        let lift = isLeading ? viewModel.walkFootLift : 0

        return ZStack {
            Ellipse()
                .fill(darkFill)
                .frame(width: 25, height: 20)
                .overlay(
                    Ellipse()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 20, height: 15)
                        .offset(x: -2 * side, y: -2)
                )

            Circle()
                .fill(Color.pink.opacity(0.5))
                .frame(width: 5, height: 4)
                .offset(x: -3 * side, y: 2)
        }
        .offset(x: 14 * side + stride, y: 54 - lift)
    }

    private func arm(side: CGFloat, raised: Bool, wave: Double) -> some View {
        // Keep arm rotation modest so it never tucks behind the body or
        // disappears off the side. `raised` adds a fixed upward swing, then
        // `wave` adds a small extra swing within sensible bounds.
        let baseDown: Double = side == -1 ? 18 : -18
        let baseUp: Double = side == -1 ? -22 : 22
        let base = raised ? baseUp : baseDown
        let clampedWave = max(-25, min(25, wave))
        let angle = base + clampedWave

        return ZStack {
            Capsule()
                .fill(darkFill)
                .frame(width: 18, height: 32)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 4, height: 20)
                        .offset(x: -4 * side, y: -4)
                        .blur(radius: 0.5)
                )

            Circle()
                .fill(Color.pink.opacity(0.38))
                .frame(width: 7, height: 5)
                .offset(y: 12)
        }
        .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: 0.15))
        .offset(x: 30 * side, y: raised ? 6 : 16)
    }
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

struct HappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

struct GrinPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct CrossedLegs: View {
    private let darkFill = LinearGradient(
        colors: [Color(white: 0.22), Color(white: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Back leg (crossed under) — slightly behind, tilted right
            Capsule()
                .fill(darkFill)
                .frame(width: 14, height: 38)
                .rotationEffect(.degrees(75))
                .offset(x: -6, y: 2)

            // Front leg — crossed over, tilted left
            Capsule()
                .fill(darkFill)
                .frame(width: 14, height: 40)
                .rotationEffect(.degrees(-75))
                .offset(x: 6, y: 0)

            // Foot pads peeking out at the knees
            Circle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.3), Color(white: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 11, height: 9)
                .offset(x: -22, y: -2)

            Circle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.3), Color(white: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 11, height: 9)
                .offset(x: 22, y: -2)

            // Tiny pink pads on the feet
            Circle().fill(Color.pink.opacity(0.55)).frame(width: 3, height: 2.5).offset(x: -22, y: -2)
            Circle().fill(Color.pink.opacity(0.55)).frame(width: 3, height: 2.5).offset(x: 22, y: -2)
        }
    }
}

struct PawsInLap: View {
    private let darkFill = LinearGradient(
        colors: [Color(white: 0.22), Color(white: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Two paws clasped together in the center of the lap
            Ellipse()
                .fill(darkFill)
                .frame(width: 16, height: 12)
                .offset(x: -5)

            Ellipse()
                .fill(darkFill)
                .frame(width: 16, height: 12)
                .offset(x: 5)

            // Subtle highlight on top
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 14, height: 2)
                .offset(y: -3)
        }
    }
}

struct Cushion: View {
    var body: some View {
        ZStack {
            // Cushion body
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.7, blue: 0.85),
                        Color(red: 0.85, green: 0.45, blue: 0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 92, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.65, green: 0.25, blue: 0.45).opacity(0.5), lineWidth: 1.2)
                )

            // Top highlight stripe
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 60, height: 4)
                .offset(y: -7)
                .blur(radius: 1.5)

            // Tassels
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.85, green: 0.4, blue: 0.6))
                    .frame(width: 6, height: 6)
                    .offset(x: i == 0 ? -46 : 46, y: 2)
            }
        }
    }
}

struct PandaBow: View {
    private let ribbonFill = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.62, blue: 0.78),
            Color(red: 0.98, green: 0.42, blue: 0.6),
            Color(red: 0.85, green: 0.22, blue: 0.42)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let ribbonOutline = Color(red: 0.55, green: 0.08, blue: 0.22).opacity(0.85)

    var body: some View {
        ZStack {
            // Ribbon tails dangling below the knot.
            ribbonTail(side: -1)
            ribbonTail(side: 1)

            // Left loop
            loop(side: -1)

            // Right loop
            loop(side: 1)

            // Center knot — wraps the join so the loops read as a single bow.
            RoundedRectangle(cornerRadius: 2.5)
                .fill(ribbonFill)
                .frame(width: 7, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5)
                        .stroke(ribbonOutline, lineWidth: 1.1)
                )
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 1.6, height: 5)
                        .offset(x: -1.4)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1.5)
    }

    private func loop(side: CGFloat) -> some View {
        Ellipse()
            .fill(ribbonFill)
            .frame(width: 15, height: 11)
            .overlay(
                Ellipse()
                    .stroke(ribbonOutline, lineWidth: 1.1)
            )
            .overlay(
                Ellipse()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 6, height: 3)
                    .offset(x: -2 * side, y: -2.5)
                    .blur(radius: 0.6)
            )
            .offset(x: 6 * side)
            .rotationEffect(.degrees(side == -1 ? -18 : 18))
    }

    private func ribbonTail(side: CGFloat) -> some View {
        RibbonTail()
            .fill(ribbonFill)
            .frame(width: 6, height: 9)
            .overlay(
                RibbonTail()
                    .stroke(ribbonOutline, lineWidth: 1)
            )
            .rotationEffect(.degrees(side == -1 ? -12 : 12))
            .offset(x: 3 * side, y: 7)
    }
}

private struct RibbonTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct BambooStick: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.9, blue: 0.38),
                        Color(red: 0.45, green: 0.72, blue: 0.22),
                        Color(red: 0.25, green: 0.5, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 9, height: 38)
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 1, y: 1)
                .overlay(
                    VStack(spacing: 8) {
                        Capsule().fill(Color(red: 0.22, green: 0.42, blue: 0.12)).frame(height: 1.5)
                        Capsule().fill(Color(red: 0.22, green: 0.42, blue: 0.12)).frame(height: 1.5)
                        Capsule().fill(Color(red: 0.22, green: 0.42, blue: 0.12)).frame(height: 1.5)
                    }
                    .frame(width: 9)
                )
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 2, height: 32)
                        .offset(x: -2)
                )

            BambooLeaf()
                .fill(LinearGradient(
                    colors: [Color(red: 0.64, green: 0.88, blue: 0.32), Color(red: 0.28, green: 0.58, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 18, height: 9)
                .rotationEffect(.degrees(-35))
                .offset(x: 9, y: -16)

            BambooLeaf()
                .fill(LinearGradient(
                    colors: [Color(red: 0.56, green: 0.8, blue: 0.28), Color(red: 0.24, green: 0.52, blue: 0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 15, height: 8)
                .rotationEffect(.degrees(145))
                .offset(x: -8, y: -4)
        }
    }
}

struct BambooLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.35)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.35)
        )
        path.closeSubpath()
        return path
    }
}
