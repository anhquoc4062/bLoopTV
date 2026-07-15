//
//  StremioAccountHomeView.swift
//  bLoopTV
//

import SwiftUI

private struct StremioAccountCatalogRow: Identifiable {
    let id: String
    let title: String
    let items: [StremioMeta]
}

struct StremioAccountHomeView: View {
    private static let continueWatchingRowId = "continueWatching"

    @EnvironmentObject var navPathManager: NavigationPathManager

    @State private var rows: [StremioAccountCatalogRow] = []
    @State private var addons: [StremioInstalledAddon] = []
    @State private var allAddonBaseURLs: [String] = []
    @State private var isLoadingCatalogs = false
    @State private var errorMessage: String?

    var body: some View {
        content
            .onAppear {
                if rows.isEmpty && !isLoadingCatalogs { loadHome() }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                topBar

                if rows.isEmpty && isLoadingCatalogs {
                    ProgressView()
                        .padding(.top, 40)
                }

                if let errorMessage, rows.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                ForEach(rows) { row in
                    StremioSectionView(sectionTitle: row.title, items: row.items) { item in
                        navPathManager.push(.stremioMovieDetail(item: item, addonBaseURLs: allAddonBaseURLs))
                    }
                    .focusSection()
                }
            }
        }
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.top)
    }

    // MARK: - Top bar riêng của "Home" Stremio, avatar = tài khoản Stremio đang đăng nhập
    private var topBar: some View {
        HStack(spacing: 30) {
            ServerSwitcherMenu()

            Button {
                navPathManager.push(.stremioSearch(addons: addons))
            } label: {
                Image(systemName: "magnifyingglass")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.card)

            Spacer()

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
        .padding(.top, 60)
        .padding(.bottom, 10)
    }

    private func loadHome() {
        guard let authKey = StremioAccountAPI.shared.authKey else {
            errorMessage = "Chưa đăng nhập"
            return
        }

        // Continue Watching load riêng, bất đồng bộ, không chờ/chặn 2 mục Featured bên dưới.
        Task {
            if let row = await fetchContinueWatchingRow(authKey: authKey) {
                await MainActor.run {
                    rows.removeAll { $0.id == Self.continueWatchingRowId }
                    rows.insert(row, at: 0)
                }
            }
        }

        // Chỉ load 4 mục cho nhẹ (Movies/Series x Popular/Featured), không loop hết catalog mọi addon.
        isLoadingCatalogs = true
        errorMessage = nil

        Task {
            do {
                print("[Stremio] Đang lấy danh sách addon từ account")
                let addons = try await StremioAccountAPI.shared.fetchAddonCollection(authKey: authKey)
                print("[Stremio] Có \(addons.count) addon trong account")

                let addonBaseURLs = addons.map { StremioAccountAPI.baseURL(fromTransportUrl: $0.transportUrl) }

                async let moviePopular = fetchCatalogRow(addons: addons, addonBaseURLs: addonBaseURLs, type: "movie", keyword: "popular", fallbackId: "top", title: "Phim lẻ - Phổ biến")
                async let movieFeatured = fetchCatalogRow(addons: addons, addonBaseURLs: addonBaseURLs, type: "movie", keyword: "featured", fallbackId: nil, title: "Phim lẻ - Nổi bật")
                async let seriesPopular = fetchCatalogRow(addons: addons, addonBaseURLs: addonBaseURLs, type: "series", keyword: "popular", fallbackId: "top", title: "Phim bộ - Phổ biến")
                async let seriesFeatured = fetchCatalogRow(addons: addons, addonBaseURLs: addonBaseURLs, type: "series", keyword: "featured", fallbackId: nil, title: "Phim bộ - Nổi bật")
                let featuredRows = await [moviePopular, movieFeatured, seriesPopular, seriesFeatured].compactMap { $0 }

                await MainActor.run {
                    self.addons = addons
                    allAddonBaseURLs = addonBaseURLs
                    rows.append(contentsOf: featuredRows)
                    isLoadingCatalogs = false
                    if rows.isEmpty {
                        errorMessage = "Không tìm thấy catalog nào trong các addon của account"
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

    /// Tìm addon đầu tiên (theo thứ tự trong account) có catalog khớp keyword (vd "popular"/"featured")
    /// đúng loại (movie/series) và trả dữ liệu. `fallbackId` dùng cho trường hợp addon không đặt tên
    /// rõ ràng nhưng dùng id quy ước (Cinemeta dùng id "top" cho catalog Popular).
    private func fetchCatalogRow(addons: [StremioInstalledAddon], addonBaseURLs: [String], type: String, keyword: String, fallbackId: String?, title: String) async -> StremioAccountCatalogRow? {
        for (addon, base) in zip(addons, addonBaseURLs) {
            guard let catalog = addon.manifest.catalogs.first(where: {
                $0.type == type && ($0.name?.lowercased().contains(keyword) == true || $0.id.lowercased() == fallbackId)
            }) else { continue }

            if let metas = try? await StremioAPI.shared.fetchCatalog(baseURL: base, type: catalog.type, id: catalog.id),
               !metas.isEmpty {
                print("[Stremio] \(title): \(addon.manifest.name)/\(catalog.type)-\(catalog.id), \(metas.count) item(s)")
                return StremioAccountCatalogRow(id: "\(base)-\(catalog.type)-\(catalog.id)", title: title, items: metas)
            }
        }
        return nil
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
