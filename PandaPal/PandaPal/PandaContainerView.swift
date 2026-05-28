import SwiftUI

struct PandaContainerView: View {
    @ObservedObject var viewModel: PandaViewModel
    @State private var lastDragLocation: CGPoint?
    @State private var dragStarted = false

    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())

            PandaView(viewModel: viewModel)
                .scaleEffect(viewModel.bounceScale)
                .offset(y: viewModel.bodyOffsetY)

            ForEach(viewModel.particles) { spawn in
                ParticleView(spawn: spawn)
            }
        }
        .frame(width: 140, height: 160)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let translation = value.translation
                    let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                    if !dragStarted {
                        // Only treat as drag once movement exceeds a tap threshold.
                        if distance < 4 {
                            return
                        }
                        dragStarted = true
                        viewModel.beginDrag()
                    }
                    let current = value.location
                    if let last = lastDragLocation {
                        let dx = current.x - last.x
                        let dy = current.y - last.y
                        viewModel.onMoveBy?(dx, dy)
                        viewModel.updateDrag(velocityX: dx)
                    }
                    lastDragLocation = current
                }
                .onEnded { value in
                    let translation = value.translation
                    let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                    if dragStarted {
                        dragStarted = false
                        lastDragLocation = nil
                        viewModel.endDrag()
                    } else if distance < 4 {
                        viewModel.pat()
                    }
                }
        )
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
