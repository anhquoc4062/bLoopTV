//
//  PlaybackData.swift
//  VuaPhimBui
//
//  Created by Monster on 11/6/25.
//

struct PlaybackData: Hashable, Equatable {
    let videoUrl: String
    let videoTitle: String
    let grandVideoTitle: String
    let viewOffset: Int
    let duration: Int
    let videoID: Int
    let grandVideoID: Int
    let ratingKey: String
    let thumbnailUrl: String
    /// Logo (clearLogo) của phim để hiện lúc loading trong player thay cho spinner. nil = không có logo,
    /// player tự lùi về spinner cam.
    var logoUrl: String? = nil
    let mediaPartStreams: [PlexMediaPartStream]
    let currentIndex: Int
    let playlist: [QueueItem]
    let ultraBlurColors: PlexUltraBlurColors
    let markers: [PlexMarker]?
    let versions: [PlexMedia]
    let selectedMediaId: Int
    /// Có giá trị khi nội dung đến từ Stremio — dùng để lưu tiến độ xem (Continue Watching) lên account
    /// Stremio thay vì gọi PlexAPI.sendTimelineUpdate. nil = nội dung Plex, giữ nguyên hành vi cũ.
    var stremioContext: StremioPlaybackContext? = nil

    static func == (lhs: PlaybackData, rhs: PlaybackData) -> Bool {
        lhs.videoUrl == rhs.videoUrl &&
        lhs.videoTitle == rhs.videoTitle &&
        lhs.ratingKey == rhs.ratingKey &&
        lhs.selectedMediaId == rhs.selectedMediaId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(videoUrl)
        hasher.combine(videoTitle)
        hasher.combine(ratingKey)
        hasher.combine(selectedMediaId)
    }
}

struct QueueItem {
    let title: String
    let grandTitle: String
    let queueIndex: Int
    let thumbnailUrl: String
    let ratingKey: String
    let duration: Int
}
