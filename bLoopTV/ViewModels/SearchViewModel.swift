//
//  SearchViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 11/6/25.
//
import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedText = ""
    @Published var searchItems: [PlexSearchItem] = [] // Kết quả gộp cuối cùng
    @Published var recentSearch: [String] = []
    @Published var suggestedTerms: [String] = []
    @Published var isSearching: Bool = false
    @Published var listCategory: [PlexCategory] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        if let saved = UserDefaults.standard.array(forKey: "recentSearch") as? [String] {
            recentSearch = saved
        }
        // Khởi động pipeline ngay khi init
        startSearchPipelineIfNeeded()
        // Load categories từ cache để hiển thị danh sách thể loại ban đầu
        self.listCategory = mergeAllCachedCategories()
    }
    
    func startSearchPipelineIfNeeded() {
        guard cancellables.isEmpty else { return }

        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.debouncedText = text
                
                if text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    self.fetchMetadataByKeyword(keyword: text)
                    self.addRecentSearch(text)
                } else if text.isEmpty {
                    self.clearSearchData()
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchMetadataByKeyword(keyword: String) {
        isSearching = true
        self.searchItems = [] // Reset để hiện loading
        self.suggestedTerms = []

        // 1. Fetch từ server hiện tại (Internal)
        PlexAPI.shared.request(
            path: "/library/search",
            queryItems: [
                URLQueryItem(name: "query", value: keyword),
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "includeSummary", value: "1")
            ],
            responseType: PlexSearchItemResponse.self
        ) { [weak self] result in
            if case .success(let data) = result {
                let internalItems = data.mediaContainer.searchResult.filter {
                    $0.metadata?.type != "episode"
                }
                DispatchQueue.main.async {
                    self?.mergeSearchResults(newItems: internalItems)
                }
            }
        }

        // 2. Fetch từ Discover (External - Giống VidHub)
        PlexAPI.shared.fetchExternalMetadataByKeyword(keyword: keyword) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSearching = false
                switch result {
                case .success((let externalResults, let suggestions)):
                    // Đánh dấu external flag để ưu tiên hiển thị
                    let filtered = externalResults.map { $0.withExternalFlag(true) }
                    self?.mergeSearchResults(newItems: filtered)
                    self?.suggestedTerms = suggestions
                case .failure(let error):
                    print("Error (external): \(error)")
                }
            }
        }
    }
    
    private func mergeSearchResults(newItems: [PlexSearchItem]) {
        // Gộp item mới vào mảng hiện tại
        var currentItems = self.searchItems
        currentItems.append(contentsOf: newItems)

        // 1. Lọc bỏ các item không hợp lệ
        let validItems = currentItems.filter { $0.metadata != nil || $0.directory != nil }
        
        // 2. Loại bỏ trùng lặp dựa trên ID (ratingKey)
        let deduplicated: [PlexSearchItem] = Dictionary(grouping: validItems, by: \.id)
            .compactMap { $0.value.first }

        // 3. Sắp xếp theo logic ưu tiên (VidHub style)
        self.searchItems = deduplicated.sorted {
            // Ưu tiên External (Discover) lên đầu vì thường metadata đẹp hơn
            if $0.isExternal != $1.isExternal {
                return $0.isExternal && !$1.isExternal
            }

            // Ưu tiên theo loại nội dung
            func priority(for type: String) -> Int {
                switch type {
                case "movie": return 0
                case "show": return 0
                case "people": return 1
                case "tag": return 2
                default: return 99
                }
            }

            let p0 = priority(for: $0.metadata?.type ?? $0.directory?.type ?? "")
            let p1 = priority(for: $1.metadata?.type ?? $1.directory?.type ?? "")

            if p0 != p1 { return p0 < p1 }
            
            // Cuối cùng so sánh theo score của Plex
            return $0.score > $1.score
        }
    }

    func mergeAllCachedCategories() -> [PlexCategory] {
        var merged: [PlexCategory] = []
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        
        for key in allKeys where key.hasPrefix("cachedCategories_") {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([PlexCategory].self, from: data) {
                merged.append(contentsOf: decoded)
            }
        }

        return Array(
            Dictionary(grouping: merged, by: { $0.id }).compactMap { $0.value.first }
        ).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    func clearSearchData() {
        searchText = ""
        debouncedText = ""
        searchItems = []
        suggestedTerms = []
        isSearching = false
    }
    
    private func addRecentSearch(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var current = recentSearch
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        
        recentSearch = current
        UserDefaults.standard.set(current, forKey: "recentSearch")
    }
    
    deinit {
        cancellables.removeAll()
    }
}
