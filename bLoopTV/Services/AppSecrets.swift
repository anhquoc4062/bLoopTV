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
}
