//
//  StremioWatchedService.swift
//  bLoopTV
//
//  Đánh dấu tập/phim Stremio đã xem xong.
//
//  Vì sao lưu local (UserDefaults) mà không đẩy lên account Stremio: state của library Stremio chỉ giữ
//  ĐÚNG 1 bản ghi cho cả series ("video_id" + "timeOffset" của tập xem gần nhất), không có danh sách
//  watched theo từng tập. Nên không có chỗ hợp lệ để ghi trạng thái này lên server bằng model hiện tại.
//

import Foundation
import Combine

final class StremioWatchedService: ObservableObject {
    static let shared = StremioWatchedService()

    /// Xem tới mốc này coi như đã xem xong (bỏ qua credit cuối).
    static let watchedThreshold = 0.95

    private let key = "StremioWatchedVideoIds"

    /// id tập (dạng "tt123:1:2") hoặc id phim lẻ đã xem xong.
    @Published private(set) var watchedIds: Set<String> = []

    private init() {
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            watchedIds = Set(saved)
        }
    }

    func isWatched(_ videoId: String) -> Bool {
        watchedIds.contains(videoId)
    }

    /// Gọi được từ luồng của player (không nhất thiết main) — luôn cập nhật @Published trên main.
    func markWatched(_ videoId: String) {
        guard !videoId.isEmpty else { return }

        DispatchQueue.main.async {
            guard !self.watchedIds.contains(videoId) else { return }
            self.watchedIds.insert(videoId)
            UserDefaults.standard.set(Array(self.watchedIds), forKey: self.key)
        }
    }

    func markUnwatched(_ videoId: String) {
        DispatchQueue.main.async {
            guard self.watchedIds.contains(videoId) else { return }
            self.watchedIds.remove(videoId)
            UserDefaults.standard.set(Array(self.watchedIds), forKey: self.key)
        }
    }

    /// true nếu tiến độ đã qua mốc coi như xem xong. duration <= 0 (chưa biết thời lượng) thì không tính.
    static func reachedWatchedThreshold(timeOffsetMs: Int, durationMs: Int) -> Bool {
        guard durationMs > 0 else { return false }
        return Double(timeOffsetMs) / Double(durationMs) >= watchedThreshold
    }
}
