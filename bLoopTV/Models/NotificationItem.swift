//
//  NotificationItem.swift
//  VuaPhimBui
//
//  Created by Monster on 12/9/25.
//
import Foundation

struct NotificationItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let type: String
    let movieId: String?
    let imageUrl: String?
    let createdAt: Date?
    var isRead: Bool
}
