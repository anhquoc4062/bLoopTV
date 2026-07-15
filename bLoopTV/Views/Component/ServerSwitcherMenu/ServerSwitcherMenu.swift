//
//  ServerSwitcherMenu.swift
//  bLoopTV
//

import SwiftUI

/// Menu chọn nguồn dùng chung cho HomeView (Plex) và StremioAccountHomeView — ưu tiên Stremio lên đầu,
/// bên dưới là danh sách server Plex. Chọn nguồn khác sẽ đổi hẳn root view (không chỉ push chồng lên),
/// nên hoạt động đúng dù đang đứng ở màn nào.
struct ServerSwitcherMenu: View {
    @EnvironmentObject var navPathManager: NavigationPathManager
    @ObservedObject var plexAPI = PlexAPI.shared
    @ObservedObject var sourcePreference = HomeSourcePreference.shared

    /// Gọi khi chọn 1 server Plex trong lúc ĐANG đứng ở HomeView (Plex) rồi — vì lúc đó root view không
    /// đổi (không tự onAppear lại) nên cần tự refresh data thủ công. StremioAccountHomeView không cần
    /// truyền cái này vì chọn Plex từ đó luôn đổi root view, HomeView mới sẽ tự refresh qua onAppear.
    var onPlexServerReselected: (() -> Void)?

    var body: some View {
        Menu {
            Button {
                selectStremio()
            } label: {
                HStack {
                    Text("Stremio")
                    if sourcePreference.current == .stremio {
                        Image(systemName: "checkmark")
                    }
                }
            }

            let names = plexAPI.plexServerNames
            ForEach(0..<names.count, id: \.self) { index in
                Button {
                    selectPlexServer(index: index)
                } label: {
                    HStack {
                        Text(names[index])
                        if sourcePreference.current == .plex && plexAPI.activeServerIndex == index {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                Text(currentLabel)
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
        }
        .menuStyle(.button)
        .buttonStyle(.card)
    }

    private var currentLabel: String {
        if sourcePreference.current == .stremio {
            return "Stremio"
        }
        return plexAPI.plexServerNames.indices.contains(plexAPI.activeServerIndex)
            ? plexAPI.plexServerNames[plexAPI.activeServerIndex]
            : "Chọn Server"
    }

    private func selectStremio() {
        guard sourcePreference.current != .stremio else { return }
        sourcePreference.current = .stremio
        if StremioAccountAPI.shared.authKey != nil {
            navPathManager.reset()
        } else {
            navPathManager.push(.stremioLogin)
        }
    }

    private func selectPlexServer(index: Int) {
        let wasAlreadyOnPlex = sourcePreference.current == .plex
        plexAPI.activeServerIndex = index
        sourcePreference.current = .plex

        if wasAlreadyOnPlex {
            onPlexServerReselected?()
        } else {
            navPathManager.reset()
        }
    }
}
