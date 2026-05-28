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
            .frame(width: 180, height: 200)
            .scaleEffect(viewModel.size.multiplier)
        }
        .frame(width: 180 * viewModel.size.multiplier, height: 200 * viewModel.size.multiplier)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Pet") {
                viewModel.pet()
            }

            Button("Walk") {
                viewModel.forceWander()
            }

            Button("Feed") {
                viewModel.feedBamboo()
            }

            Menu("Size") {
                ForEach(PandaSize.allCases, id: \.self) { size in
                    Button(size.label + (viewModel.size == size ? " (Current)" : "")) {
                        viewModel.requestSize(size)
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
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
                        // Snapshot the offset between mouse and window corner
                        // so we can pin the window to the cursor absolutely.
                        viewModel.onCaptureDragOffset?()
                    }
                    // Recompute window origin from current mouse position every
                    // event — no delta accumulation, no drift.
                    viewModel.onDragTrackMouse?()
                    if let last = lastMouseLocation {
                        viewModel.updateDrag(velocityX: mouse.x - last.x)
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
            .font(.system(size: 18, weight: .semibold))
            .shadow(color: Color.white.opacity(0.7), radius: 2, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
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
