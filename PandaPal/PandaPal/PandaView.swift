import SwiftUI

struct PandaView: View {
    @ObservedObject var viewModel: PandaViewModel

    private let bodyFill = LinearGradient(
        colors: [Color(white: 1.0), Color(white: 0.94)],
        startPoint: .top,
        endPoint: .bottom
    )

    private let darkFill = LinearGradient(
        colors: [Color(white: 0.22), Color(white: 0.08)],
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
            // Soft drop shadow under the panda
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 70, height: 8)
                .blur(radius: 3)
                .offset(y: 62)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Body
            Ellipse()
                .fill(bodyFill)
                .frame(width: 64, height: 74)
                .offset(y: 20)
                .overlay(
                    Ellipse()
                        .stroke(Color(white: 0.15), lineWidth: 2)
                        .frame(width: 64, height: 74)
                        .offset(y: 20)
                )

            // Belly highlight (subtle lighter spot)
            Ellipse()
                .fill(Color.white.opacity(0.7))
                .frame(width: 30, height: 36)
                .offset(x: -4, y: 22)
                .blur(radius: 4)

            // Legs
            leg(side: -1)
            leg(side: 1)

            // Arms
            arm(side: -1, raised: viewModel.leftArmRaised, wave: viewModel.leftArmWave)
            arm(side: 1, raised: viewModel.rightArmRaised, wave: viewModel.rightArmWave)

            // Bamboo (held during eating)
            if viewModel.bambooVisible {
                BambooStick()
                    .offset(x: 0, y: -2)
                    .rotationEffect(.degrees(viewModel.bambooTilt))
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

            // Head shape
            Circle()
                .fill(bodyFill)
                .frame(width: 68, height: 68)
                .offset(y: -12)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.15), lineWidth: 2)
                        .frame(width: 68, height: 68)
                        .offset(y: -12)
                )

            // Eye patches
            eyePatch(side: -1)
            eyePatch(side: 1)

            // Eyes
            eye(side: -1)
            eye(side: 1)

            // Cheeks (always faintly visible)
            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.55 : 0.18))
                .frame(width: 11, height: 9)
                .offset(x: -22, y: -2)
                .blur(radius: 1)

            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.55 : 0.18))
                .frame(width: 11, height: 9)
                .offset(x: 22, y: -2)
                .blur(radius: 1)

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
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color.pink.opacity(0.4))
                .frame(width: 11, height: 11)
        }
        .offset(x: 23 * side, y: -38 + (viewModel.earWiggle * (side == -1 ? 1 : -1)))
    }

    private func eyePatch(side: CGFloat) -> some View {
        Ellipse()
            .fill(darkFill)
            .frame(width: 22, height: 24)
            .rotationEffect(.degrees(side == -1 ? -15 : 15))
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
                    .frame(width: 3.2, height: 3.2)
                    .offset(x: -1.6 + lookX * 0.3, y: -1.6 + lookY * 0.3)

                // Tiny secondary highlight
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 1.6, height: 1.6)
                    .offset(x: 1.8 + lookX * 0.3, y: 1.4 + lookY * 0.3)
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
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.7, blue: 0.75))
                    .frame(width: 6, height: 3)
                    .offset(y: 2)
            }
            .offset(y: 4)
        case .grin:
            GrinPath()
                .fill(Color(red: 0.95, green: 0.45, blue: 0.5))
                .frame(width: 16, height: 8)
                .offset(y: 4)
                .overlay(
                    GrinPath()
                        .stroke(Color(white: 0.15), lineWidth: 1.4)
                        .frame(width: 16, height: 8)
                        .offset(y: 4)
                )
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
        Ellipse()
            .fill(darkFill)
            .frame(width: 24, height: 20)
            .offset(x: 14 * side, y: 54)
    }

    private func arm(side: CGFloat, raised: Bool, wave: Double) -> some View {
        let angleDown: Double = side == -1 ? 15 : -15
        let angleUp: Double = side == -1 ? -55 : 55
        let angle = raised ? angleUp + wave : angleDown

        return Ellipse()
            .fill(darkFill)
            .frame(width: 18, height: 30)
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(x: 32 * side, y: raised ? 2 : 18)
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

struct BambooStick: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.78, blue: 0.35), Color(red: 0.35, green: 0.6, blue: 0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 8, height: 36)
                .overlay(
                    VStack(spacing: 8) {
                        Capsule().fill(Color(red: 0.25, green: 0.45, blue: 0.15)).frame(height: 1.5)
                        Capsule().fill(Color(red: 0.25, green: 0.45, blue: 0.15)).frame(height: 1.5)
                        Capsule().fill(Color(red: 0.25, green: 0.45, blue: 0.15)).frame(height: 1.5)
                    }
                    .frame(width: 8)
                )

            // Leaf
            Ellipse()
                .fill(Color(red: 0.5, green: 0.8, blue: 0.3))
                .frame(width: 14, height: 6)
                .rotationEffect(.degrees(-35))
                .offset(x: 8, y: -16)
        }
    }
}
