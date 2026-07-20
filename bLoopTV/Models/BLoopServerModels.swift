//
//  BLoopServerModels.swift
//  bLoopTV
//
//  Model cho bLoopServer — server riêng stream + cache file Google Drive. Addon Drive nằm ở tài khoản
//  Stremio CHỦ, không phải tài khoản người dùng, nên nội dung này chỉ lấy được qua bLoopServer.
//

import Foundation

struct BLoopStream: Decodable, Identifiable {
    /// Định danh ổn định của đúng file đó (không phải vị trí trong mảng) — luôn phát bằng sid này.
    let sid: String
    let play: String?
    let addonId: String?
    let addonName: String?
    let name: String?
    let description: String?
    let filename: String?
    /// Số byte chính xác — dùng để hiện dung lượng, KHÔNG parse từ description.
    let size: Int64?
    /// Addon liệt kê cả file phụ đề lẫn trong danh sách stream — không được tự phát mấy cái này.
    let isSubtitle: Bool?
    let fileKey: String?
    /// Tỉ lệ đã cache sẵn trên đĩa server (0..1), nil = không rõ.
    let cached: Double?

    var id: String { sid }

    var isSubtitleStream: Bool { isSubtitle == true }

    /// Dung lượng dạng đọc được, lấy từ `size` (byte chính xác).
    var readableSize: String? {
        guard let size, size > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: size)
    }

    /// Nhãn hiện trong danh sách chọn nguồn: tên + dung lượng + mức cache (để biết cái nào mở là chạy ngay).
    var displayLabel: String {
        var parts: [String] = []
        parts.append(name ?? filename ?? addonName ?? "Nguồn bLoop")
        if let readableSize { parts.append(readableSize) }
        if let cached, cached > 0 {
            parts.append(cached >= 0.999 ? "⚡ sẵn sàng" : "⚡ \(Int(cached * 100))%")
        }
        return parts.joined(separator: " • ")
    }
}

struct BLoopStreamsResponse: Decodable {
    let type: String?
    let id: String?
    let streams: [BLoopStream]
    /// Addon nào lỗi thì báo ở đây; các addon còn lại vẫn trả stream bình thường — KHÔNG coi là lỗi toàn cục.
    let errors: [String]?
}
