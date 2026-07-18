//
//  StremioPlaybackConverter.swift
//  bLoopTV
//

import Foundation

/// Convert dữ liệu Stremio (StremioMeta + StremioStream) sang PlaybackData để dùng chung
/// VideoPlayerView/mpv pipeline sẵn có (giống hệt luồng Plex). Những gì Stremio không cung cấp
/// trước khi phát (audio track thật nhúng trong file, duration...) được placeholder tối thiểu;
/// riêng subtitle rời addon cung cấp thật (field "subtitles" trong response /stream) được convert
/// thành external subtitle track thật, không phải placeholder.
enum StremioPlaybackConverter {
    /// - Parameters:
    ///   - resumeOffsetMs: vị trí xem dở lần trước (ms), lấy từ library account nếu có, mặc định 0 (xem từ đầu).
    ///   - knownDurationMs: tổng thời lượng đã biết trước đó (ms) từ library, mặc định 0 (mpv sẽ tự cập nhật khi phát).
    ///   - libraryItemId: id item trong library account (nil = không lưu tiến độ, dùng cho chế độ nhập URL thủ công không đăng nhập).
    ///   - existing: item library cũ (nếu có) để giữ nguyên field housekeeping khi ghi lại tiến độ mới.
    /// - coverImageUrl: ảnh ngang (background/episode thumbnail ở màn detail) dùng cho lớp che khi load —
    ///   đẹp hơn poster dọc bị kéo giãn. nil thì lùi về poster.
    static func buildPlaybackData(
        item: StremioMeta,
        stream: StremioStream,
        resumeOffsetMs: Int = 0,
        knownDurationMs: Int = 0,
        libraryItemId: String? = nil,
        existing: StremioLibraryItem? = nil,
        coverImageUrl: String? = nil
    ) -> PlaybackData? {
        guard let videoUrlString = stream.url else { return nil }

        var mediaStreams: [PlexMediaPartStream] = [
            // Placeholder: audio nhúng sẵn trong file, không biết trước ff-index nên mpv sẽ tự phát
            // track audio mặc định của file (không cần chọn track này để phát được).
            PlexMediaPartStream(
                id: 1,
                streamType: 2,
                title: "Mặc định",
                displayTitle: "Âm thanh mặc định",
                extendedDisplayTitle: "Âm thanh mặc định",
                codec: "",
                index: 0,
                url: "",
                selected: true,
                languageTag: ""
            )
        ]

        // Chỉ lấy sub tiếng Anh/Việt cho gọn danh sách; nếu addon không có 2 ngôn ngữ này thì vẫn giữ
        // hết những gì có (kể cả ngôn ngữ không xác định) để không mất hẳn lựa chọn phụ đề.
        let allSubtitles = stream.subtitles ?? []
        let viEnSubtitles = allSubtitles.filter {
            let tag = normalizedLanguageTag($0.lang)
            return tag == "vi" || tag == "en"
        }
        let subtitlesToUse = viEnSubtitles.isEmpty ? allSubtitles : viEnSubtitles

        var nextId = 2
        for sub in subtitlesToUse {
            let languageTag = normalizedLanguageTag(sub.lang)
            let displayName = sub.lang?.uppercased() ?? "Phụ đề"
            mediaStreams.append(
                PlexMediaPartStream(
                    id: nextId,
                    streamType: 3,
                    title: displayName,
                    displayTitle: displayName,
                    extendedDisplayTitle: displayName,
                    codec: subtitleCodec(from: sub.url),
                    index: nil,
                    url: sub.url,
                    selected: false,
                    languageTag: languageTag
                )
            )
            nextId += 1
        }

        let context: StremioPlaybackContext? = libraryItemId.map { id in
            StremioPlaybackContext(
                libraryItemId: id,
                videoId: item.id,
                type: item.type,
                name: item.name,
                poster: item.poster,
                existingCtime: existing?.ctime,
                existingTemp: existing?.temp,
                existingRemoved: existing?.removed
            )
        }

        return PlaybackData(
            videoUrl: videoUrlString,
            videoTitle: item.name,
            grandVideoTitle: item.name,
            viewOffset: resumeOffsetMs,
            duration: knownDurationMs,
            videoID: stableVideoId(item.id),
            grandVideoID: 0,
            ratingKey: item.id,
            thumbnailUrl: coverImageUrl ?? item.asPlexMetaData.thumbnail ?? "",
            mediaPartStreams: mediaStreams,
            currentIndex: 0,
            playlist: [],
            ultraBlurColors: PlexUltraBlurColors(topLeft: "000000", topRight: "000000", bottomRight: "000000", bottomLeft: "000000"),
            markers: nil,
            versions: [],
            selectedMediaId: 0,
            stremioContext: context
        )
    }

    /// videoID dùng để lưu lựa chọn audio/subtitle riêng cho từng phim (UserSelectionsService).
    /// Không dùng item.id.hashValue vì Swift random hoá seed mỗi lần chạy app — sẽ mất lựa chọn đã lưu
    /// sau khi tắt/mở lại app. Dùng hash thủ công (djb2) để ổn định qua các lần chạy.
    private static func stableVideoId(_ id: String) -> Int {
        var hash = 5381
        for scalar in id.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }

    private static func subtitleCodec(from urlString: String) -> String {
        let ext = URL(string: urlString)?.pathExtension.lowercased() ?? ""
        return ext.isEmpty ? "srt" : ext
    }

    /// MediaSettingsPanel chỉ hiện phụ đề có languageTag bắt đầu bằng "vi"/"en" — map các mã ISO 639-2
    /// phổ biến addon Stremio hay trả (vie/eng) về đúng dạng đó để hiện lên danh sách.
    private static func normalizedLanguageTag(_ lang: String?) -> String {
        guard let lang = lang?.lowercased() else { return "" }
        let map: [String: String] = ["vie": "vi", "eng": "en"]
        return map[lang] ?? lang
    }
}
