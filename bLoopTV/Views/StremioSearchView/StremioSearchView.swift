//
//  StremioSearchView.swift
//  bLoopTV
//

import SwiftUI

private struct StremioSearchRow: Identifiable {
    let id: String
    let title: String
    let items: [StremioMeta]
    /// Chuyển sẵn 1 lần lúc dựng hàng để dùng chung MovieCardView với bên Plex.
    let metadatas: [PlexMetaData]

    init(id: String, title: String, items: [StremioMeta]) {
        self.id = id
        self.title = title
        self.items = items
        self.metadatas = items.map { $0.asPlexMetaData }
    }

    func item(forMetadataId id: String) -> StremioMeta? {
        items.first { $0.id == id }
    }
}

/// Chỉ dùng kết quả của addon AI Search (bỏ qua catalog tìm kiếm của các addon khác). Khớp theo tên
/// catalog trong manifest, không phân biệt hoa thường. Thứ tự trong mảng cũng là thứ tự hiển thị.
private struct AISearchCatalog {
    let manifestName: String
    let displayTitle: String
}

/// Đồng bộ style với SearchView bên Plex: thanh .searchable của hệ thống + lưới 5 cột MovieCardView,
/// thay vì TextField + nút bấm như trước.
struct StremioSearchView: View {
    let addons: [StremioInstalledAddon]

    @EnvironmentObject var navPathManager: NavigationPathManager

    @State private var query: String = ""
    @State private var submittedQuery: String = ""
    @State private var rows: [StremioSearchRow] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private static let aiCatalogs: [AISearchCatalog] = [
        AISearchCatalog(manifestName: "ai movie search", displayTitle: "Phim Lẻ"),
        AISearchCatalog(manifestName: "ai series search", displayTitle: "Phim Bộ")
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    private var addonBaseURLs: [String] {
        addons.map { StremioAccountAPI.baseURL(fromTransportUrl: $0.transportUrl) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if submittedQuery.isEmpty && !isSearching {
                initialStateView
            } else {
                resultsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // AI search tốn tài nguyên/tiền — chỉ gọi khi người dùng bấm tìm, không gọi theo từng ký tự gõ.
        .searchable(text: $query, prompt: "Tìm phim, series bằng AI...")
        .onSubmit(of: .search) { search() }
    }

    // MARK: - Trạng thái ban đầu

    private var initialStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text("Nhập nội dung để tìm kiếm bằng AI")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Kết quả

    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                HStack {
                    Text(isSearching ? "Đang tìm kiếm..." : "Kết quả cho '\(submittedQuery)'")
                    if isSearching { ProgressView().controlSize(.small) }
                }
                .font(.headline)
                .padding(.horizontal, 60)

                if let errorMessage, !isSearching {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal, 60)
                }

                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 20) {
                        Text(row.title)
                            .font(.headline)
                            .padding(.horizontal, 60)

                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(row.metadatas) { metadata in
                                MovieCardView(
                                    metadata: metadata,
                                    isLandscape: false,
                                    isContinueWatching: false,
                                    onSelect: {
                                        guard let item = row.item(forMetadataId: metadata.id) else { return }
                                        navPathManager.push(.stremioMovieDetail(item: item, addonBaseURLs: addonBaseURLs))
                                    },
                                    subtitleOverride: row.item(forMetadataId: metadata.id)?.cardSubtitle
                                )
                            }
                        }
                        .padding(.horizontal, 60)
                    }
                    .focusSection()
                }
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Tìm kiếm

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        print("[Stremio] AI search: \(trimmed)")
        submittedQuery = trimmed
        isSearching = true
        errorMessage = nil
        rows = []

        Task {
            var newRows: [StremioSearchRow] = []

            // Duyệt theo thứ tự aiCatalogs để "Phim Lẻ" luôn đứng trước "Phim Bộ", không phụ thuộc thứ tự
            // catalog khai báo trong manifest của addon.
            for spec in Self.aiCatalogs {
                guard let match = findCatalog(named: spec.manifestName) else {
                    print("[Stremio] không thấy catalog AI '\(spec.manifestName)' trong addon nào")
                    continue
                }

                if let metas = try? await StremioAPI.shared.fetchCatalog(
                    baseURL: match.base,
                    type: match.catalog.type,
                    id: match.catalog.id,
                    searchQuery: trimmed
                ), !metas.isEmpty {
                    print("[Stremio] \(spec.displayTitle): \(metas.count) kết quả")
                    newRows.append(
                        StremioSearchRow(
                            id: "\(match.base)-\(match.catalog.type)-\(match.catalog.id)",
                            title: spec.displayTitle,
                            items: metas
                        )
                    )
                }
            }

            await MainActor.run {
                rows = newRows
                isSearching = false
                if newRows.isEmpty {
                    errorMessage = "Không tìm thấy kết quả nào"
                }
            }
        }
    }

    private func findCatalog(named name: String) -> (base: String, catalog: StremioCatalogDescriptor)? {
        for addon in addons {
            let base = StremioAccountAPI.baseURL(fromTransportUrl: addon.transportUrl)
            if let catalog = addon.manifest.catalogs.first(where: {
                $0.supportsSearch
                    && $0.name?.trimmingCharacters(in: .whitespaces).lowercased() == name
            }) {
                return (base, catalog)
            }
        }
        return nil
    }
}
