import SwiftUI

/// Procedural cartoon budgerigar. Wings open and flap whenever arm-wave state
/// is non-zero (so panda's wave / dance / drag-flail all drive the wings).
/// The head-bob from `bounceScale` doubles as a "chirp" motion. Gender swaps
/// plumage: girl → soft pink + violet, boy → classic budgie blue + yellow.
struct BudgieView: View {
    @ObservedObject var viewModel: PandaViewModel

    private var isBoy: Bool { viewModel.gender == .boy }

    private var bodyFill: LinearGradient {
        if isBoy {
            return LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.78, blue: 0.95),
                    Color(red: 0.28, green: 0.55, blue: 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.85, blue: 0.92),
                Color(red: 0.78, green: 0.55, blue: 0.78)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headFill: LinearGradient {
        if isBoy {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.93, blue: 0.55),
                    Color(red: 0.95, green: 0.78, blue: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.88, blue: 0.92),
                Color(red: 0.95, green: 0.72, blue: 0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var bellyFill: Color {
        isBoy ? Color(red: 0.85, green: 0.92, blue: 1.0) : Color(red: 1.0, green: 0.95, blue: 0.97)
    }

    private var beakFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.8, blue: 0.4),
                Color(red: 0.85, green: 0.55, blue: 0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private let footColor = Color(red: 0.95, green: 0.72, blue: 0.45)
    private let outline = Color(red: 0.1, green: 0.08, blue: 0.18).opacity(0.85)

    // Wing flap angle — wave state drives it (whenever panda would wave/dance,
    // the wings flap in sync). Greeting wave gets a fixed extra lift.
    private func wingAngle(side: CGFloat) -> Double {
        let wave = side < 0 ? viewModel.leftArmWave : viewModel.rightArmWave
        let greet = viewModel.greetingWave ? 30.0 : 0.0
        return wave + Double(side) * (28 + greet)
    }

    var body: some View {
        ZStack {
            budgieBody
        }
        .rotationEffect(.degrees(viewModel.headTilt))
        .rotationEffect(.degrees(viewModel.bodyRoll))
        .rotationEffect(.degrees(viewModel.dragSway), anchor: .top)
    }

    private var budgieBody: some View {
        ZStack {
            // Shadow / perch base
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 60, height: 9)
                .blur(radius: 3)
                .offset(y: 64)
                .scaleEffect(x: viewModel.shadowScale, y: 1, anchor: .center)

            // Tail feathers (fan back behind the body)
            tailFeathers
                .offset(x: 0, y: 58)
                .rotationEffect(.degrees(viewModel.dragSway * 0.5), anchor: .top)

            // Feet (cling to perch — lift when walking)
            foot(side: -1)
            foot(side: 1)

            // Body
            Ellipse()
                .fill(bodyFill)
                .frame(width: 58, height: 76)
                .offset(y: 26)
                .overlay(
                    Ellipse()
                        .stroke(outline, lineWidth: 1.5)
                        .frame(width: 58, height: 76)
                        .offset(y: 26)
                )

            // Belly highlight
            Ellipse()
                .fill(bellyFill)
                .frame(width: 30, height: 46)
                .offset(y: 32)
                .blur(radius: 1)

            // Wings — flap with arm-wave state
            wing(side: -1)
            wing(side: 1)

            // Head
            head
                .offset(y: -18)
        }
        .frame(width: 180, height: 200)
    }

    private var head: some View {
        ZStack {
            Circle()
                .fill(headFill)
                .frame(width: 56, height: 52)
                .overlay(Circle().stroke(outline, lineWidth: 1.5).frame(width: 56, height: 52))

            // Cheek dots — boys get blue, girls get violet (classic budgie spots)
            ForEach([-1, 1], id: \.self) { sign in
                Circle()
                    .fill(isBoy ? Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.8) : Color(red: 0.7, green: 0.5, blue: 0.85).opacity(0.8))
                    .frame(width: 7, height: 7)
                    .offset(x: CGFloat(sign) * 16, y: 10)
                    .blur(radius: 0.6)
            }

            // Eyes
            eye(side: -1)
            eye(side: 1)

            // Beak — opens for mouth shapes that need a chirp
            beak

            // Blush
            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.5 : 0.0))
                .frame(width: 9, height: 9)
                .offset(x: -19, y: 4)
                .blur(radius: 1.5)
            Circle()
                .fill(Color.pink.opacity(viewModel.blushVisible ? 0.5 : 0.0))
                .frame(width: 9, height: 9)
                .offset(x: 19, y: 4)
                .blur(radius: 1.5)
        }
    }

    @ViewBuilder
    private func eye(side: CGFloat) -> some View {
        let x = side * 11
        let y: CGFloat = -2

        if viewModel.eyesHeart {
            Text("♥")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(Color.pink)
                .offset(x: x, y: y)
        } else if viewModel.eyesStarry {
            Text("✦")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(Color.yellow)
                .offset(x: x, y: y)
        } else if viewModel.eyesClosed {
            HappyArc()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 10, height: 5)
                .offset(x: x, y: y)
        } else {
            ZStack {
                Circle()
                    .fill(outline)
                    .frame(width: viewModel.eyesWide ? 11 : 9, height: viewModel.eyesWide ? 11 : 9)
                Circle()
                    .fill(Color.white)
                    .frame(width: 3, height: 3)
                    .offset(x: viewModel.lookDirection * 0.3 - 1, y: viewModel.lookVertical * 0.3 - 1)
            }
            .offset(x: x, y: y)
        }
    }

    private var beakOpen: CGFloat {
        switch viewModel.mouthShape {
        case .smile, .grin: return 0
        case .open: return 5
        case .ohh: return 7
        case .yawn: return 9
        }
    }

    @ViewBuilder
    private var beak: some View {
        let open = beakOpen
        ZStack {
            // Upper beak
            BeakShape()
                .fill(beakFill)
                .frame(width: 16, height: 12)
                .overlay(BeakShape().stroke(outline.opacity(0.7), lineWidth: 1).frame(width: 16, height: 12))
                .offset(y: 12)

            // Lower beak — drops when mouth is open
            if open > 0 {
                BeakShape()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.55, blue: 0.18),
                            Color(red: 0.65, green: 0.35, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 14, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(y: 12 + open)
                    .overlay(
                        BeakShape()
                            .stroke(outline.opacity(0.7), lineWidth: 1)
                            .frame(width: 14, height: 10)
                            .rotationEffect(.degrees(180))
                            .offset(y: 12 + open)
                    )
            }
        }
    }

    @ViewBuilder
    private func wing(side: CGFloat) -> some View {
        WingShape()
            .fill(bodyFill)
            .frame(width: 30, height: 50)
            .overlay(
                WingShape()
                    .stroke(outline, lineWidth: 1.4)
                    .frame(width: 30, height: 50)
            )
            // Striped barring across the wing — classic budgie look.
            .overlay(
                VStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule()
                            .fill(outline.opacity(0.55))
                            .frame(height: 1.2)
                    }
                }
                .frame(width: 22)
                .clipShape(WingShape())
                .frame(width: 30, height: 50)
            )
            .scaleEffect(x: side, y: 1)
            .offset(x: side * 22, y: 18)
            .rotationEffect(.degrees(wingAngle(side: side)), anchor: .top)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.leftArmWave)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.rightArmWave)
    }

    private var tailFeathers: some View {
        ZStack {
            ForEach(-1...1, id: \.self) { i in
                Capsule()
                    .fill(bodyFill)
                    .frame(width: 6, height: 26)
                    .overlay(Capsule().stroke(outline.opacity(0.6), lineWidth: 0.8).frame(width: 6, height: 26))
                    .rotationEffect(.degrees(Double(i) * 14))
                    .offset(y: 8)
            }
        }
    }

    @ViewBuilder
    private func foot(side: CGFloat) -> some View {
        let lift = max(0, viewModel.walkFootLift)
        let stride = Double(viewModel.walkStride) * Double(side)
        ZStack {
            // Three little toes splayed out
            ForEach(-1...1, id: \.self) { i in
                Capsule()
                    .fill(footColor)
                    .frame(width: 3, height: 8)
                    .overlay(Capsule().stroke(outline.opacity(0.6), lineWidth: 0.7).frame(width: 3, height: 8))
                    .rotationEffect(.degrees(Double(i) * 22))
                    .offset(y: 2)
            }
            // Stubby leg
            Capsule()
                .fill(footColor)
                .frame(width: 4, height: 10)
                .offset(y: -6)
        }
        .offset(x: side * 10, y: 60 - lift * 0.3)
        .rotationEffect(.degrees(stride * 1.2), anchor: .top)
    }
}

private struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: 0)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: 0),
            control: CGPoint(x: rect.minX, y: rect.maxY * 0.6)
        )
        p.closeSubpath()
        return p
    }
}

private struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX * 0.85, y: rect.maxY * 0.8))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: 0),
                       control: CGPoint(x: rect.maxX * 0.15, y: rect.maxY * 0.8))
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
