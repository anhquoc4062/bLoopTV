//
//  MovieDetailView.swift
//  bLoopTV
//
//  Rewritten for tvOS — fixed thumbnail, clean layout, focus-optimized
//

import SwiftUI
import SDWebImageSwiftUI
import Combine

struct MovieDetailView: View {
    @EnvironmentObject var navManager: NavigationPathManager

    @StateObject private var viewModel = MovieDetailViewModel()
    @StateObject private var blurColors = BlurColors()

    let metadata: PlexMetaData
    let isDiscover: Bool

    // MARK: - State
    @State private var showPlayer = false
    @State private var playbackData: PlaybackData? = nil
    @State private var shouldReloadSeason = false
    @State private var relatedCollections: [String: PlexHomeCollection] = [:]
    @State private var hasFetchedRelated = false
    @State private var screenWidth: CGFloat = 1920 // tvOS default
    @State private var listRole: [PlexActor] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background — luôn fullscreen, không phụ thuộc scroll
            backgroundLayer
                .ignoresSafeArea()

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection.focusSection()
                    contentSection.focusSection()
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear { handleOnAppear() }
        .animation(.easeInOut(duration: 0.3), value: showPlayer)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail — right side, fading into background
            thumbnailView.edgesIgnoringSafeArea(.trailing)

            // Left side: logo + metadata + actions
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                logoView
                titleView
                metaInfoView
                summaryView
                actionButtons
            }
            // .padding(.leading, 30)
            .padding(.bottom, 60)
            .frame(maxWidth: screenWidth * 0.52, alignment: .leading)
        }
        .frame(height: 880)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { screenWidth = geo.size.width }
            }
        )
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        let thumbWidth = screenWidth * 0.90

        ZStack(alignment: .trailing) {
            // Layer baseline (poster/art từ metadata) — hiện ngay, không bao giờ bị xoá.
            thumbLayer(url: viewModel.thumbnailURL, width: thumbWidth)

            // Layer discover — fade-in đè lên baseline khi ảnh "background" về (nếu có).
            if viewModel.discoverThumbnailURL != nil {
                thumbLayer(url: viewModel.discoverThumbnailURL, width: thumbWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 880, alignment: .trailing)
    }

    private func thumbLayer(url: URL?, width: CGFloat) -> some View {
        FadeInWebImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 880)
                .clipped()
                .mask(thumbnailMask)
        }
        .frame(width: width, height: 880)
    }

    private var thumbnailMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.1),
                .init(color: .white, location: 0.3),
                .init(color: .clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
                
        )
        .mask(
            LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),          // transparent (từ 0 đến 10px - xấp xỉ 0)
                        .init(color: .black.opacity(0.2), location: 0.15), // rgba(0,0,0,.2) 15%
                        .init(color: .black, location: 0.40),         // black 40%
                        .init(color: .black, location: 0.80),         // black 80%
                        .init(color: .black, location: 0.99)          // transparent 99%
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
        )
        .compositingGroup()
    }

    // MARK: - Logo

    @ViewBuilder
    private var logoView: some View {
        if viewModel.logoURL != nil {
            FadeInWebImage(url: viewModel.logoURL) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 150)
            }
            .frame(maxWidth: 300, maxHeight: 150)
        } else {
            Color.clear.frame(height: 110)
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleView: some View {
        let title = metadata.type == "episode"
            ? (metadata.grandParentTitle ?? metadata.title)
            : metadata.title

        Text(title)
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
    }

    // MARK: - Meta Info

    private var metaInfoView: some View {
        let parts = [
            metadata.contentRating,
            metadata.year,
            metadata.duration.map { "\($0 / 60000) phút" }
        ].compactMap { $0 }

        return Text(parts.joined(separator: " • "))
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
    }

    // MARK: - Summary

    private var summaryView: some View {
        Text(viewModel.metaDataDetail?.summary ?? "Chưa có mô tả.")
            .font(.system(size: 22))
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(4)
            .frame(maxWidth: 700, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 20) {
            playButton.focusSection()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var playButton: some View {
        // Đang load metadata (selectedMetadata == nil) — không dùng Menu vì lúc đó content bên trong Menu
        // hoàn toàn rỗng (chưa có version nào để liệt kê), bấm vào sẽ ra menu trống/không phản hồi.
        if let selected = viewModel.selectedMetadata {
            if selected.listVersionFiltered.count == 1, let onlyVersion = selected.listVersionFiltered.first {
                // Chỉ có đúng 1 bản thì phát luôn, khỏi bắt chọn thêm 1 bước thừa.
                Button {
                    showVideoPlayer(version: onlyVersion)
                } label: {
                    playButtonLabelContent
                }
                .buttonStyle(.plain)
                .background(Color("VArtThemeColor"), in: RoundedRectangle(cornerRadius: 14))
                .hoverEffect()
            } else if !selected.listVersionFiltered.isEmpty {
                Menu {
                    ForEach(selected.listVersionFiltered) { version in
                        Button(versionLabel(version)) {
                            showVideoPlayer(version: version)
                        }
                    }
                } label: {
                    playButtonLabelContent
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .background(Color("VArtThemeColor"), in: RoundedRectangle(cornerRadius: 14))
                .hoverEffect()
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color("ButtonText"))
                    Text("Không có bản phát")
                        .foregroundStyle(Color("ButtonText"))
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 18)
                .background(Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            }
        } else {
            HStack(spacing: 14) {
                ProgressView()
                    .tint(Color("ButtonText"))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background(Color("VArtThemeColor"), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var playButtonLabelContent: some View {
        HStack(spacing: 14) {
            Image(systemName: (viewModel.selectedMetadata?.viewOffset ?? 0) > 0 ? "memories" : "play.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color("ButtonText"))

            Text(playButtonLabel)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color("ButtonText"))
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 18)
    }

    private func versionLabel(_ version: PlexMedia) -> String {
        var parts = [version.videoResolution.uppercased(), version.videoCodec.uppercased()]
        if let bitrate = version.bitrate {
            parts.append("\(bitrate / 1000) Mbps")
        }
        return parts.joined(separator: " • ")
    }

    private var playButtonLabel: String {
        guard let selected = viewModel.selectedMetadata else {
            return "Xem Từ Đầu"
        }

        let hasProgress = selected.viewOffset > 0

        if selected.type == "episode" {
            let base = hasProgress ? "Tiếp Tục Xem" : "Xem Từ Đầu"

            return "\(base) M\(selected.seasonIndex ?? 1)•T\(selected.episodeIndex ?? 1)"
        }

        // MARK: - Movie Progress
        if hasProgress {

            let seconds = selected.viewOffset / 1000
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60

            if minutes > 0 {
                return "Xem tiếp từ \(minutes)p \(remainingSeconds)g"
            } else {
                return "Xem tiếp từ \(remainingSeconds)g"
            }
        }

        return "Xem Từ Đầu"
    }

    // MARK: - Content Section (Episodes + Related)

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 48) {
            // Season selector
            if metadata.type == "show" || metadata.type == "episode" {
                SeasonSelectorView(
                    id: metadata.grandParentId ?? metadata.parentId ?? metadata.id,
                    isDiscover: isDiscover,
                    movieDetailViewModel: viewModel,
                    onSelectEpisode: { episode in
                        Task {
                            await viewModel.updateSelectedMetadataByEpisode(episodeData: episode)
                        }
                    },
                    triggerReload: $shouldReloadSeason
                )
                .id(metadata.grandParentId ?? metadata.parentId ?? metadata.id)
            }
            
            ActorSectionView(listRole: listRole)
                .focusSection()

            // Related collections
            relatedSection
        }
        .padding(.top, 20)
        .padding(.bottom, 80)
    }

    @ViewBuilder
    private var relatedSection: some View {
        if relatedCollections.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            ForEach(Array(relatedCollections.values), id: \.title) { collection in
                SectionView(
                    sectionTitle: replaceTitle(title: collection.title),
                    hubKey: collection.key,
                    metadatas: collection.metadatas ?? [],
                    isLandscapeSection: collection.id == "extras",
                    isDiscover: isDiscover
                ).focusSection()
            }
        }
    }

    // MARK: - Background Layer

    @ViewBuilder
    private var backgroundLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = max(w, h)

            ZStack {
                Color.black

                RadialGradient(
                    colors: [Color(hex: blurColors.bottomLeft), .clear],
                    center: .bottomLeading, startRadius: 0, endRadius: r
                )
                RadialGradient(
                    colors: [Color(hex: blurColors.bottomRight), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: r
                )
                RadialGradient(
                    colors: [Color(hex: blurColors.topRight), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: r
                )
                RadialGradient(
                    colors: [Color(hex: blurColors.topLeft), .clear],
                    center: .topLeading, startRadius: 0, endRadius: r
                )
            }
            .frame(width: w, height: h)
        }.drawingGroup()
    }
    // MARK: - onAppear

    private func handleOnAppear() {
        // Screen width fallback cho tvOS
        screenWidth = UIScreen.main.bounds.width

        // Blur colors từ metadata
        if let colors = metadata.ultraBlurColors {
            blurColors.topLeft = colors.topLeft
            blurColors.topRight = colors.topRight
            blurColors.bottomLeft = colors.bottomLeft
            blurColors.bottomRight = colors.bottomRight
        }

        // Baseline ngay lập tức từ chính metadata đã có sẵn (poster/art) — trước đây thumbnailURL/logoURL
        // CHỈ được gán bên trong renderDiscoverImage (chạy sau khi fetch API Discover bên ngoài thành công).
        // Discover là dịch vụ Plex tách biệt, dễ fail âm thầm (guid dạng cũ, thiếu plexToken, không có
        // field "images"...) — lúc đó thumbnailURL/logoURL không bao giờ được gán, hero luôn trống trơn dù
        // không có lỗi/crash gì. Set baseline trước để luôn có gì đó hiện ra ngay, Discover fetch xong thì
        // ghi đè bằng ảnh đẹp hơn (nếu có).
        viewModel.thumbnailURL = PlexAPI.shared.getPosterTranscodeURL(
            url: metadata.thumbnail ?? metadata.poster,
            width: 1280,
            height: 800
        )
        viewModel.fetchThumbnail(url: metadata.thumbnail)

        // Fetch discover image nếu cần (có thể ghi đè baseline ở trên bằng ảnh "background"/logo đẹp hơn).
        // Thử ngay với guid từ list (nhanh), thường là guid canonical "plex://..." với server dùng agent mới.
        if !isDiscover {
            Task { await tryRenderDiscoverImage(from: metadata.guid, label: "list") }
        }


        // Fetch metadata detail + related
        Task {
            await viewModel.fetchMetadataDetailAsync(
                id: metadata.grandParentId ?? metadata.parentId ?? metadata.id,
                isDiscover: isDiscover
            )

            // Nội dung đã ở dạng Discover sẵn (isDiscover == true) thì metaDataDetail đã có ảnh, dùng luôn
            // thay vì gọi lại API discover lần nữa như nhánh !isDiscover ở trên.
            if isDiscover, let detail = viewModel.metaDataDetail {
                renderDiscoverImage(metadataDetail: detail)
            } else if viewModel.logoURL == nil {
                // Guid từ list có thể là dạng agent cũ (không canonical) → không lấy được discover.
                // Guid trong metadata detail đầy đủ (từ server) thường chuẩn "plex://..." hơn, thử lại lần nữa.
                await tryRenderDiscoverImage(from: viewModel.metaDataDetail?.guid, label: "detail")
            }

            if let roles = viewModel.metaDataDetail?.roles {
                listRole = roles
            }

            guard !hasFetchedRelated else { return }
            hasFetchedRelated = true

            viewModel.fetchRelatedByRatingKey(
                ratingKey: metadata.grandParentId ?? metadata.parentId ?? metadata.id,
                isDiscover: isDiscover
            ) { collections in
                for collection in collections {
                    relatedCollections[collection.id] = collection
                    viewModel.fetchMetadatasByHubKey(
                        key: collection.key,
                        offset: collection.metadatas?.count ?? 0,
                        size: 36,
                        isDiscover: isDiscover
                    ) { metadatas in
                        if var existing = relatedCollections[collection.id]?.metadatas {
                            existing.append(contentsOf: metadatas)
                            relatedCollections[collection.id]?.metadatas = existing
                        } else {
                            relatedCollections[collection.id]?.metadatas = metadatas
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func showVideoPlayer(version: PlexMedia) {
        guard let selected = viewModel.selectedMetadata,
              let part = version.parts.first else { return }

        navManager.push(
            .videoPlayer(
                playbackData: PlaybackData(
                    videoUrl: PlexAPI.shared.getVideoURL(urlString: part.url),
                    videoTitle: selected.type == "episode"
                        ? "\(metadata.grandParentTitle ?? metadata.title) - M\(selected.seasonIndex ?? 1)•T\(selected.episodeIndex ?? 1)"
                        : metadata.title,
                    grandVideoTitle: metadata.title,
                    viewOffset: selected.viewOffset,
                    duration: selected.duration,
                    videoID: part.id,
                    grandVideoID: part.id,
                    ratingKey: selected.id,
                    thumbnailUrl: viewModel.localThumbnailURL?.absoluteString ?? "",
                    mediaPartStreams: part.streams,
                    currentIndex: 0,
                    playlist: [],
                    ultraBlurColors: metadata.ultraBlurColors ?? PlexUltraBlurColors(
                        topLeft: "#000000",
                        topRight: "#000000",
                        bottomRight: "#000000",
                        bottomLeft: "#000000"
                    ),
                    markers: selected.listMarker,
                    versions: selected.listVersionFiltered,
                    selectedMediaId: version.id
                )
            )
        )
    }

    /// Gọi Discover bằng guid (nếu là guid canonical "plex://...") rồi render ảnh nền/logo nếu lấy được.
    private func tryRenderDiscoverImage(from guid: String?, label: String) async {
        guard let guid else {
            print("[Discover] (\(label)) guid nil, bỏ qua")
            return
        }
        guard let key = viewModel.extractRatingKey(from: guid) else {
            print("[Discover] (\(label)) guid không phải plex:// (\(guid)) — bỏ qua, không gọi discover")
            return
        }
        print("[Discover] (\(label)) gọi discover với key=\(key) (guid=\(guid))")
        guard let detail = await viewModel.fetchMetadataFromDiscoverAsync(id: key) else {
            print("[Discover] (\(label)) fetch thất bại/nil cho key=\(key)")
            return
        }
        await MainActor.run { renderDiscoverImage(metadataDetail: detail) }
    }

    private func renderDiscoverImage(metadataDetail: PlexMetaDataDetail) {
        guard let images = metadataDetail.images else {
            print("[Discover] metadataDetail.images == nil, không có ảnh discover")
            return
        }

        print("[Discover] nhận \(images.count) ảnh: \(images.map { $0.type })")

        // Set vào layer discover riêng (không đụng thumbnailURL baseline) → baseline vẫn hiện liên tục,
        // ảnh discover fade-in đè lên trên, không có khoảng trống trắng gây "chớp".
        if let bg = images.first(where: { $0.type == "background" }) {
            viewModel.discoverThumbnailURL = URL(string: bg.url)
        }

        if let logo = images.first(where: { $0.type == "clearLogo" }) {
            viewModel.logoURL = URL(string: logo.url)
        }
    }

    private func replaceTitle(_ title: String) -> String {
        var result = title
        let replacements: [String: String] = [
            "Collection": "",
            "More with": "Phim của",
            "More by": "Phim của",
            "Related Movies": "Phim có liên quan",
            "Related Shows": "Series có liên quan",
            "TV Shows in": "",
            "Movies in": "",
            "More from": "Có trên",
        ]
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // replaceTitle overload nhận title label (giữ tương thích)
    private func replaceTitle(title: String) -> String {
        replaceTitle(title)
    }
}

/// WebImage tự fade-in mượt đúng lúc ảnh giải mã xong (onSuccess) thay vì pop/nháy. Reset khi url đổi để
/// lần load mới cũng fade lại từ đầu. Dùng cho logo/thumbnail ở màn detail (ảnh Discover về trễ).
private struct FadeInWebImage<Content: View>: View {
    let url: URL?
    var options: SDWebImageOptions = [.scaleDownLargeImages]
    @ViewBuilder let content: (Image) -> Content

    @State private var visible = false

    var body: some View {
        WebImage(url: url, options: options) { image in
            content(image)
        } placeholder: {
            Color.clear
        }
        .onSuccess { _, _, _ in
            withAnimation(.easeIn(duration: 0.5)) { visible = true }
        }
        .cancelOnDisappear(true)
        .opacity(visible ? 1 : 0)
        .onChange(of: url) { _ in visible = false }
    }
}
