import SwiftUI
import SDWebImageSwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject var navPathManager: NavigationPathManager
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.searchText.isEmpty && viewModel.searchItems.isEmpty {
                initialStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            Color("BackgroundColor")
//                .ignoresSafeArea()
//        )
        .searchable(text: $viewModel.searchText, prompt: "Tìm tên phim, diễn viên...")
        .onAppear {
            viewModel.startSearchPipelineIfNeeded()
        }
    }

    // MARK: - Initial State (Recent Search & Empty)
    private var initialStateView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.recentSearch.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tìm kiếm gần đây")
                        .font(.headline)
                        .padding(.horizontal, 60)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) { // Tăng spacing giữa các card một chút
                            ForEach(viewModel.recentSearch, id: \.self) { text in
                                Button {
                                    viewModel.searchText = text
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                        Text(text)
                                            .font(.headline)
                                    }
                                    .padding(.horizontal, 10)
                                }
                                .buttonStyle(.card)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 30)
                    }
                }
                .padding(.top, 40)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    Text("Nhập nội dung để tìm kiếm trên bLoopTV")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if !viewModel.recentSearch.isEmpty {
                Spacer()
            }
        }
    }

    // MARK: - Results Grid
    private var resultsGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                
                // Giao diện Gợi ý từ khóa (Suggested Terms) như VidHub
                if !viewModel.suggestedTerms.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Gợi ý").font(.headline).padding(.horizontal, 60)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(viewModel.suggestedTerms, id: \.self) { term in
                                    Button(term) { viewModel.searchText = term }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 25).padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.2)).cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 60)
                        }
                    }
                }

                // Lưới hiển thị kết quả đã gộp và lọc trùng từ nhiều server
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(viewModel.isSearching ? "Đang tìm kiếm..." : "Kết quả cho '\(viewModel.debouncedText)'")
                        if viewModel.isSearching { ProgressView().controlSize(.small) }
                    }
                    .font(.headline).padding(.horizontal, 60)

                    LazyVGrid(columns: columns, spacing: 60) {
                        ForEach(viewModel.searchItems, id: \.id) { searchItem in
                            if let metadata = searchItem.metadata {
                                if !searchItem.isExternal {
                                    MovieCardView(metadata: metadata, isLandscape: false, isContinueWatching: false)
                                }
                            } else if let actor = searchItem.directory {
                                // SearchItemActorView(actor: actor)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                }
            }
            .padding(.vertical, 40)
        }
    }
}
