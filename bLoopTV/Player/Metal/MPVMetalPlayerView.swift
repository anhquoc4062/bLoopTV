import Foundation
import SwiftUI
import Combine

struct MPVMetalPlayerView: UIViewControllerRepresentable {
    @ObservedObject var coordinator: Coordinator

    func makeUIViewController(context: Context) -> some UIViewController {
        // Mỗi lần vào player tạo controller + mpv context RIÊNG (không share). Chia sẻ nguyên UIViewController
        // qua các lần push/pop của NavigationStack gây reparent loạn view Metal → video chồng nhau + lag.
        let mpv = MPVMetalViewController()
        mpv.playDelegate = coordinator
        mpv.playUrl = coordinator.playUrl

        context.coordinator.player = mpv

        return mpv
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }

    // Giải phóng hẳn mpv context khi SwiftUI tháo representable (pop khỏi player). destroy() có guard chống
    // gọi 2 lần nên an toàn dù onDisappear cũng gọi destroyPlayer().
    static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator) {
        (uiViewController as? MPVMetalViewController)?.destroy()
    }

    public func makeCoordinator() -> Coordinator {
        coordinator
    }

    func play(_ url: URL) -> Self {
        coordinator.playUrl = url
        return self
    }

    func onPropertyChange(_ handler: @escaping (MPVMetalViewController, String, Any?) -> Void) -> Self {
        coordinator.onPropertyChange = handler
        return self
    }

    @MainActor
    public final class Coordinator: MPVPlayerDelegate, ObservableObject {
        @Published var showSkipIntro: Bool = false
        @Published var introEndMs: Int = 0

        weak var player: MPVMetalViewController?

        var playUrl : URL?
        var onPropertyChange: ((MPVMetalViewController, String, Any?) -> Void)?

        func play(_ url: URL) {
            player?.loadFile(url)
        }

        /// Tạm dừng thay vì destroy — giữ mpv + buffer sống để lần sau vào lại xem tiếp ngay.
        func pausePlayer() {
            player?.pause()
        }

        /// Chỉ dùng khi thực sự muốn giải phóng hẳn mpv context (hiện không gọi trong luồng thường).
        func destroyPlayer() {
            player?.destroy()
        }

        func propertyChange(mpv: OpaquePointer, propertyName: String, data: Any?) {
            guard let player else { return }

            self.onPropertyChange?(player, propertyName, data)
        }
    }
}

