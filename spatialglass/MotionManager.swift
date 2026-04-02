import CoreMotion
import Combine
import SwiftUI

class MotionManager: ObservableObject {
    private let manager = CMMotionManager()

    @Published var smoothX: Double = 0
    @Published var smoothY: Double = 0

    private var rawX: Double = 0
    private var rawY: Double = 0

    init() { start() }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0

        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // gravity gives ambient tilt — feels most natural for parallax
            let targetX = data.gravity.x * 1.8
            let targetY = data.gravity.y * 1.8
            // lerp smoothing — lower = smoother but slower
            self.smoothX += (targetX - self.smoothX) * 0.08
            self.smoothY += (targetY - self.smoothY) * 0.08
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
