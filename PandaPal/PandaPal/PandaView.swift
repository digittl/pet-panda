import SwiftUI

struct PandaView: View {
    @ObservedObject var viewModel: PandaViewModel

    var body: some View {
        ZStack {
            pandaBody
        }
        .rotationEffect(.degrees(viewModel.headTilt))
    }

    private var pandaBody: some View {
        ZStack {
            // Body (white oval)
            Ellipse()
                .fill(Color.white)
                .frame(width: 60, height: 70)
                .offset(y: 20)

            // Body outline
            Ellipse()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 60, height: 70)
                .offset(y: 20)

            // Left leg
            Ellipse()
                .fill(Color(white: 0.15))
                .frame(width: 22, height: 18)
                .offset(x: -14, y: 52)

            // Right leg
            Ellipse()
                .fill(Color(white: 0.15))
                .frame(width: 22, height: 18)
                .offset(x: 14, y: 52)

            // Left arm
            leftArm

            // Right arm
            rightArm

            // Head (white circle)
            Circle()
                .fill(Color.white)
                .frame(width: 64, height: 64)
                .offset(y: -12)

            // Head outline
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 64, height: 64)
                .offset(y: -12)

            // Left ear
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: 22, height: 22)
                .offset(x: -22, y: -38)

            // Right ear
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: 22, height: 22)
                .offset(x: 22, y: -38)

            // Inner left ear
            Circle()
                .fill(Color(white: 0.4))
                .frame(width: 10, height: 10)
                .offset(x: -22, y: -38)

            // Inner right ear
            Circle()
                .fill(Color(white: 0.4))
                .frame(width: 10, height: 10)
                .offset(x: 22, y: -38)

            // Eye patches (dark circles around eyes)
            Ellipse()
                .fill(Color(white: 0.15))
                .frame(width: 20, height: 22)
                .offset(x: -12 + viewModel.lookDirection * 0.3, y: -14)

            Ellipse()
                .fill(Color(white: 0.15))
                .frame(width: 20, height: 22)
                .offset(x: 12 + viewModel.lookDirection * 0.3, y: -14)

            // Eyes
            if viewModel.eyesClosed {
                // Closed eyes - horizontal lines
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 10, height: 2)
                    .offset(x: -12 + viewModel.lookDirection * 0.5, y: -14)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 10, height: 2)
                    .offset(x: 12 + viewModel.lookDirection * 0.5, y: -14)
            } else {
                // Open eyes - white circles with pupils
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: -12 + viewModel.lookDirection * 0.5, y: -14)

                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: 12 + viewModel.lookDirection * 0.5, y: -14)

                // Pupils
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                    .offset(x: -12 + viewModel.lookDirection, y: -13)

                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                    .offset(x: 12 + viewModel.lookDirection, y: -13)

                // Eye highlights
                Circle()
                    .fill(Color.white)
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: -13 + viewModel.lookDirection, y: -15)

                Circle()
                    .fill(Color.white)
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 11 + viewModel.lookDirection, y: -15)
            }

            // Nose
            Ellipse()
                .fill(Color(white: 0.2))
                .frame(width: 8, height: 6)
                .offset(y: -4)

            // Mouth
            if viewModel.mouthOpen {
                // Happy open mouth
                Ellipse()
                    .fill(Color(red: 0.9, green: 0.4, blue: 0.4))
                    .frame(width: 12, height: 8)
                    .offset(y: 2)
            } else {
                // Small smile using a curved path
                SmilePath()
                    .stroke(Color(white: 0.2), lineWidth: 1.5)
                    .frame(width: 14, height: 6)
                    .offset(y: 2)
            }

            // Blush
            if viewModel.blushVisible {
                Circle()
                    .fill(Color.pink.opacity(0.4))
                    .frame(width: 12, height: 12)
                    .offset(x: -20, y: -4)

                Circle()
                    .fill(Color.pink.opacity(0.4))
                    .frame(width: 12, height: 12)
                    .offset(x: 20, y: -4)
            }
        }
    }

    private var leftArm: some View {
        Ellipse()
            .fill(Color(white: 0.15))
            .frame(width: 18, height: 28)
            .rotationEffect(.degrees(viewModel.leftArmRaised ? -45 : 15), anchor: .top)
            .offset(x: -32, y: viewModel.leftArmRaised ? 5 : 18)
    }

    private var rightArm: some View {
        Ellipse()
            .fill(Color(white: 0.15))
            .frame(width: 18, height: 28)
            .rotationEffect(.degrees(viewModel.rightArmRaised ? 45 : -15), anchor: .top)
            .offset(x: 32, y: viewModel.rightArmRaised ? 5 : 18)
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
