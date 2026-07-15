//
//  SharedContinueWatching.swift
//  bloopTVTopShelf
//
//  Bản sao y hệt file trong target bLoopTV — đọc/ghi dữ liệu Continue Watching qua App Group.
//

import Foundation

struct SharedContinueWatchingItem: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let posterURLString: String?
    /// Deep link mở lại đúng chỗ trong app, dạng "blooptv://continueWatching?source=plex&id=..."
    let deepLinkURLString: String
}

enum ContinueWatchingSync {
    static let appGroupId = "group.com.vuaphimbui.blooptv.shared2026"
    private static let storageKey = "sharedContinueWatchingItems"

    static func write(_ items: [SharedContinueWatchingItem]) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func read() -> [SharedContinueWatchingItem] {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([SharedContinueWatchingItem].self, from: data) else {
            return []
        }
        return items
    }
}
