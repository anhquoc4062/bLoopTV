//
//  PlexMetaData+Placeholder.swift
//  bLoopTV
//

import Foundation

extension PlexMetaData {
    /// Dựng tạm 1 PlexMetaData chỉ với id/title/poster/type — dùng cho deep link (vd Top Shelf) trước khi
    /// có dữ liệu thật. MovieDetailView tự fetch đầy đủ chi tiết bằng "id" ngay khi xuất hiện, nên các
    /// field còn lại chỉ cần placeholder hợp lệ, không ảnh hưởng UI (title/poster hiện đúng ngay, phần còn
    /// lại tự lấp đầy sau khi fetch xong).
    ///
    /// Dựng qua JSON decode (không dùng init thường) vì init thường ép parentId/grandParentId thành chuỗi
    /// rỗng thay vì nil — MovieDetailView fetch bằng "metadata.grandParentId ?? metadata.parentId ?? metadata.id",
    /// chuỗi rỗng không phải nil nên toán tử ?? dừng lại luôn ở đó, fetch nhầm id rỗng thay vì id thật.
    static func placeholder(
        id: String,
        title: String,
        poster: String?,
        background: String?,
        type: String,
        guid: String? = nil,
        art: String? = nil,
        viewOffset: Int? = nil,
        duration: Int? = nil
    ) -> PlexMetaData {
        var json: [String: Any] = [
            "ratingKey": id,
            "title": title,
            "type": type,
            "thumb": poster ?? "",
            "summary": ""
        ]
        if let guid, !guid.isEmpty { json["guid"] = guid }
        // thumbnail (landscape) decode từ key "art". Ưu tiên art (deep link Plex), thiếu thì dùng
        // background (poster ngang của Stremio) — để thẻ landscape có ảnh ngang thay vì poster dọc.
        if let landscapeArt = [art, background].compactMap({ $0 }).first(where: { !$0.isEmpty }) {
            json["art"] = landscapeArt
        }
        // Cho thẻ Continue Watching hiện thanh progress (viewProgress = viewOffset / duration).
        if let viewOffset { json["viewOffset"] = viewOffset }
        if let duration { json["duration"] = duration }

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let metadata = try? JSONDecoder().decode(PlexMetaData.self, from: data) else {
            // Không thể xảy ra với JSON hợp lệ ở trên, nhưng vẫn cần 1 giá trị trả về.
            return PlexMetaData(
                id: id, ratingKey: id, uuid: UUID(), parentId: "", grandParentId: "",
                title: title, grandParentTitle: "", type: type, poster: poster ?? "", thumbnail: background ?? "",
                year: nil, seasonIndex: nil, episodeIndex: nil, addedAt: 0, updatedAt: 0,
                ultraBlurColors: PlexUltraBlurColors(topLeft: "000000", topRight: "000000", bottomRight: "000000", bottomLeft: "000000"),
                genres: [], contentRating: "", duration: 0, librarySectionTitle: "", images: [], guid: "",
                audienceRating: 0, childCount: 0, leafCount: 0, summary: "",
                imageSources: ImageSources(coverPoster: nil, coverArt: nil, thumbnail: nil, art: nil),
                tagline: "", viewOffset: 0, lastViewedAt: 0)
        }
        return metadata
    }
}
