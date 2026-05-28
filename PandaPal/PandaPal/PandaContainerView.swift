import SwiftUI

struct PandaContainerView: View {
    @ObservedObject var viewModel: PandaViewModel

    var body: some View {
        ZStack {
            Color.clear

            PandaView(viewModel: viewModel)
                .scaleEffect(viewModel.bounceScale)
                .offset(y: viewModel.bodyOffsetY)
                .onTapGesture { viewModel.pat() }

            ForEach(viewModel.particles) { spawn in
                ParticleView(spawn: spawn)
            }
        }
        .frame(width: 140, height: 160)
    }
}

struct ParticleView: View {
    let spawn: PandaParticleSpawn

    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Text(spawn.particle.glyph)
            .font(.system(size: 18))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(
                x: spawn.offset.width + xOffset,
                y: spawn.offset.height + yOffset
            )
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: spawn.lifetime)) {
                    yOffset = -38
                    xOffset = spawn.driftX
                    opacity = 0
                }
            }
    }
}
