import SwiftUI

struct PandaContainerView: View {
    @ObservedObject var viewModel: PandaViewModel

    var body: some View {
        ZStack {
            Color.clear

            PandaView(viewModel: viewModel)
                .scaleEffect(viewModel.bounceScale)
                .offset(y: viewModel.bodyOffsetY)
                .onTapGesture {
                    viewModel.pat()
                }

            if viewModel.heartVisible {
                HeartParticleView()
                    .offset(x: 30, y: -50)
                    .transition(.opacity)
            }

            if viewModel.zzzVisible {
                ZzzView()
                    .offset(x: 35, y: -45)
                    .transition(.opacity)
            }
        }
        .frame(width: 120, height: 140)
    }
}

struct HeartParticleView: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("❤️")
            .font(.system(size: 20))
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offset = -20
                    opacity = 0
                }
            }
    }
}

struct ZzzView: View {
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 2) {
            Text("z")
                .font(.system(size: 8, weight: .bold))
                .offset(x: 8, y: -4)
            Text("z")
                .font(.system(size: 10, weight: .bold))
                .offset(x: 4)
            Text("Z")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.gray)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 1
            }
        }
    }
}
