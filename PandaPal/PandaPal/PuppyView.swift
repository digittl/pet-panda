import SwiftUI

/// Procedural cartoon puppy, drawn to the same quality bar as the panda:
/// layered fur gradients, a soft rim-light, floppy ears that hang down the
/// sides of the head, big glossy eyes and a white snout with a lolling tongue.
/// Drawing-only — every motion maps from the shared PandaViewModel state:
/// headTilt/bodyRoll/dragSway rotate the whole pup, leftArmWave/rightArmWave
/// drive the front paws, walkStride/walkFootLift drive the hind legs, earWiggle
/// flops the ears, and the tail wags whenever she's happy (earWiggle / wave /
/// blush). When `bambooVisible` fires she holds her treat — a bone.
struct PuppyView: View {
    @ObservedObject var viewModel: PandaViewModel

    private let furLight = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.87, blue: 0.66),
            Color(red: 0.95, green: 0.78, blue: 0.52),
            Color(red: 0.86, green: 0.66, blue: 0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let furDark = LinearGradient(
        colors: [
            Color(red: 0.62, green: 0.41, blue: 0.21),
            Color(red: 0.43, green: 0.27, blue: 0.13)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let outline = Color(red: 0.2, green: 0.11, blue: 0.05).opacity(0.85)
    private let bellyFill = Color(red: 1.0, green: 0.95, blue: 0.85)
    private let pawPadColor = Color(red: 0.45, green: 0.28, blue: 0.2)

    private var cheekColor: Color {
        Color(red: 1.0, green: 0.55, blue: 0.55).opacity(viewModel.blushVisible ? 0.55 : 0.22)
    }

    // Tail wags whenever she's happy: earWiggle drives a continuous wag and a
    // greeting/blush adds a fixed swing, so a wagging tail tracks her mood
    // without needing a dedicated state field.
    private var tailWag: Double {
        let base = Double(viewModel.earWiggle) * 7
        let greet = viewModel.greetingWave ? 26.0 : 0.0
        let happy = viewModel.blushVisible ? 12.0 : 0.0
        return base + greet + happy
    }

    var body: some View {
        ZStack {
            puppyBody
        }
        .rotationEffect(.degrees(viewModel.headTilt))
        .rotationEffect(.degrees(viewModel.bodyRoll))
        .rotationEffect(.degrees(viewModel.dragSway), anchor: .top)
    }

    private var puppyBody: some View {
        ZStack {
            // Soft drop shadow
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 78, height: 11)
                .blur(radius: 4)
                .offset(y: 64)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Tail — curls up behind the body and wags with her mood
            tail
                .offset(x: 34, y: 28)
                .rotationEffect(.degrees(tailWag - 12), anchor: .bottomLeading)
                .animation(.spring(response: 0.32, dampingFraction: 0.5), value: tailWag)

            // Body
            Ellipse()
                .fill(furLight)
                .frame(width: 70, height: 72)
                .offset(y: 24)
                .shadow(color: Color.white.opacity(0.45), radius: 4, x: -2, y: -3)
                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 1.5, y: 2.5)
                .overlay(
                    Ellipse()
                        .stroke(outline, lineWidth: 1.7)
                        .frame(width: 70, height: 72)
                        .offset(y: 24)
                )

            // Cream belly
            Ellipse()
                .fill(bellyFill)
                .frame(width: 40, height: 48)
                .offset(y: 30)
                .blur(radius: 0.6)

            // Hind legs (tucked away in the sitting pose)
            if !viewModel.sitting {
                hindLeg(side: -1)
                hindLeg(side: 1)
            }

            // Front paws — driven by the shared arm-wave state
            frontPaw(side: -1, wave: viewModel.leftArmWave, lift: viewModel.greetingWave ? -8 : 0)
            frontPaw(side: 1, wave: viewModel.rightArmWave, lift: 0)

            // Head sits in front of the paws so the face always reads clearly
            head
                .offset(y: -16)

            // Held treat (bone) — flies in during the feed/catch feast
            if viewModel.bambooVisible {
                Text("🦴")
                    .font(.system(size: 26))
                    .rotationEffect(.degrees(viewModel.bambooTilt + 90))
                    .scaleEffect(viewModel.bambooScale)
                    .offset(
                        x: viewModel.bambooEntryOffset.width,
                        y: 22 + viewModel.bambooEntryOffset.height
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                    .transition(.opacity)
            }
        }
        .frame(width: 180, height: 200)
        .scaleEffect(y: viewModel.squashScale, anchor: .bottom)
    }

    private var head: some View {
        ZStack {
            // Floppy ears hang behind the head and drape down the sides
            floppyEar(side: -1)
            floppyEar(side: 1)

            // Head — light fur base with a darker fur cap over the top, clipped
            // to the head silhouette, then a rim-light and outline on top.
            ZStack {
                Ellipse().fill(furLight)
                Ellipse()
                    .fill(furDark)
                    .frame(width: 76, height: 44)
                    .offset(y: -20)
            }
            .frame(width: 72, height: 68)
            .clipShape(Ellipse())
            .overlay(
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                            center: UnitPoint(x: 0.3, y: 0.2),
                            startRadius: 1,
                            endRadius: 30
                        )
                    )
                    .frame(width: 72, height: 68)
                    .blendMode(.screen)
            )
            .overlay(
                Ellipse()
                    .stroke(outline, lineWidth: 1.7)
                    .frame(width: 72, height: 68)
            )

            // Eyes sit on the line where the cap meets the face
            eye(side: -1)
            eye(side: 1)

            // Blush
            Circle().fill(cheekColor).frame(width: 10, height: 8).offset(x: -23, y: 9).blur(radius: 1.5)
            Circle().fill(cheekColor).frame(width: 10, height: 8).offset(x: 23, y: 9).blur(radius: 1.5)

            // White snout
            Ellipse()
                .fill(Color.white.opacity(0.97))
                .frame(width: 40, height: 30)
                .offset(y: 13)
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                .overlay(
                    Ellipse()
                        .stroke(outline.opacity(0.4), lineWidth: 0.9)
                        .frame(width: 40, height: 30)
                        .offset(y: 13)
                )

            // Nose — glossy dark button
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.28, green: 0.18, blue: 0.14), Color(red: 0.1, green: 0.06, blue: 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 13, height: 10)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 4, height: 2.4)
                    .offset(x: -2, y: -2)
            }
            .offset(y: 4)

            // Mouth / tongue
            mouth
                .offset(y: 16)
        }
    }

    @ViewBuilder
    private func floppyEar(side: CGFloat) -> some View {
        let wiggle = Double(viewModel.earWiggle) * 5
        Ellipse()
            .fill(furDark)
            .frame(width: 26, height: 52)
            .overlay(
                // Soft inner-ear highlight
                Ellipse()
                    .fill(Color(red: 0.7, green: 0.42, blue: 0.42).opacity(0.45))
                    .frame(width: 13, height: 32)
                    .offset(y: 6)
                    .blur(radius: 1.5)
            )
            .overlay(
                Ellipse()
                    .stroke(outline.opacity(0.75), lineWidth: 1.3)
                    .frame(width: 26, height: 52)
            )
            .rotationEffect(.degrees(side * (20 + wiggle)), anchor: .top)
            .offset(x: side * 28, y: -28)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.earWiggle)
    }

    @ViewBuilder
    private func eye(side: CGFloat) -> some View {
        let baseX = side * 13
        let baseY: CGFloat = -3

        if viewModel.eyesHeart {
            Text("♥")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.5))
                .offset(x: baseX, y: baseY)
        } else if viewModel.eyesStarry {
            Text("✦")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.2))
                .offset(x: baseX, y: baseY)
        } else if viewModel.eyesClosed {
            HappyArc()
                .stroke(outline, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 13, height: 6)
                .offset(x: baseX, y: baseY)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: viewModel.eyesWide ? 14 : 12, height: viewModel.eyesWide ? 14 : 12)
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: viewModel.eyesWide ? 9 : 7.5, height: viewModel.eyesWide ? 9 : 7.5)
                    .offset(x: viewModel.lookDirection * 0.4, y: viewModel.lookVertical * 0.4)
                Circle()
                    .fill(Color.white)
                    .frame(width: 3.6, height: 3.6)
                    .offset(x: -1.6 + viewModel.lookDirection * 0.3, y: -1.6 + viewModel.lookVertical * 0.3)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 2)
                    .offset(x: 1.8, y: 1.6)
            }
            .offset(x: baseX + viewModel.lookDirection * 0.5, y: baseY + viewModel.lookVertical * 0.5)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch viewModel.mouthShape {
        case .smile:
            PuppySmile()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 22, height: 9)
        case .grin:
            ZStack {
                PuppyGrin()
                    .fill(Color(red: 0.4, green: 0.15, blue: 0.18))
                    .frame(width: 22, height: 11)
                // A little tongue peeking out of the grin
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.42, blue: 0.5))
                    .frame(width: 11, height: 7)
                    .offset(y: 4)
                PuppyGrin()
                    .stroke(outline, lineWidth: 1.3)
                    .frame(width: 22, height: 11)
            }
        case .open, .ohh:
            // Open pant — dark mouth with a lolling tongue
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.32, green: 0.1, blue: 0.12))
                    .frame(width: 15, height: 12)
                Ellipse()
                    .fill(Color(red: 0.96, green: 0.42, blue: 0.52))
                    .frame(width: 11, height: 12)
                    .offset(y: 5)
                    .overlay(
                        Capsule()
                            .fill(Color(red: 0.78, green: 0.26, blue: 0.36))
                            .frame(width: 1.6, height: 7)
                            .offset(y: 6)
                    )
                    .mask(
                        Ellipse().frame(width: 15, height: 22).offset(y: 5)
                    )
            }
        case .yawn:
            Ellipse()
                .fill(Color(red: 0.3, green: 0.1, blue: 0.12))
                .frame(width: 16, height: 15)
        }
    }

    @ViewBuilder
    private func hindLeg(side: CGFloat) -> some View {
        let stride = Double(viewModel.walkStride) * Double(side)
        let lift = max(0, viewModel.walkFootLift)
        Capsule()
            .fill(furLight)
            .frame(width: 16, height: 24)
            .overlay(Capsule().stroke(outline.opacity(0.7), lineWidth: 1.1).frame(width: 16, height: 24))
            .overlay(
                Ellipse()
                    .fill(pawPadColor.opacity(0.6))
                    .frame(width: 9, height: 4)
                    .offset(y: 9)
            )
            .offset(x: side * 24, y: 52 - lift * 0.5)
            .rotationEffect(.degrees(stride * 1.3), anchor: .top)
    }

    @ViewBuilder
    private func frontPaw(side: CGFloat, wave: Double, lift: CGFloat) -> some View {
        let clampedWave = max(-30, min(30, wave))
        let angle = clampedWave + Double(side) * 5
        Capsule()
            .fill(furLight)
            .frame(width: 14, height: 30)
            .overlay(Capsule().stroke(outline.opacity(0.7), lineWidth: 1.1).frame(width: 14, height: 30))
            .overlay(
                Ellipse()
                    .fill(pawPadColor.opacity(0.6))
                    .frame(width: 9, height: 4)
                    .offset(y: 12)
            )
            .offset(x: side * 19, y: 26 + lift)
            .rotationEffect(.degrees(angle), anchor: .top)
    }

    private var tail: some View {
        TailShape()
            .fill(furLight)
            .frame(width: 30, height: 18)
            .overlay(
                TailShape()
                    .stroke(outline.opacity(0.75), lineWidth: 1.2)
                    .frame(width: 30, height: 18)
            )
    }
}

private struct PuppySmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.midX
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: mid, y: rect.maxY),
                       control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
        return p
    }
}

private struct PuppyGrin: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.4))
        p.closeSubpath()
        return p
    }
}

// A plume tail — wide curl at the base tapering to a rounded tip.
private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.1, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.7, y: rect.minY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.width * 0.2, y: rect.maxY),
            control: CGPoint(x: rect.width * 0.55, y: rect.midY)
        )
        p.closeSubpath()
        return p
    }
}

private struct HappyArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}
