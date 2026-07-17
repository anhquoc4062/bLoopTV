//
//  StremioSearchView.swift
//  bLoopTV
//

import SwiftUI
import Combine

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

@MainActor
private final class StremioSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var submittedQuery = ""
    @Published private(set) var rows: [StremioSearchRow] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    static let aiCatalogs: [AISearchCatalog] = [
        AISearchCatalog(manifestName: "ai movie search", displayTitle: "Phim Lẻ"),
        AISearchCatalog(manifestName: "ai series search", displayTitle: "Phim Bộ")
    ]

    private var addons: [StremioInstalledAddon] = []
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    /// tvOS không có phím Enter — bàn phím của .searchable chỉ cập nhật text, không có sự kiện submit.
    /// Nên phải tự tìm sau khi người dùng ngừng gõ (giống pipeline của SearchViewModel bên Plex).
    /// Để 1200ms (dài hơn Plex 800ms) vì mỗi lần gọi là một lượt AI search, không nên bắn liên tục.
    func start(addons: [StremioInstalledAddon]) {
        self.addons = addons
        guard cancellables.isEmpty else { return }

        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(1200), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.count >= 2 {
                    self.search(trimmed)
                } else if trimmed.isEmpty {
                    self.clear()
                }
            }
            .store(in: &cancellables)
    }

    private func clear() {
        searchTask?.cancel()
        submittedQuery = ""
        rows = []
        isSearching = false
        errorMessage = nil
    }

    private func search(_ trimmed: String) {
        // Huỷ lượt tìm trước để kết quả cũ về trễ không đè lên kết quả của từ khoá mới.
        searchTask?.cancel()

        print("[Stremio] AI search: \(trimmed)")
        submittedQuery = trimmed
        isSearching = true
        errorMessage = nil
        rows = []

        searchTask = Task {
            var newRows: [StremioSearchRow] = []

            // Duyệt theo thứ tự aiCatalogs để "Phim Lẻ" luôn đứng trước "Phim Bộ", không phụ thuộc thứ tự
            // catalog khai báo trong manifest của addon.
            for spec in Self.aiCatalogs {
                if Task.isCancelled { return }

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

            if Task.isCancelled { return }

            rows = newRows
            isSearching = false
            if newRows.isEmpty {
                errorMessage = "Không tìm thấy kết quả nào"
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

/// Đồng bộ style với SearchView bên Plex: thanh .searchable của hệ thống + lưới 5 cột MovieCardView,
/// tự tìm sau khi ngừng gõ (tvOS không có phím Enter để submit).
struct StremioSearchView: View {
    let addons: [StremioInstalledAddon]

    @EnvironmentObject var navPathManager: NavigationPathManager
    @StateObject private var viewModel = StremioSearchViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    private var addonBaseURLs: [String] {
        addons.map { StremioAccountAPI.baseURL(fromTransportUrl: $0.transportUrl) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.submittedQuery.isEmpty && !viewModel.isSearching {
                initialStateView
            } else {
                resultsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $viewModel.searchText, prompt: "Tìm phim, series bằng AI...")
        .onAppear { viewModel.start(addons: addons) }
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
                    Text(viewModel.isSearching ? "Đang tìm kiếm..." : "Kết quả cho '\(viewModel.submittedQuery)'")
                    if viewModel.isSearching { ProgressView().controlSize(.small) }
                }
                .font(.headline)
                .padding(.horizontal, 60)

                if let errorMessage = viewModel.errorMessage, !viewModel.isSearching {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal, 60)
                }

                ForEach(viewModel.rows) { row in
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
}
