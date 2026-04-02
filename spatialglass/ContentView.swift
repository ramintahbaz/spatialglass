import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var motion = MotionManager()

    let maxShift: CGFloat = 28

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            NotesPanel()
                .padding(.horizontal, 12)
        }
    }

    func offset(depth: Double) -> CGPoint {
        CGPoint(
            x: CGFloat(motion.smoothX) * maxShift * depth,
            y: CGFloat(-motion.smoothY) * maxShift * depth
        )
    }
}
