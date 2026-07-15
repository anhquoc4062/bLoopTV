import Foundation
import SwiftUI
import Combine

/// Giữ DUY NHẤT 1 instance MPVMetalViewController (và 1 mpv context) sống suốt vòng đời app.
/// Nhờ vậy khi thoát khỏi VideoPlayerView (pop) rồi vào lại, buffer/cache của mpv còn nguyên → xem tiếp
/// ngay không phải load lại. Vì chỉ có đúng 1 controller (PlayerHost giữ strong reference), SwiftUI dismantle
/// representable KHÔNG deallocate controller, và setupMpv() có guard mpv==nil nên không bao giờ tạo 2 context
/// (tránh leak/tràn memory). Cache bị chặn bởi giới hạn mặc định của mpv (demuxer-max-bytes...).
@MainActor
final class PlayerHost {
    static let shared = PlayerHost()
    let controller = MPVMetalViewController()
    let coordinator = MPVMetalPlayerView.Coordinator()

    private init() {
        controller.playDelegate = coordinator
        coordinator.player = controller
    }
}

struct MPVMetalPlayerView: UIViewControllerRepresentable {
    @ObservedObject var coordinator: Coordinator

    func makeUIViewController(context: Context) -> some UIViewController {
        // Tái sử dụng controller dùng chung thay vì tạo mới → giữ mpv context + buffer sống qua các lần
        // present/dismiss của player view.
        let mpv = PlayerHost.shared.controller
        mpv.playDelegate = coordinator
        mpv.playUrl = coordinator.playUrl

        context.coordinator.player = mpv

        return mpv
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }

    // KHÔNG destroy controller ở đây — PlayerHost giữ nó sống để lần sau vào lại còn buffer sẵn.
    static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator) {
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

