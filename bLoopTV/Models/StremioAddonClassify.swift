//
//  StremioAddonClassify.swift
//  bLoopTV
//
//  Nhận diện addon theo tên/id manifest để chọn nguồn: Home dùng Watchly, detail ưu tiên TMDB (Cinemeta
//  làm placeholder). Khớp không phân biệt hoa thường, chấp nhận nhiều biến thể tên.
//

import Foundation

extension StremioInstalledAddon {
    var baseURL: String {
        StremioAccountAPI.baseURL(fromTransportUrl: transportUrl)
    }

    private var haystack: String {
        (manifest.name + " " + manifest.id).lowercased()
    }

    var isWatchly: Bool { haystack.contains("watchly") }

    var isTMDB: Bool {
        haystack.contains("tmdb") || haystack.contains("themoviedb") || haystack.contains("movie database")
    }

    var isCinemeta: Bool { haystack.contains("cinemeta") }
}

extension Array where Element == StremioInstalledAddon {
    var baseURLs: [String] { map { $0.baseURL } }
    var watchly: StremioInstalledAddon? { first { $0.isWatchly } }
    var tmdb: StremioInstalledAddon? { first { $0.isTMDB } }
    var cinemeta: StremioInstalledAddon? { first { $0.isCinemeta } }

    /// Base URL xếp theo thứ tự ưu tiên lấy /meta: TMDB trước (tiếng Việt), Cinemeta sau, rồi tới addon
    /// còn lại. Dùng khi tra ảnh nền cho Continue Watching (lấy addon đầu tiên có background).
    var metaOrderedBaseURLs: [String] {
        var ordered: [StremioInstalledAddon] = []
        if let t = tmdb { ordered.append(t) }
        if let c = cinemeta { ordered.append(c) }
        for a in self where !ordered.contains(where: { $0.transportUrl == a.transportUrl }) {
            ordered.append(a)
        }
        return ordered.map { $0.baseURL }
    }
}

extension StremioCatalogDescriptor {
    /// Catalog cần tham số bắt buộc (genre/skip/search...) mà Home không cung cấp → bỏ qua, tránh row rỗng/lỗi.
    var hasRequiredExtra: Bool {
        extra?.contains { $0.isRequired == true } == true
    }
}
