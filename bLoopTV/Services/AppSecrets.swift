//
//  AppSecrets.swift
//  bLoopTV
//
//  Đọc key/token bí mật từ Secrets.plist (đã gitignore) trong bundle. Không có file/không có giá trị thì
//  trả về rỗng — nơi dùng tự bỏ qua tính năng tương ứng, app vẫn chạy bình thường.
//

import Foundation

enum AppSecrets {
    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return [:]
        }
        return plist
    }()

    private static func string(_ key: String) -> String {
        (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// TMDB API key (v3). Rỗng nếu chưa cấu hình.
    static var tmdbAPIKey: String { string("TMDBAPIKey") }

    /// Host API TMDB. Để trống = dùng thẳng TMDB. Điền URL proxy (vd Cloudflare Worker) khi ISP chặn
    /// api.themoviedb.org. KHÔNG kèm dấu "/" cuối. Vd: "https://tmdb-proxy.example.workers.dev/3".
    static var tmdbAPIHost: String {
        let v = string("TMDBAPIHost")
        return v.isEmpty ? "https://api.themoviedb.org/3" : v
    }

    /// Base ảnh TMDB (poster/profile). Để trống = dùng image.tmdb.org. Điền proxy nếu ISP chặn luôn ảnh.
    /// KHÔNG kèm dấu "/" cuối. Vd: "https://img-proxy.example.workers.dev/t/p".
    static var tmdbImageHost: String {
        let v = string("TMDBImageHost")
        return v.isEmpty ? "https://image.tmdb.org/t/p" : v
    }
}
