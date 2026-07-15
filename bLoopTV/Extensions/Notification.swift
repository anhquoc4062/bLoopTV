//
//  Notification.swift
//  VuaPhimBui
//
//  Created by Monster on 7/6/25.
//
import Foundation

extension Notification.Name {
    static let playerDidDismiss = Notification.Name("playerDidDismiss")
    static let didReachBottom = Notification.Name("didReachBottom")
    static let scrollToTop = Notification.Name("scrollToTop")
    static let goToSearch = Notification.Name("goToSearch")
    static let didRemoveFromContinueWatching = Notification.Name("didRemoveFromContinueWatching")
    static let filterMoviesShouldReload = Notification.Name("filterMoviesShouldReload")
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
    static let didTapNotification = Notification.Name("didTapNotification")
}
