//
//  StremioAccountHomeView.swift
//  bLoopTV
//

import SwiftUI

private struct StremioAccountCatalogRow: Identifiable {
    let id: String
    let title: String
    let items: [StremioMeta]
    /// Chuyển sẵn sang PlexMetaData lúc dựng hàng (không convert lại mỗi lần render) để dùng chung
    /// SectionView/MovieCardView với bên Plex.
    let metadatas: [PlexMetaData]

    init(id: String, title: String, items: [StremioMeta]) {
        self.id = id
        self.title = title
        self.items = items
        self.metadatas = items.map { $0.asPlexMetaData }
    }

    /// Tìm ngược item Stremio gốc từ thẻ được bấm (PlexMetaData.id giữ nguyên id Stremio).
    func item(forMetadataId id: String) -> StremioMeta? {
        items.first { $0.id == id }
    }
}

struct StremioAccountHomeView: View {
    private static let continueWatchingRowId = "continueWatching"

    @EnvironmentObject var navPathManager: NavigationPathManager

    @State private var rows: [StremioAccountCatalogRow] = []
    @State private var addons: [StremioInstalledAddon] = []
    @State private var isLoadingCatalogs = false
    @State private var errorMessage: String?

    var body: some View {
        content
            .onAppear {
                if rows.isEmpty && !isLoadingCatalogs {
                    loadHome()
                } else {
                    // Quay lại từ detail: nội dung home giữ nguyên, chỉ làm mới "Xem Tiếp" cho khớp tiến độ.
                    refreshContinueWatching()
                }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                topBar

                if rows.isEmpty && isLoadingCatalogs {
                    LogoLoadingView()
                        .padding(.top, 80)
                }

                if let errorMessage, rows.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                ForEach(rows) { row in
                    SectionView(
                        sectionTitle: row.title,
                        hubKey: row.id,
                        metadatas: row.metadatas,
                        isLandscapeSection: false,
                        isDiscover: false,
                        onSelectItem: { metadata in
                            guard let item = row.item(forMetadataId: metadata.id) else { return }
                            navPathManager.push(.stremioMovieDetail(item: item, addons: addons))
                        },
                        subtitleProvider: { metadata in
                            row.item(forMetadataId: metadata.id)?.cardSubtitle
                        }
                    )
                    .focusSection()
                }
            }
        }
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.top)
    }

    // MARK: - Top bar riêng của "Home" Stremio, avatar = tài khoản Stremio đang đăng nhập
    private var topBar: some View {
        HomeTopBar {
            ServerSwitcherMenu()

            Button {
                navPathManager.push(.stremioSearch(addons: addons))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Tìm kiếm")
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
            }
            .buttonStyle(.card)
        } trailing: {
            Menu {
                Button("Đăng xuất") {
                    StremioAccountAPI.shared.logout()
                    HomeSourcePreference.shared.current = .plex
                    navPathManager.reset()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                    if let email = StremioAccountAPI.shared.accountEmail {
                        Text(email)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .menuStyle(.button)
            .buttonStyle(.card)
        }
    }

    private func loadHome() {
        guard let authKey = StremioAccountAPI.shared.authKey else {
            errorMessage = "Chưa đăng nhập"
            return
        }

        // Continue Watching load riêng, bất đồng bộ, không chờ/chặn các mục Watchly bên dưới.
        refreshContinueWatching()

        isLoadingCatalogs = true
        errorMessage = nil

        Task {
            do {
                print("[Stremio] Đang lấy danh sách addon từ account")
                let addons = try await StremioAccountAPI.shared.fetchAddonCollection(authKey: authKey)
                print("[Stremio] Có \(addons.count) addon trong account")

                await MainActor.run {
                    self.addons = addons
                }

                // Home chỉ lấy các mục của addon Watchly (không loop hết catalog mọi addon như trước).
                guard let watchly = addons.watchly else {
                    await MainActor.run {
                        isLoadingCatalogs = false
                        if rows.isEmpty { errorMessage = "Chưa cài addon Watchly trong tài khoản Stremio" }
                    }
                    return
                }

                let base = watchly.baseURL
                // Mỗi catalog Watchly = 1 mục, giữ đúng thứ tự khai báo. Bỏ catalog cần tham số bắt buộc.
                let catalogs = watchly.manifest.catalogs.filter { !$0.hasRequiredExtra }

                let fetched: [StremioAccountCatalogRow] = await withTaskGroup(of: (Int, StremioAccountCatalogRow?).self) { group in
                    for (index, catalog) in catalogs.enumerated() {
                        group.addTask {
                            guard let metas = try? await StremioAPI.shared.fetchCatalog(baseURL: base, type: catalog.type, id: catalog.id),
                                  !metas.isEmpty else { return (index, nil) }
                            let title = catalog.name ?? catalog.id.capitalized
                            return (index, StremioAccountCatalogRow(id: "\(base)-\(catalog.type)-\(catalog.id)", title: title, items: metas))
                        }
                    }
                    var out: [(Int, StremioAccountCatalogRow)] = []
                    for await (index, row) in group {
                        if let row { out.append((index, row)) }
                    }
                    return out.sorted { $0.0 < $1.0 }.map { $0.1 }
                }

                await MainActor.run {
                    rows.append(contentsOf: fetched)
                    isLoadingCatalogs = false
                    if rows.isEmpty {
                        errorMessage = "Addon Watchly không trả về mục nào"
                    }
                }
            } catch {
                print("[Stremio] Lỗi lấy addon collection: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingCatalogs = false
                }
            }
        }
    }

    /// Làm mới riêng mục "Xem Tiếp" — gọi lúc vào home lần đầu và mỗi lần quay lại từ detail (tiến độ đã đổi).
    private func refreshContinueWatching() {
        guard let authKey = StremioAccountAPI.shared.authKey else { return }
        Task {
            let row = await fetchContinueWatchingRow(authKey: authKey)
            await MainActor.run {
                rows.removeAll { $0.id == Self.continueWatchingRowId }
                if let row { rows.insert(row, at: 0) }
            }
        }
    }

    private func fetchContinueWatchingRow(authKey: String) async -> StremioAccountCatalogRow? {
        do {
            let items = try await StremioAccountAPI.shared.fetchLibraryItems(authKey: authKey)
            print("[Stremio] Library có \(items.count) item")

            // Lưu ý: field "removed" không có nghĩa "đã dừng xem" trong dữ liệu Stremio thực tế
            // (đa số item đang xem dở vẫn có removed=true), nên không dùng nó để lọc.
            let inProgress = items
                .filter { ($0.state?.timeOffset ?? 0) > 0 }
                .sorted { ($0.state?.lastWatched ?? "") > ($1.state?.lastWatched ?? "") }

            print("[Stremio] Continue Watching: \(inProgress.count) item")
            guard !inProgress.isEmpty else { return nil }

            let metas = inProgress.map { libItem -> StremioMeta in
                // Luôn dùng "_id" (id cả series/phim), KHÔNG dùng video_id — vì id kèm season/episode
                // sẽ khiến trang detail gọi /meta sai (chỉ nhận id series trần) và bấm vô chỉ vào đúng
                // 1 tập chứ không phải cả series. StremioMovieDetailView đã tự tra video_id trong library
                // để resume đúng tập, không cần truyền qua đây.
                StremioMeta(id: libItem.id, type: libItem.type, name: libItem.name, poster: libItem.poster)
            }

            syncContinueWatchingToTopShelf(metas)

            return StremioAccountCatalogRow(id: Self.continueWatchingRowId, title: "Xem Tiếp", items: metas)
        } catch {
            print("[Stremio] Lỗi lấy Continue Watching: \(error)")
            return nil
        }
    }

    /// Đưa Continue Watching của Stremio ra Top Shelf ngoài Home Screen — chỉ khi Stremio đang là nguồn
    /// đang dùng (tránh đè lên Top Shelf khi người dùng đang ở Plex).
    private func syncContinueWatchingToTopShelf(_ metas: [StremioMeta]) {
        guard HomeSourcePreference.shared.current == .stremio else { return }

        let items: [SharedContinueWatchingItem] = metas.prefix(10).map { meta in
            var deepLink = URLComponents(string: "blooptv://continueWatching")!
            deepLink.queryItems = [
                URLQueryItem(name: "source", value: "stremio"),
                URLQueryItem(name: "id", value: meta.id),
                URLQueryItem(name: "title", value: meta.name),
                URLQueryItem(name: "poster", value: meta.poster ?? ""),
                URLQueryItem(name: "type", value: meta.type)
            ]

            return SharedContinueWatchingItem(
                id: "stremio-\(meta.id)",
                title: meta.name,
                subtitle: nil,
                posterURLString: meta.poster,
                deepLinkURLString: deepLink.url?.absoluteString ?? ""
            )
        }

        ContinueWatchingSync.write(items)
    }
}
