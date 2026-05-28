import SwiftUI
import AppKit

struct PandaContainerView: View {
    @ObservedObject var viewModel: PandaViewModel
    @State private var dragStarted = false
    @State private var dragStartLocation: CGPoint?
    @State private var lastMouseLocation: CGPoint?

    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())

            ZStack {
                PandaView(viewModel: viewModel)
                    .scaleEffect(viewModel.bounceScale)
                    .offset(y: viewModel.bodyOffsetY)

                ForEach(viewModel.particles) { spawn in
                    ParticleView(spawn: spawn)
                }
            }
            .frame(width: 140, height: 160)
            .scaleEffect(viewModel.size.multiplier)
        }
        .frame(width: 140 * viewModel.size.multiplier, height: 160 * viewModel.size.multiplier)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Use NSEvent.mouseLocation (true screen coords). SwiftUI's
                    // `.global` is window-relative, so it moves with the window
                    // while we drag — gives wrong deltas.
                    let mouse = NSEvent.mouseLocation
                    if dragStartLocation == nil {
                        dragStartLocation = mouse
                    }
                    if !dragStarted {
                        if let start = dragStartLocation {
                            let dist = hypot(mouse.x - start.x, mouse.y - start.y)
                            if dist < 4 {
                                return
                            }
                        }
                        dragStarted = true
                        lastMouseLocation = mouse
                        viewModel.beginDrag()
                        return
                    }
                    if let last = lastMouseLocation {
                        let dx = mouse.x - last.x
                        let dy = mouse.y - last.y
                        viewModel.onMoveBy?(dx, dy)
                        viewModel.updateDrag(velocityX: dx)
                    }
                    lastMouseLocation = mouse
                }
                .onEnded { _ in
                    if dragStarted {
                        dragStarted = false
                        viewModel.endDrag()
                    } else {
                        viewModel.pat()
                    }
                    lastMouseLocation = nil
                    dragStartLocation = nil
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
