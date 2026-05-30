import SwiftUI

/// Procedural cartoon puppy. Shares PandaViewModel state with the other pets:
/// eyes/mouth state drive the face, headTilt + dragSway rotate the whole pup,
/// arm waves drive the front paws, and the tail wags whenever earWiggle or
/// blushVisible (happy idles) fire. Drawing-only — no behaviour lives here.
struct PuppyView: View {
    @ObservedObject var viewModel: PandaViewModel

    private let furLight = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.86, blue: 0.66),
            Color(red: 0.93, green: 0.75, blue: 0.5),
            Color(red: 0.78, green: 0.58, blue: 0.34)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let furDark = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.36, blue: 0.18),
            Color(red: 0.34, green: 0.21, blue: 0.1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let outline = Color(red: 0.18, green: 0.1, blue: 0.05).opacity(0.85)

    private var bellyFill: Color { Color(red: 1.0, green: 0.94, blue: 0.84) }
    private var pawPadColor: Color { Color(red: 0.85, green: 0.45, blue: 0.45).opacity(0.7) }
    private var cheekColor: Color {
        Color.pink.opacity(viewModel.blushVisible ? 0.55 : 0.22)
    }

    // The tail wags continuously whenever earWiggle is nonzero (happy idle) or
    // greetingWave fires; clamp gives a sane angle without an extra state field.
    private var tailWag: Double {
        let base = Double(viewModel.earWiggle) * 8
        let greet = viewModel.greetingWave ? 24.0 : 0.0
        return base + greet
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
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 78, height: 11)
                .blur(radius: 4)
                .offset(y: 64)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Tail — curls behind the body, wags with state
            tail
                .offset(x: 32, y: 20)
                .rotationEffect(.degrees(tailWag + 18), anchor: .bottomLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: tailWag)

            // Body
            Ellipse()
                .fill(furLight)
                .frame(width: 72, height: 70)
                .offset(y: 24)
                .overlay(
                    Ellipse()
                        .stroke(outline, lineWidth: 1.6)
                        .frame(width: 72, height: 70)
                        .offset(y: 24)
                )

            // Belly
            Ellipse()
                .fill(bellyFill)
                .frame(width: 38, height: 44)
                .offset(y: 30)

            // Back legs (or sitting pose tucks them under)
            if !viewModel.sitting {
                backLeg(side: -1)
                backLeg(side: 1)
            }

            // Front paws — driven by leftArmWave / rightArmWave like the panda
            frontPaw(side: -1, wave: viewModel.leftArmWave, lift: CGFloat(viewModel.greetingWave ? -6 : 0))
            frontPaw(side: 1, wave: viewModel.rightArmWave, lift: 0)

            // Head
            head
                .offset(y: -14)
        }
        .frame(width: 180, height: 200)
    }

    private var head: some View {
        ZStack {
            // Skull
            Circle()
                .fill(furLight)
                .frame(width: 70, height: 66)
                .overlay(Circle().stroke(outline, lineWidth: 1.6).frame(width: 70, height: 66))

            // Top patch (a darker fur cap, gives the puppy character)
            HeadPatch()
                .fill(furDark)
                .frame(width: 60, height: 38)
                .offset(y: -14)

            // Floppy ears — wiggle with earWiggle
            floppyEar(side: -1)
            floppyEar(side: 1)

            // Muzzle (white snout)
            Ellipse()
                .fill(Color.white.opacity(0.96))
                .frame(width: 38, height: 28)
                .offset(y: 10)
                .overlay(
                    Ellipse()
                        .stroke(outline.opacity(0.5), lineWidth: 1)
                        .frame(width: 38, height: 28)
                        .offset(y: 10)
                )

            // Nose
            Ellipse()
                .fill(outline)
                .frame(width: 11, height: 8)
                .offset(y: 2)

            // Eyes
            eye(side: -1)
            eye(side: 1)

            // Cheeks
            Circle()
                .fill(cheekColor)
                .frame(width: 9, height: 9)
                .offset(x: -22, y: 8)
                .blur(radius: 1.5)
            Circle()
                .fill(cheekColor)
                .frame(width: 9, height: 9)
                .offset(x: 22, y: 8)
                .blur(radius: 1.5)

            // Mouth
            mouth
                .offset(y: 14)
        }
    }

    @ViewBuilder
    private func floppyEar(side: CGFloat) -> some View {
        let wiggle = Double(viewModel.earWiggle) * 6
        FloppyEarShape(side: side)
            .fill(furDark)
            .frame(width: 22, height: 38)
            .overlay(
                FloppyEarShape(side: side)
                    .stroke(outline.opacity(0.7), lineWidth: 1.2)
                    .frame(width: 22, height: 38)
            )
            .offset(x: side * 28, y: -2)
            .rotationEffect(.degrees(side * (12 + wiggle)), anchor: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.earWiggle)
    }

    @ViewBuilder
    private func eye(side: CGFloat) -> some View {
        let x = side * 12
        let y: CGFloat = -4

        if viewModel.eyesHeart {
            Text("♥")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color.pink)
                .offset(x: x, y: y)
        } else if viewModel.eyesStarry {
            Text("✦")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color.yellow)
                .offset(x: x, y: y)
        } else if viewModel.eyesClosed {
            HappyArc()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 12, height: 6)
                .offset(x: x, y: y)
        } else {
            ZStack {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: viewModel.eyesWide ? 13 : 10, height: viewModel.eyesWide ? 13 : 10)
                Ellipse()
                    .fill(outline)
                    .frame(width: viewModel.eyesWide ? 7 : 6, height: viewModel.eyesWide ? 7 : 6)
                    .offset(x: viewModel.lookDirection * 0.4, y: viewModel.lookVertical * 0.4)
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 2.2, height: 2.2)
                    .offset(x: -1.5, y: -1.5)
            }
            .offset(x: x, y: y)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch viewModel.mouthShape {
        case .smile:
            PuppySmile()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 22, height: 10)
        case .grin:
            PuppyGrin()
                .fill(Color(red: 0.4, green: 0.15, blue: 0.18))
                .frame(width: 22, height: 12)
                .overlay(
                    PuppyGrin().stroke(outline, lineWidth: 1.2).frame(width: 22, height: 12)
                )
        case .open, .ohh:
            // Open-mouth pant — includes a tongue lolling out
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.32, green: 0.1, blue: 0.12))
                    .frame(width: 14, height: 11)
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.4, blue: 0.5))
                    .frame(width: 10, height: 9)
                    .offset(y: 3)
                    .overlay(
                        Capsule()
                            .fill(Color(red: 0.75, green: 0.25, blue: 0.35))
                            .frame(width: 1.5, height: 6)
                            .offset(y: 4)
                    )
            }
        case .yawn:
            Ellipse()
                .fill(Color(red: 0.3, green: 0.1, blue: 0.12))
                .frame(width: 16, height: 14)
        }
    }

    @ViewBuilder
    private func backLeg(side: CGFloat) -> some View {
        let stride = Double(viewModel.walkStride) * Double(side)
        let lift = max(0, viewModel.walkFootLift)
        Capsule()
            .fill(furLight)
            .frame(width: 14, height: 22)
            .overlay(Capsule().stroke(outline.opacity(0.7), lineWidth: 1.1).frame(width: 14, height: 22))
            .overlay(
                Ellipse()
                    .fill(pawPadColor)
                    .frame(width: 8, height: 4)
                    .offset(y: 8)
            )
            .offset(x: side * 22, y: 52 - lift * 0.5)
            .rotationEffect(.degrees(stride * 1.4), anchor: .top)
    }

    @ViewBuilder
    private func frontPaw(side: CGFloat, wave: Double, lift: CGFloat) -> some View {
        let angle = wave + Double(side) * 6
        Capsule()
            .fill(furLight)
            .frame(width: 13, height: 28)
            .overlay(Capsule().stroke(outline.opacity(0.7), lineWidth: 1.1).frame(width: 13, height: 28))
            .overlay(
                Ellipse()
                    .fill(pawPadColor)
                    .frame(width: 8, height: 4)
                    .offset(y: 11)
            )
            .offset(x: side * 18, y: 28 + lift)
            .rotationEffect(.degrees(angle), anchor: .top)
    }

    private var tail: some View {
        TailShape()
            .fill(furLight)
            .frame(width: 28, height: 14)
            .overlay(
                TailShape()
                    .stroke(outline.opacity(0.75), lineWidth: 1.1)
                    .frame(width: 28, height: 14)
            )
    }
}

private struct FloppyEarShape: Shape {
    let side: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(
            to: CGPoint(x: w * (side > 0 ? 0.05 : 0.95), y: h * 0.95),
            control1: CGPoint(x: w * (side > 0 ? 0.0 : 1.0), y: h * 0.25),
            control2: CGPoint(x: w * (side > 0 ? 0.1 : 0.9), y: h * 0.85)
        )
        p.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.1),
            control: CGPoint(x: w * (side > 0 ? 0.55 : 0.45), y: h * 0.6)
        )
        p.closeSubpath()
        return p
    }
}

private struct HeadPatch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.1))
        return p
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
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 2),
            control1: CGPoint(x: rect.width * 0.4, y: rect.midY - rect.height * 0.4),
            control2: CGPoint(x: rect.width * 0.7, y: rect.minY)
        )
        p.addQuadCurve(
            to: CGPoint(x: 0, y: rect.midY + 3),
            control: CGPoint(x: rect.width * 0.4, y: rect.maxY)
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
