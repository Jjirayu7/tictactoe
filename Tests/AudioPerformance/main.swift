import Foundation

@main
struct AudioPerformanceRunner {
    static func main() {
        let iterations = 1_000
        let enumerationResult = measure(iterations: iterations) {
            _ = AudioDeviceManager.outputDevices()
        }
        let defaultDeviceResult = measure(iterations: iterations) {
            _ = AudioDeviceManager.defaultOutputDeviceID()
        }

        print("PASS: AudioDeviceManager performance benchmark")
        print(String(format: "outputDevices: %.3f ms total, %.3f µs/iteration", enumerationResult.totalMilliseconds, enumerationResult.averageMicroseconds))
        print(String(format: "defaultOutputDeviceID: %.3f ms total, %.3f µs/iteration", defaultDeviceResult.totalMilliseconds, defaultDeviceResult.averageMicroseconds))
    }

    private static func measure(iterations: Int, operation: () -> Void) -> (totalMilliseconds: Double, averageMicroseconds: Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            operation()
        }
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
        let totalMilliseconds = Double(elapsedNanoseconds) / 1_000_000
        return (totalMilliseconds, totalMilliseconds * 1_000 / Double(iterations))
    }
}
