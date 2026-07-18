//
//  NavigatyionDestination.swift
//  VuaPhimBui
//
//  Created by Monster on 28/6/25.
//

enum NavigationDestination: Hashable {
    case movieDetail(metadata: PlexMetaData, isDiscover: Bool)
    case collection(sectionTitle: String, hubKey: String, isDiscover: Bool, hasFilteredHeader: Bool = false)
    case actorDetail(actor: PlexActor)
    case searchPage
    case discoverPage(title: String, hubKey: String, showBackButton: Bool)
    case watchTogetherRoom(room: PlexWatchTogetherRoom)
    case filterMovie(filterQuery: String)
    case notifications
    case notificationDetail(notification: NotificationItem)
    case videoPlayer(playbackData: PlaybackData)
    case stremioHome
    case stremioLogin
    case stremioAccountHome
    case stremioMovieDetail(item: StremioMeta, addons: [StremioInstalledAddon])
    case stremioSearch(addons: [StremioInstalledAddon])
}
