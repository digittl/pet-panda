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

            // Resting arms sit behind the head for a clean panda silhouette.
            // When she's napping / sitting / relaxing, the same capsules just
            // angle inward from their default position instead of swapping in
            // a separate "paws in lap" view.
            if !viewModel.leftArmRaised {
                arm(side: -1, raised: false, wave: viewModel.leftArmWave, inLap: viewModel.pawsInLap)
            }
            if !viewModel.rightArmRaised || viewModel.greetingWave {
                arm(
                    side: 1,
                    raised: viewModel.greetingWave,
                    wave: viewModel.rightArmWave,
                    inLap: viewModel.greetingWave ? false : viewModel.pawsInLap
                )
            }

            // Head
            head

            // Raised arms render IN FRONT of the head so her paws are clearly
            // holding the bamboo at face level.
            if viewModel.leftArmRaised {
                arm(side: -1, raised: true, wave: viewModel.leftArmWave, inLap: false)
            }
            if viewModel.rightArmRaised && !viewModel.greetingWave {
                arm(side: 1, raised: true, wave: viewModel.rightArmWave, inLap: false)
            }

            // Bamboo (held during eating) — flies in from upper-right.
            if viewModel.bambooVisible {
                BambooStick()
                    .rotationEffect(.degrees(viewModel.bambooTilt))
                    .scaleEffect(viewModel.bambooScale)
                    .offset(
                        x: viewModel.bambooEntryOffset.width,
                        y: 26 + viewModel.bambooEntryOffset.height
                    )
                    .transition(.opacity)
            }
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

            // Head shape — multi-layered for high-def depth.
            Circle()
                .fill(bodyFill)
                .frame(width: 70, height: 70)
                .offset(y: -12)
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: -2, y: -3)
                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 1.5, y: 2)
                .overlay(
                    // Top-left rim light — soft fur sheen toward the light source.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
                                center: UnitPoint(x: 0.25, y: 0.18),
                                startRadius: 1,
                                endRadius: 28
                            )
                        )
                        .frame(width: 66, height: 66)
                        .offset(y: -12)
                        .blendMode(.screen)
                )
                .overlay(
                    // Bottom-right inner shadow — gives the head volume.
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.clear, Color.clear, Color.black.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 6
                        )
                        .frame(width: 70, height: 70)
                        .offset(y: -12)
                        .blur(radius: 2.5)
                )
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

            // Nose — teardrop with proper specular highlights.
            ZStack {
                NoseShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.13, blue: 0.13),
                                Color(red: 0.04, green: 0.03, blue: 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 10, height: 7)
                    .overlay(
                        NoseShape()
                            .stroke(Color.black.opacity(0.7), lineWidth: 0.6)
                            .frame(width: 10, height: 7)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 1.2, x: 0, y: 0.6)

                Ellipse()
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 3.4, height: 1.8)
                    .offset(x: -1.8, y: -1.4)
                    .blur(radius: 0.2)

                Ellipse()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 1.4, height: 0.9)
                    .offset(x: 1.4, y: 0.6)
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

    private func gripHand(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(darkFill)
                .frame(width: 13, height: 12)
                .overlay(
                    Circle()
                        .stroke(outline, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 1.5, x: 0, y: 1)

            Circle()
                .fill(Color.pink.opacity(0.55))
                .frame(width: 5, height: 4)
                .offset(y: 1.5)
        }
        .offset(
            x: 8 * side + viewModel.bambooEntryOffset.width * 0.4,
            y: 16 + viewModel.bambooEntryOffset.height * 0.4
        )
        .transition(.opacity)
    }

    private func arm(side: CGFloat, raised: Bool, wave: Double, inLap: Bool = false) -> some View {
        // Single chibi capsule per arm. Side-dependent base angles so the
        // right arm rotates inward symmetrically when raised. In the lap
        // pose, the arms tilt strongly toward the centre from their default
        // resting offset — no separate "paws in lap" view needed.
        let baseDown: Double = side == -1 ? 18 : -18
        let baseUp: Double = side == -1 ? -28 : 28
        let baseLap: Double = side == -1 ? -38 : 38
        let base: Double
        if inLap {
            base = baseLap
        } else if raised {
            base = baseUp
        } else {
            base = baseDown
        }
        let clampedWave = max(-25, min(25, wave))
        let angle = base + clampedWave

        return ZStack {
            Capsule()
                .fill(darkFill)
                .frame(width: 18, height: 32)
                .overlay(
                    Capsule()
                        .stroke(outline, lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 4, height: 20)
                        .offset(x: -4 * side, y: -4)
                        .blur(radius: 0.5)
                )

            // Pink paw pad at the bottom (only really visible when raised).
            Circle()
                .fill(Color.pink.opacity(0.45))
                .frame(width: 7, height: 5)
                .offset(y: 12)
        }
        .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: 0.15))
        .offset(x: 30 * side, y: raised ? 6 : (inLap ? 22 : 16))
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
    private let topFill = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.78, blue: 0.9),
            Color(red: 0.93, green: 0.58, blue: 0.75),
            Color(red: 0.82, green: 0.4, blue: 0.6)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let sideFill = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.36, blue: 0.55),
            Color(red: 0.62, green: 0.22, blue: 0.42)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let trim = Color(red: 0.55, green: 0.15, blue: 0.32).opacity(0.85)

    var body: some View {
        ZStack {
            // Ground shadow under the cushion gives it weight.
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 100, height: 12)
                .blur(radius: 4)
                .offset(y: 14)

            // Cushion side band — gives the pillow its depth.
            RoundedRectangle(cornerRadius: 16)
                .fill(sideFill)
                .frame(width: 96, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(trim, lineWidth: 1.2)
                )
                .offset(y: 6)

            // Plump top cushion — slight squash so it reads as soft.
            Ellipse()
                .fill(topFill)
                .frame(width: 100, height: 34)
                .overlay(
                    Ellipse()
                        .stroke(trim, lineWidth: 1.4)
                )
                .shadow(color: Color.white.opacity(0.5), radius: 3, x: -2, y: -2)
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 2, y: 3)

            // Quilted top highlight — long soft sheen.
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: 72, height: 8)
                .offset(y: -9)
                .blur(radius: 2)

            // Stitched piping running across the top — adds tufted detail.
            Capsule()
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2.5]))
                .frame(width: 80, height: 14)
                .offset(y: -2)

            // Centre tuft button — the hallmark of a real cushion.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.7, green: 0.22, blue: 0.42),
                                Color(red: 0.45, green: 0.1, blue: 0.25)
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 6
                        )
                    )
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(trim, lineWidth: 0.8)
                    )

                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 2.4, height: 2.4)
                    .offset(x: -1.4, y: -1.4)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)

            // Corner tassels — full pom-poms with hanging strands.
            ForEach(0..<2, id: \.self) { i in
                let xSign: CGFloat = i == 0 ? -1 : 1
                CushionTassel()
                    .offset(x: xSign * 50, y: 4)
            }
        }
    }
}

private struct CushionTassel: View {
    var body: some View {
        ZStack {
            // Knot at the cushion edge.
            Capsule()
                .fill(Color(red: 0.55, green: 0.15, blue: 0.32))
                .frame(width: 5, height: 4)
                .offset(y: -2)

            // Fluffy pom-pom.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.78, blue: 0.88),
                            Color(red: 0.85, green: 0.4, blue: 0.6)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 8
                    )
                )
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.55, green: 0.15, blue: 0.32).opacity(0.55), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                .offset(y: 4)

            // Tiny dangling strands.
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.65, green: 0.22, blue: 0.4))
                    .frame(width: 1, height: 4)
                    .offset(x: CGFloat(i - 1) * 2.5, y: 11)
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
            RoundedRectangle(cornerRadius: 3)
                .fill(ribbonFill)
                .frame(width: 9, height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(ribbonOutline, lineWidth: 1.3)
                )
                .overlay(
                    // Knot crease — vertical pinches that sell the wrap.
                    HStack(spacing: 1.5) {
                        Capsule().fill(Color.black.opacity(0.25)).frame(width: 0.8, height: 8)
                        Capsule().fill(Color.white.opacity(0.55)).frame(width: 1.4, height: 8)
                        Capsule().fill(Color.black.opacity(0.25)).frame(width: 0.8, height: 8)
                    }
                )
                .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 2.5, x: 0, y: 2)
    }

    private func loop(side: CGFloat) -> some View {
        // Each loop is a teardrop pinched at the knot (inner) side and
        // bulging outward — mirrored per side to form a classic bow.
        ZStack {
            BowLoop()
                .fill(ribbonFill)
                .overlay(
                    BowLoop()
                        .stroke(ribbonOutline, lineWidth: 1.4)
                )
                .overlay(
                    // Top sheen inside the loop.
                    Ellipse()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 9, height: 4)
                        .offset(x: 3, y: -3.5)
                        .blur(radius: 0.7)
                )
                .overlay(
                    // Inner crease near the knot — sells the pinch.
                    BowLoop()
                        .stroke(
                            LinearGradient(
                                colors: [Color.black.opacity(0.45), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 0.9)
                )
        }
        .frame(width: 18, height: 16)
        .scaleEffect(x: side, y: 1)
        .offset(x: 8 * side)
        .rotationEffect(.degrees(side == -1 ? -8 : 8))
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

private struct NoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Soft teardrop — wider at the top, narrower at the bottom.
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let leftCtrlTop = CGPoint(x: rect.minX - rect.width * 0.05, y: rect.minY + rect.height * 0.2)
        let leftCtrlBottom = CGPoint(x: rect.midX - rect.width * 0.25, y: rect.maxY)
        let rightCtrlBottom = CGPoint(x: rect.midX + rect.width * 0.25, y: rect.maxY)
        let rightCtrlTop = CGPoint(x: rect.maxX + rect.width * 0.05, y: rect.minY + rect.height * 0.2)

        path.move(to: top)
        path.addCurve(to: bottom, control1: leftCtrlTop, control2: leftCtrlBottom)
        path.addCurve(to: top, control1: rightCtrlBottom, control2: rightCtrlTop)
        path.closeSubpath()
        return path
    }
}

private struct BowLoop: Shape {
    func path(in rect: CGRect) -> Path {
        // Pinched on the LEFT (knot side), bulging out on the right —
        // classic ribbon-loop silhouette.
        var path = Path()
        let knot = CGPoint(x: rect.minX, y: rect.midY)
        let topOuter = CGPoint(x: rect.maxX * 0.85, y: rect.minY)
        let outerMid = CGPoint(x: rect.maxX, y: rect.midY)
        let bottomOuter = CGPoint(x: rect.maxX * 0.85, y: rect.maxY)

        path.move(to: knot)
        // Top edge of the loop swoops up and out.
        path.addCurve(
            to: topOuter,
            control1: CGPoint(x: rect.midX * 0.4, y: rect.minY + rect.height * 0.05),
            control2: CGPoint(x: rect.midX * 0.7, y: rect.minY)
        )
        // Outer rounded edge of the loop.
        path.addQuadCurve(
            to: outerMid,
            control: CGPoint(x: rect.maxX + rect.width * 0.08, y: rect.minY + rect.height * 0.18)
        )
        path.addQuadCurve(
            to: bottomOuter,
            control: CGPoint(x: rect.maxX + rect.width * 0.08, y: rect.maxY - rect.height * 0.18)
        )
        // Bottom edge swoops back to the knot.
        path.addCurve(
            to: knot,
            control1: CGPoint(x: rect.midX * 0.7, y: rect.maxY),
            control2: CGPoint(x: rect.midX * 0.4, y: rect.maxY - rect.height * 0.05)
        )
        path.closeSubpath()
        return path
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
