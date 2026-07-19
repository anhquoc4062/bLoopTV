//
//  StremioMetaAdapter.swift
//  bLoopTV
//
//  Cầu nối để item Stremio dùng chung được MovieCardView/SectionView (vốn nhận PlexMetaData). Nhờ vậy
//  Home/Search của Stremio hiển thị y hệt bên Plex mà không phải nuôi 2 bộ component song song.
//

import Foundation

extension StremioMeta {
    /// Poster giữ nguyên URL tuyệt đối của addon — MovieCardView tự nhận biết http(s) và dùng thẳng,
    /// không đi qua transcode của Plex (Plex không giữ ảnh này).
    ///
    /// Chuyển 1 lần lúc dựng danh sách, đừng gọi trong body của view: placeholder dựng qua JSON decode
    /// nên gọi lại mỗi lần render sẽ tốn vô ích.
    var asPlexMetaData: PlexMetaData {
        PlexMetaData.placeholder(id: id, title: name, poster: poster, background: background, type: type)
    }

    /// Dòng phụ dưới tên thẻ. StremioMeta không có năm/số mùa/số tập như Plex nên chỉ hiện loại nội dung.
    var cardSubtitle: String {
        switch type {
        case "movie": return "Phim lẻ"
        case "series": return "Phim bộ"
        default: return type.capitalized
        }
    }
}
