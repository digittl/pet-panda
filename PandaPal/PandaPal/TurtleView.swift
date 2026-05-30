import SwiftUI

/// Procedural cartoon turtle. Signature trick: when `sitting` is true (the
/// shared "rest" pose) or the mouth shows shock (`ohh` + eyesClosed), he
/// retracts his head and limbs into the shell. Everything else (eyes, blink,
/// drag sway, arm wave → flipper sway) maps from the same shared state knobs
/// as the other pets.
struct TurtleView: View {
    @ObservedObject var viewModel: PandaViewModel

    private let shellOuter = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.32, blue: 0.13),
            Color(red: 0.35, green: 0.2, blue: 0.08)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let shellInner = LinearGradient(
        colors: [
            Color(red: 0.74, green: 0.5, blue: 0.22),
            Color(red: 0.5, green: 0.3, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let skinFill = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.78, blue: 0.42),
            Color(red: 0.35, green: 0.58, blue: 0.28)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let bellyFill = Color(red: 0.95, green: 0.88, blue: 0.6)
    private let outline = Color(red: 0.12, green: 0.15, blue: 0.08).opacity(0.85)

    // Retract trigger: sitting pose, or a scared "ohh" with closed eyes
    // (the panda's startle/wake reaction also fires those together).
    private var retracted: Bool {
        viewModel.sitting || (viewModel.mouthShape == .ohh && viewModel.eyesClosed)
    }

    // Head/limbs slide a few px back into the shell when retracted.
    private var retractDistance: CGFloat { retracted ? 18 : 0 }

    var body: some View {
        ZStack {
            turtleBody
        }
        .rotationEffect(.degrees(viewModel.headTilt))
        .rotationEffect(.degrees(viewModel.bodyRoll))
        .rotationEffect(.degrees(viewModel.dragSway), anchor: .top)
    }

    private var turtleBody: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 84, height: 10)
                .blur(radius: 4)
                .offset(y: 50)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Back limbs (peek out below shell)
            backFlipper(side: -1)
            backFlipper(side: 1)

            // Tail
            Triangle()
                .fill(skinFill)
                .frame(width: 12, height: 14)
                .overlay(
                    Triangle()
                        .stroke(outline.opacity(0.7), lineWidth: 1.1)
                        .frame(width: 12, height: 14)
                )
                .rotationEffect(.degrees(180))
                .offset(x: 32, y: 24)

            // Front flippers — driven by arm-wave state
            frontFlipper(side: -1, wave: viewModel.leftArmWave)
            frontFlipper(side: 1, wave: viewModel.rightArmWave)

            // Head — slides in/out of the shell
            head
                .offset(x: 0, y: 4 + retractDistance)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: retracted)

            // Shell on top
            shell
                .offset(y: 16)
        }
        .frame(width: 180, height: 200)
    }

    private var shell: some View {
        ZStack {
            // Lower belly (cream plastron, peeks below the dome)
            Capsule()
                .fill(bellyFill)
                .frame(width: 88, height: 24)
                .offset(y: 28)
                .overlay(
                    Capsule()
                        .stroke(outline.opacity(0.6), lineWidth: 1.2)
                        .frame(width: 88, height: 24)
                        .offset(y: 28)
                )

            // Shell dome
            ShellDome()
                .fill(shellOuter)
                .frame(width: 100, height: 70)
                .overlay(
                    ShellDome()
                        .stroke(outline, lineWidth: 1.8)
                        .frame(width: 100, height: 70)
                )

            // Inner plates — a six-piece honeycomb pattern.
            ZStack {
                ForEach(0..<6, id: \.self) { idx in
                    let angle = Double(idx) * 60
                    Hexagon()
                        .fill(shellInner)
                        .frame(width: 18, height: 16)
                        .overlay(
                            Hexagon()
                                .stroke(outline.opacity(0.7), lineWidth: 1)
                                .frame(width: 18, height: 16)
                        )
                        .offset(x: CGFloat(cos(angle * .pi / 180) * 22),
                                y: CGFloat(sin(angle * .pi / 180) * 16) - 6)
                }
                Hexagon()
                    .fill(shellInner)
                    .frame(width: 22, height: 20)
                    .overlay(Hexagon().stroke(outline.opacity(0.7), lineWidth: 1).frame(width: 22, height: 20))
                    .offset(y: -6)
            }
            .offset(y: -2)
        }
    }

    private var head: some View {
        ZStack {
            // Neck (peeks out from under the shell when not retracted)
            Capsule()
                .fill(skinFill)
                .frame(width: 16, height: 22)
                .offset(y: 0)
                .overlay(
                    Capsule()
                        .stroke(outline.opacity(0.7), lineWidth: 1)
                        .frame(width: 16, height: 22)
                )

            // Head
            Ellipse()
                .fill(skinFill)
                .frame(width: 44, height: 38)
                .offset(y: -22)
                .overlay(
                    Ellipse()
                        .stroke(outline, lineWidth: 1.6)
                        .frame(width: 44, height: 38)
                        .offset(y: -22)
                )

            // Eyes
            eye(side: -1)
            eye(side: 1)

            // Cheeks
            Circle()
                .fill(Color(red: 1, green: 0.7, blue: 0.5).opacity(viewModel.blushVisible ? 0.55 : 0.25))
                .frame(width: 6, height: 6)
                .offset(x: -14, y: -16)
                .blur(radius: 1.2)
            Circle()
                .fill(Color(red: 1, green: 0.7, blue: 0.5).opacity(viewModel.blushVisible ? 0.55 : 0.25))
                .frame(width: 6, height: 6)
                .offset(x: 14, y: -16)
                .blur(radius: 1.2)

            // Mouth
            mouth.offset(y: -14)
        }
        .opacity(retracted ? 0.0 : 1.0)
    }

    @ViewBuilder
    private func eye(side: CGFloat) -> some View {
        let x = side * 9
        let y: CGFloat = -26

        if viewModel.eyesHeart {
            Text("♥")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Color.pink)
                .offset(x: x, y: y)
        } else if viewModel.eyesStarry {
            Text("✦")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Color.yellow)
                .offset(x: x, y: y)
        } else if viewModel.eyesClosed {
            HappyArc()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 9, height: 5)
                .offset(x: x, y: y)
        } else {
            ZStack {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: viewModel.eyesWide ? 11 : 9, height: viewModel.eyesWide ? 11 : 9)
                Ellipse()
                    .fill(outline)
                    .frame(width: 5, height: 5)
                    .offset(x: viewModel.lookDirection * 0.35, y: viewModel.lookVertical * 0.35)
            }
            .offset(x: x, y: y)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch viewModel.mouthShape {
        case .smile:
            HappyArc()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 12, height: 5)
        case .grin:
            Capsule()
                .fill(outline)
                .frame(width: 16, height: 3)
        case .open, .ohh:
            Ellipse()
                .fill(Color(red: 0.4, green: 0.18, blue: 0.18))
                .frame(width: 10, height: 6)
        case .yawn:
            Ellipse()
                .fill(Color(red: 0.4, green: 0.18, blue: 0.18))
                .frame(width: 14, height: 10)
        }
    }

    @ViewBuilder
    private func frontFlipper(side: CGFloat, wave: Double) -> some View {
        let angle = wave + Double(side) * 18
        FlipperShape()
            .fill(skinFill)
            .frame(width: 22, height: 18)
            .overlay(
                FlipperShape()
                    .stroke(outline.opacity(0.7), lineWidth: 1)
                    .frame(width: 22, height: 18)
            )
            .scaleEffect(x: side, y: 1)
            .offset(x: side * (24 - retractDistance * 0.4), y: 22)
            .rotationEffect(.degrees(angle), anchor: .topTrailing)
            .opacity(retracted ? 0.0 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: retracted)
    }

    @ViewBuilder
    private func backFlipper(side: CGFloat) -> some View {
        let stride = Double(viewModel.walkStride) * Double(side)
        Capsule()
            .fill(skinFill)
            .frame(width: 14, height: 12)
            .overlay(Capsule().stroke(outline.opacity(0.7), lineWidth: 1).frame(width: 14, height: 12))
            .offset(x: side * (28 - retractDistance * 0.4), y: 38 - max(0, viewModel.walkFootLift) * 0.4)
            .rotationEffect(.degrees(stride * 0.8 + Double(side) * 12))
            .opacity(retracted ? 0.0 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: retracted)
    }
}

private struct ShellDome: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.2)
        )
        p.closeSubpath()
        return p
    }
}

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.25, y: 0))
        p.addLine(to: CGPoint(x: w * 0.75, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.75, y: h))
        p.addLine(to: CGPoint(x: w * 0.25, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.5))
        p.closeSubpath()
        return p
    }
}

private struct FlipperShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
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
