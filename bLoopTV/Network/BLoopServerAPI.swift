//
//  BLoopServerAPI.swift
//  bLoopTV
//
//  Client cho bLoopServer — server riêng stream + cache file Google Drive. Addon Drive nằm ở tài khoản
//  Stremio CHỦ nên KHÔNG gọi thẳng addon, mọi thứ đi qua server này.
//
//  Xác thực bằng authKey Stremio của chính người dùng:
//    - Gọi API  -> header "X-Stremio-Auth"
//    - URL phát -> query "?a=" (player không set được header)
//  Tuyệt đối không log/hiển thị authKey ở bất cứ đâu.
//

import Foundation

enum BLoopServerError: Error, Equatable {
    /// 400 — sid sai định dạng.
    case badRequest
    /// 401 — thiếu/sai authKey.
    case unauthorized
    /// 403 — tài khoản chưa được cấp quyền.
    case forbidden
    /// 410 — addon không còn file đó nữa.
    case gone
    /// 502 — không lấy được nội dung từ nguồn.
    case upstream
    /// 503 — chưa xác minh được tài khoản lúc này.
    case unavailable
    case notLoggedIn
    case invalidURL
    case http(Int)
    case transport
    case decoding

    init?(statusCode: Int) {
        switch statusCode {
        case 200...299: return nil
        case 400: self = .badRequest
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 410: self = .gone
        case 502: self = .upstream
        case 503: self = .unavailable
        default: self = .http(statusCode)
        }
    }

    /// sid không còn dùng được → phải gọi lại /streams cho người dùng chọn lại.
    var needsStreamRefresh: Bool {
        self == .gone || self == .badRequest
    }

    /// Lỗi vĩnh viễn, thử lại vô ích.
    var isPermanent: Bool {
        self == .forbidden
    }

    var userMessage: String {
        switch self {
        case .badRequest, .gone:
            return "Nguồn phát không còn khả dụng, đang tải lại danh sách..."
        case .unauthorized, .notLoggedIn:
            return "Phiên Stremio đã hết hạn, vui lòng đăng nhập lại."
        case .forbidden:
            return "Tài khoản chưa được cấp quyền dùng bLoopServer."
        case .upstream:
            return "Không lấy được nội dung từ nguồn, thử lại giúp mình."
        case .unavailable:
            return "Chưa xác minh được tài khoản lúc này, thử lại sau chút."
        case .invalidURL:
            return "Địa chỉ bLoopServer không hợp lệ."
        case .http(let code):
            return "bLoopServer lỗi (\(code))."
        case .transport:
            return "Không kết nối được bLoopServer."
        case .decoding:
            return "Dữ liệu từ bLoopServer không đọc được."
        }
    }
}

final class BLoopServerAPI {
    static let shared = BLoopServerAPI()
    private init() {}

    /// Cho phép đổi lúc chạy (vd màn cài đặt sau này) mà không cần build lại.
    static let baseURLDefaultsKey = "BLoopServerBaseURL"
    private static let fallbackBaseURL = "http://127.0.0.1:7788"

    /// Thứ tự ưu tiên: UserDefaults (đổi lúc chạy) -> Secrets.plist -> mặc định 127.0.0.1:7788.
    var baseURL: String {
        if let saved = UserDefaults.standard.string(forKey: Self.baseURLDefaultsKey), !saved.isEmpty {
            return Self.normalized(saved)
        }
        if let fromPlist = Self.plistValue(Self.baseURLDefaultsKey), !fromPlist.isEmpty {
            return Self.normalized(fromPlist)
        }
        return Self.fallbackBaseURL
    }

    func setBaseURL(_ value: String) {
        UserDefaults.standard.set(Self.normalized(value), forKey: Self.baseURLDefaultsKey)
    }

    private static func normalized(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private static func plistValue(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return (plist[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - API

    /// Liệt kê stream cho 1 phim/tập. `id` đúng định dạng Stremio ("tt123" hoặc "tt123:1:5").
    func fetchStreams(type: String, id: String, authKey: String) async throws -> BLoopStreamsResponse {
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(baseURL)/streams/\(type)/\(encodedId)") else {
            throw BLoopServerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Gọi API thì dùng header, không nhét authKey vào URL.
        request.setValue(authKey, forHTTPHeaderField: "X-Stremio-Auth")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BLoopServerError.transport
        }

        if let http = response as? HTTPURLResponse, let error = BLoopServerError(statusCode: http.statusCode) {
            print("[bLoop] /streams/\(type)/\(id) lỗi HTTP \(http.statusCode)")
            throw error
        }

        do {
            return try JSONDecoder().decode(BLoopStreamsResponse.self, from: data)
        } catch {
            throw BLoopServerError.decoding
        }
    }

    /// URL phát cho player. Player không set được header nên authKey đi qua query "?a=".
    /// LUÔN dựng từ `sid` lấy ở /streams — không tự ghép từ type/id, không dùng chỉ số mảng.
    func playURL(sid: String, authKey: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/f/\(sid)")
        components?.queryItems = [URLQueryItem(name: "a", value: authKey)]
        return components?.url
    }

    /// Kiểm tra nhanh sid còn dùng được không (HEAD) trước khi đưa cho player — bắt sớm 410/401/403 để
    /// báo tử tế, thay vì để player chết với lỗi khó hiểu. Dùng header nên authKey không lọt vào URL.
    func preflight(sid: String, authKey: String) async throws {
        guard let url = URL(string: "\(baseURL)/f/\(sid)") else { throw BLoopServerError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(authKey, forHTTPHeaderField: "X-Stremio-Auth")
        request.timeoutInterval = 8

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BLoopServerError.transport
        }

        if let http = response as? HTTPURLResponse, let error = BLoopServerError(statusCode: http.statusCode) {
            print("[bLoop] preflight lỗi HTTP \(http.statusCode)")
            throw error
        }
    }
}
