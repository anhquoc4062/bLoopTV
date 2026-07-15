//
//  StremioSearchView.swift
//  bLoopTV
//

import SwiftUI

private struct StremioSearchRow: Identifiable {
    let id: String
    let title: String
    let items: [StremioMeta]
}

struct StremioSearchView: View {
    let addons: [StremioInstalledAddon]

    @EnvironmentObject var navPathManager: NavigationPathManager

    @State private var query: String = ""
    @State private var rows: [StremioSearchRow] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private var addonBaseURLs: [String] {
        addons.map { StremioAccountAPI.baseURL(fromTransportUrl: $0.transportUrl) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                searchInputSection

                if isSearching {
                    ProgressView()
                        .padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    ForEach(rows) { row in
                        StremioSectionView(sectionTitle: row.title, items: row.items) { item in
                            navPathManager.push(.stremioMovieDetail(item: item, addonBaseURLs: addonBaseURLs))
                        }
                        .focusSection()
                    }
                }
            }
            .padding(.horizontal, 80)
            .padding(.top, 60)
        }
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.top)
    }

    private var searchInputSection: some View {
        HStack(spacing: 20) {
            TextField("Tìm phim, series...", text: $query, onCommit: search)
                .frame(maxWidth: 600)

            Button("Tìm kiếm") {
                search()
            }
            .buttonStyle(.card)
        }
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        print("[Stremio] Tìm kiếm: \(trimmed)")
        isSearching = true
        errorMessage = nil
        rows = []

        Task {
            var newRows: [StremioSearchRow] = []

            for addon in addons {
                let base = StremioAccountAPI.baseURL(fromTransportUrl: addon.transportUrl)
                for catalog in addon.manifest.catalogs where catalog.supportsSearch {
                    if let metas = try? await StremioAPI.shared.fetchCatalog(baseURL: base, type: catalog.type, id: catalog.id, searchQuery: trimmed),
                       !metas.isEmpty {
                        print("[Stremio] \(addon.manifest.name)/\(catalog.type)-\(catalog.id): \(metas.count) kết quả")
                        newRows.append(StremioSearchRow(id: "\(base)-\(catalog.type)-\(catalog.id)", title: "\(addon.manifest.name) - \(catalog.name ?? catalog.id)", items: metas))
                    }
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
}
