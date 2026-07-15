//
//  HomeSourcePreference.swift
//  bLoopTV
//

import Foundation
import Combine

enum HomeSource: String {
    case plex
    case stremio
}

/// Nhớ lần cuối người dùng chọn "server" nào (1 server Plex cụ thể hay Stremio) để mở lại app
/// vào đúng nguồn đó, thay vì luôn mặc định vào Plex HomeView. ObservableObject để ContentView đổi
/// root view ngay khi người dùng chuyển nguồn giữa phiên (không cần khởi động lại app).
final class HomeSourcePreference: ObservableObject {
    static let shared = HomeSourcePreference()
    private let key = "selectedHomeSource"

    @Published var current: HomeSource {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: key) }
    }

    private init() {
        current = HomeSource(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .plex
    }
}
