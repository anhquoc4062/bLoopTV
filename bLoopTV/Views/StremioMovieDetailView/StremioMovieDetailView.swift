//
//  StremioMovieDetailView.swift
//  bLoopTV
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

private struct StremioStreamOption: Identifiable {
    let id = UUID()
    let addonBase: String
    let stream: StremioStream

    var label: String {
        stream.title ?? stream.name ?? "Nguồn phát"
    }

    /// Vài addon trộn cả link phụ đề rời vào chung /stream — loại các link đuôi phụ đề khỏi danh sách phát.
    private static let subtitleExtensions: Set<String> = ["srt", "vtt", "ass", "ssa", "sub"]

    var isSubtitleFile: Bool {
        guard let urlString = stream.url,
              let ext = URL(string: urlString)?.pathExtension.lowercased() else { return false }
        return Self.subtitleExtensions.contains(ext)
    }
}

/// Trang detail riêng cho item Stremio, viết mới hoàn toàn (không tái sử dụng MovieDetailView của Plex
/// vì view đó gắn chặt với PlexMetaData/ratingKey thật). Layout hero + nút Phát clone style MovieDetailView,
/// dùng "background" (ảnh ngang thật) từ /meta thay vì kéo giãn poster (ảnh dọc) gây bể hình.
/// Bộ chọn Mùa/Tập cũng viết mới (không dùng lại SeasonSelectorView của Plex vì cần MovieDetailViewModel/
/// ratingKey Plex thật), nhưng đồng bộ style, hiện luôn trên trang thay vì menu (Menu lồng Menu không hoạt
/// động ổn định trên tvOS).
/// Khi phát, đi qua đúng VideoPlayerView/PlaybackData pipeline sẵn có của app (giống hệt luồng Plex).
struct StremioMovieDetailView: View {
    let item: StremioMeta
    let addons: [StremioInstalledAddon]

    /// Base URL của mọi addon — dùng để lấy nguồn phát (stream) từ tất cả addon như cũ.
    private var addonBaseURLs: [String] { addons.baseURLs }

    @EnvironmentObject var navPathManager: NavigationPathManager

    /// Meta chính đã về từ TMDB chưa — để Cinemeta (placeholder) không ghi đè lên bản TMDB.
    @State private var hasPrimaryMeta = false

    /// Đánh dấu đã xem lưu local — @ObservedObject để thẻ tập tự cập nhật dấu check ngay khi thoát player về.
    @ObservedObject private var watchedService = StremioWatchedService.shared

    /// 4 màu góc trích từ poster để dựng gradient nền (Stremio không có UltraBlurColors như Plex).
    @StateObject private var cornerColors = PosterCornerColorsModel()

    @State private var metaDetail: StremioMetaDetail?
    @State private var screenWidth: CGFloat = 1920

    @State private var resolvedStreamId: String = ""
    @State private var libraryItemId: String = ""
    @State private var existingLibraryItem: StremioLibraryItem?
    @State private var resumeOffsetMs = 0
    @State private var knownDurationMs = 0
    @State private var selectedSeason: Int?

    @State private var streamOptions: [StremioStreamOption] = []
    @State private var extraSubtitleStreams: [StremioStream] = []
    @State private var isLoadingStreams = true
    @State private var errorMessage: String?

    private var currentVideo: StremioVideoEntry? {
        metaDetail?.videos?.first { $0.id == resolvedStreamId }
    }

    private var seasons: [Int] {
        guard let videos = metaDetail?.videos else { return [] }
        // Mùa 0 (Đặc biệt) xếp cuối thay vì lên đầu.
        return Array(Set(videos.compactMap { $0.season })).sorted { lhs, rhs in
            if lhs == 0 { return false }
            if rhs == 0 { return true }
            return lhs < rhs
        }
    }

    private var activeSeason: Int {
        selectedSeason ?? currentVideo?.season ?? seasons.first ?? 1
    }

    @State private var hasPreparedStreams = false
    /// Người dùng đã tự bấm chọn tập trong phiên này — khi đó không tự nhảy sang tập kế nữa.
    @State private var userPickedEpisode = false
    /// Đổi mỗi lần bắt đầu 1 lượt lấy nguồn phát — kết quả của lượt cũ (đổi tập khi đang tải) bị bỏ qua.
    @State private var streamFetchToken = UUID()

    var body: some View {
        detailContent
            .onAppear {
                cornerColors.load(urlString: item.poster)
                loadMetaDetail()
                // Quay lại từ VideoPlayerView không gọi lại luồng lấy stream nữa — giữ nguyên kết quả cũ.
                guard !hasPreparedStreams else { return }
                hasPreparedStreams = true
                prepareStreamOptions()
            }
    }

    private var detailContent: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if cornerColors.colors.count == 4 {
                    CornerGradientBackground(colors: cornerColors.colors)
                } else {
                    Color("BackgroundColor")
                }
            }
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection.focusSection()

                    if item.type == "series" && !seasons.isEmpty {
                        seasonEpisodeSection.focusSection()
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            bannerView.edgesIgnoringSafeArea(.trailing)

            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                if let logoUrlString = metaDetail?.logo, let logoURL = URL(string: logoUrlString) {
                    FadeInWebImage(url: logoURL) { image in
                        image.resizable().scaledToFit().frame(maxWidth: 300, maxHeight: 130)
                    }
                    .frame(maxWidth: 300, maxHeight: 130)
                } else {
                    titleView
                }

                metaInfoView

                if let genres = metaDetail?.genres, !genres.isEmpty {
                    Text(genres.joined(separator: " • "))
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.6))
                }

                summaryView

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                actionButtons
            }
            .padding(.bottom, 60)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(height: 880)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { screenWidth = geo.size.width }
            }
        )
    }

    @ViewBuilder
    private var bannerView: some View {
        let bannerUrlString = metaDetail?.background ?? item.poster ?? ""

        DetailHeroBanner(imageURL: URL(string: bannerUrlString), screenWidth: screenWidth)
    }

    private var watchedBadge: some View {
        ZStack {
            Circle()
                .fill(Color("VArtThemeColor"))
                .frame(width: 32, height: 32)
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color("ButtonText"))
        }
    }

    private var titleView: some View {
        Text(item.name)
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
    }

    private var metaInfoView: some View {
        let parts = [
            metaDetail?.releaseInfo,
            metaDetail?.imdbRating.map { "IMDb \($0)" },
            item.type.capitalized
        ].compactMap { $0 }

        return Text(parts.joined(separator: " • "))
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
    }

    private var summaryView: some View {
        Text(metaDetail?.description ?? "Chưa có mô tả.")
            .font(.system(size: 20))
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(4)
            .frame(maxWidth: 700, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButtons: some View {
        HStack(spacing: 20) {
            playButton
        }
        .padding(.top, 8)
        .focusSection()
    }

    @ViewBuilder
    private var playButton: some View {
        // Không dùng .disabled() lúc loading — disabled khiến nút mất khả năng nhận focus, focus engine
        // sẽ nhảy lung tung ra chỗ khác. Thay vào đó vẫn giữ focus được, chỉ chặn hành động bên trong.
        if streamOptions.count == 1, let onlyOption = streamOptions.first {
            // Chỉ có đúng 1 nguồn phát thì phát luôn, khỏi bắt chọn thêm 1 bước thừa.
            Button {
                guard !isLoadingStreams else { return }
                play(with: onlyOption)
            } label: {
                playButtonLabelContent
            }
            .buttonStyle(.plain)
            .background(Color("VArtThemeColor"), in: RoundedRectangle(cornerRadius: 14))
            .hoverEffect()
        } else {
            Menu {
                if streamOptions.isEmpty {
                    Text("Không có nguồn phát")
                } else {
                    ForEach(streamOptions) { option in
                        Button(option.label) {
                            play(with: option)
                        }
                    }
                }
            } label: {
                playButtonLabelContent
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .background(Color("VArtThemeColor"), in: RoundedRectangle(cornerRadius: 14))
            .hoverEffect()
        }
    }

    private var playButtonLabelContent: some View {
        HStack(spacing: 20) {
            Group {
                if isLoadingStreams {
                    ProgressView()
                        .tint(Color("ButtonText"))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color("ButtonText"))
                }
            }
            .frame(width: 30, height: 30)

            Text(playLabel)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color("ButtonText"))
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 18)
    }

    private var playLabel: String {
        let prefix = resumeOffsetMs > 0 ? "Tiếp tục" : "Phát"
        guard item.type == "series", let video = currentVideo, let season = video.season, let episode = video.episode else {
            return prefix
        }
        return "\(prefix) - Mùa \(season) Tập \(episode)"
    }

    // MARK: - Bộ chọn Mùa/Tập (hiện luôn trên trang, chỉ với series)

    private var seasonEpisodeSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            seasonTabBar
            episodeRow
        }
        // .padding(.vertical, 32)
    }

    private var seasonTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(seasons, id: \.self) { season in
                    Button {
                        selectedSeason = season
                    } label: {
                        Text(season == 0 ? "Đặc biệt" : "Mùa \(season)")
                            .font(.system(size: 24, weight: activeSeason == season ? .bold : .regular))
                            .foregroundStyle(activeSeason == season ? Color("VArtThemeColor") : .secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.card)
                }
            }
            // Chừa khoảng trống 2 bên + trên dưới để thẻ không bị clip khi zoom focus (tvOS)
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }

    private var episodeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 40) {
                ForEach(episodes(forSeason: activeSeason)) { video in
                    episodeCard(video)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }

    // Đồng bộ kích thước/style với EpisodeCard trong SeasonSelectorView bên Plex (420x236 16:9, bo góc 14,
    // gradient dưới ảnh, viền màu khi đang là tập đang chọn).
    private func episodeCard(_ video: StremioVideoEntry) -> some View {
        let cardWidth: CGFloat = 420
        let cardHeight: CGFloat = 236
        let isCurrent = video.id == resolvedStreamId

        return VStack {
            Button {
                selectEpisode(video)
            } label: {
                ZStack(alignment: .topTrailing) {
                    WebImage(url: URL(string: video.thumbnail ?? ""), options: [.scaleDownLargeImages]) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .cornerRadius(14)

                    if isCurrent {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color("VArtThemeColor"), lineWidth: 4)
                            .frame(width: cardWidth, height: cardHeight)
                    }

                    VStack {
                        Spacer()
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 70)
                            .cornerRadius(14)
                    }
                    .frame(width: cardWidth, height: cardHeight)

                    // Đã xem xong (>=95% thời lượng) — cùng style watchedBadge của SeasonSelectorView bên Plex.
                    if watchedService.isWatched(video.id) {
                        watchedBadge
                            .offset(x: -10, y: 10)
                    }

                    if isCurrent {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Đang phát")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color("ButtonText"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color("VArtThemeColor"), in: Capsule())
                        .offset(x: -10, y: cardHeight - 40)
                    }
                }
                .frame(width: cardWidth)
            }
            .buttonStyle(.card)

            metadataView(video, cardWidth: cardWidth)
                .padding(.top, 12)
        }
    }

    private func metadataView(_ video: StremioVideoEntry, cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mùa \(video.season ?? 0) • Tập \(video.episode ?? 0)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color("VArtThemeColor"))

            if let name = video.name {
                Text(name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: cardWidth, alignment: .leading)
            }

            if let overview = video.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
    }

    private func episodes(forSeason season: Int) -> [StremioVideoEntry] {
        (metaDetail?.videos ?? [])
            .filter { $0.season == season }
            .sorted { ($0.episode ?? 0) < ($1.episode ?? 0) }
    }

    /// Toàn bộ tập theo đúng thứ tự xem: mùa tăng dần, mùa 0 (Đặc biệt) xếp cuối — khớp thứ tự tab mùa.
    private var orderedEpisodes: [StremioVideoEntry] {
        (metaDetail?.videos ?? []).sorted { lhs, rhs in
            let lhsSeason = lhs.season ?? 0
            let rhsSeason = rhs.season ?? 0
            if lhsSeason != rhsSeason {
                if lhsSeason == 0 { return false }
                if rhsSeason == 0 { return true }
                return lhsSeason < rhsSeason
            }
            return (lhs.episode ?? 0) < (rhs.episode ?? 0)
        }
    }

    /// Xem xong tập hiện tại (>=95%) thì nút Phát phải mời tập KẾ chứ không mời xem lại tập cũ — vì
    /// state library Stremio chỉ nhớ "tập xem gần nhất", quay về detail sẽ luôn trỏ lại đúng tập đó.
    /// Nhảy liên tiếp qua các tập đã xem để về đúng tập chưa xem đầu tiên (xem liền mấy tập cũng đúng).
    /// - Returns: true nếu có đổi tập (và đã tự nạp lại nguồn phát cho tập mới).
    @discardableResult
    private func advanceToNextUnwatchedEpisode() -> Bool {
        guard item.type == "series", !resolvedStreamId.isEmpty else { return false }
        // Người dùng tự bấm chọn tập thì tôn trọng lựa chọn đó, không tự nhảy đi chỗ khác.
        guard !userPickedEpisode else { return false }

        let list = orderedEpisodes
        guard var index = list.firstIndex(where: { $0.id == resolvedStreamId }) else { return false }

        var moved = false
        while watchedService.isWatched(list[index].id), index + 1 < list.count {
            index += 1
            moved = true
        }
        guard moved else { return false }

        let next = list[index]
        print("[Stremio] Tập \(resolvedStreamId) đã xem xong → nút Phát chuyển sang \(next.id)")

        resolvedStreamId = next.id
        resumeOffsetMs = 0
        knownDurationMs = 0
        selectedSeason = next.season
        fetchStreamOptions(for: next.id)
        return true
    }

    private func selectEpisode(_ video: StremioVideoEntry) {
        print("[Stremio] Chọn tập: \(video.id)")
        userPickedEpisode = true
        resolvedStreamId = video.id

        if video.id == existingLibraryItem?.state?.videoId {
            resumeOffsetMs = Int(existingLibraryItem?.state?.timeOffset ?? 0)
            knownDurationMs = Int(existingLibraryItem?.state?.duration ?? 0)
        } else {
            resumeOffsetMs = 0
            knownDurationMs = 0
        }

        fetchStreamOptions(for: video.id)
    }

    // MARK: - Load meta chi tiết cho hero (banner/logo/mô tả/thể loại/danh sách tập)

    private func loadMetaDetail() {
        // Placeholder nhanh từ Cinemeta để hero không trống trong lúc chờ TMDB (thường TMDB chậm hơn vì
        // đi qua server addon + localize). Cinemeta chỉ set nếu bản TMDB chính chưa về.
        if let cinemetaBase = addons.cinemeta?.baseURL {
            Task {
                guard let detail = try? await StremioAPI.shared.fetchMetaDetail(baseURL: cinemetaBase, type: item.type, id: item.id) else { return }
                await MainActor.run {
                    guard !hasPrimaryMeta else { return }
                    applyMeta(detail)
                }
            }
        }

        // Nguồn chính: TMDB addon (title/summary tiếng Việt). Không có TMDB thì fallback duyệt mọi addon.
        Task {
            let primaryBases = addons.tmdb.map { [$0.baseURL] } ?? addonBaseURLs
            for base in primaryBases {
                guard let detail = try? await StremioAPI.shared.fetchMetaDetail(baseURL: base, type: item.type, id: item.id) else { continue }
                await MainActor.run {
                    hasPrimaryMeta = true
                    applyMeta(detail)
                }
                return
            }
        }
    }

    private func applyMeta(_ detail: StremioMetaDetail) {
        metaDetail = detail
        // Có danh sách tập rồi mới biết tập kế là tập nào. Chạy cả lúc quay về từ player (onAppear gọi lại)
        // nên vừa xem xong tập là nút Phát nhảy sang tập kế ngay.
        advanceToNextUnwatchedEpisode()
    }

    // MARK: - Chuẩn bị vị trí resume + danh sách nguồn phát để chọn khi bấm Phát

    private func prepareStreamOptions() {
        Task {
            let resolvedLibraryItemId = item.id.split(separator: ":").first.map(String.init) ?? item.id

            var existing: StremioLibraryItem?
            var offsetMs = 0
            var durationMs = 0

            if let authKey = StremioAccountAPI.shared.authKey,
               let libraryItems = try? await StremioAccountAPI.shared.fetchLibraryItems(authKey: authKey) {
                existing = libraryItems.first { $0.id == resolvedLibraryItemId }
                offsetMs = Int(existing?.state?.timeOffset ?? 0)
                durationMs = Int(existing?.state?.duration ?? 0)
            }

            // Series bấm từ danh mục chưa có season/episode trong id. Tự chọn: tập đang xem dở nếu có,
            // chưa xem bao giờ thì mặc định Mùa 1 Tập 1 (giống Plex tự vào tập đầu khi chưa có lịch sử).
            var streamId = item.id
            if item.type == "series" && !item.id.contains(":") {
                if let resumeVideoId = existing?.state?.videoId, !resumeVideoId.isEmpty {
                    streamId = resumeVideoId
                } else {
                    streamId = "\(item.id):1:1"
                    offsetMs = 0
                    durationMs = 0
                }
            }

            let advanced = await MainActor.run { () -> Bool in
                libraryItemId = resolvedLibraryItemId
                existingLibraryItem = existing
                resumeOffsetMs = offsetMs
                knownDurationMs = durationMs
                resolvedStreamId = streamId

                // Tập vừa resolve từ library có thể đã xem xong rồi (vào lại app sau khi xem hết tập cũ)
                // — nhảy luôn sang tập kế, và chính nó tự nạp nguồn phát cho tập mới.
                return advanceToNextUnwatchedEpisode()
            }

            if !advanced {
                fetchStreamOptions(for: streamId)
            }
        }
    }

    private func fetchStreamOptions(for streamId: String) {
        let token = UUID()
        streamFetchToken = token

        isLoadingStreams = true
        streamOptions = []
        extraSubtitleStreams = []
        errorMessage = nil

        let type = item.type
        let bases = addonBaseURLs

        Task {
            // Hỏi tất cả addon SONG SONG, không chờ nhau. Addon nào trả về trước thì gom nguồn của nó vào
            // ngay và tắt loading — khỏi phải đợi mấy addon chậm.
            await withTaskGroup(of: (options: [StremioStreamOption], subs: [StremioStream]).self) { group in
                for base in bases {
                    group.addTask {
                        guard let streams = try? await StremioAPI.shared.fetchStreams(baseURL: base, type: type, id: streamId) else {
                            return ([], [])
                        }
                        var opts: [StremioStreamOption] = []
                        // Một số addon trả lẫn link phụ đề rời ngay trong /stream — gom riêng, không bỏ.
                        var subs: [StremioStream] = []
                        for stream in streams where stream.url != nil {
                            let option = StremioStreamOption(addonBase: base, stream: stream)
                            if option.isSubtitleFile {
                                subs.append(stream)
                            } else {
                                opts.append(option)
                            }
                        }
                        return (opts, subs)
                    }
                }

                for await result in group {
                    await MainActor.run {
                        // Đổi tập khi đang tải → token khác, bỏ kết quả của lượt cũ.
                        guard streamFetchToken == token else { return }
                        streamOptions.append(contentsOf: result.options)
                        extraSubtitleStreams.append(contentsOf: result.subs)
                        // Có nguồn phát đầu tiên là bỏ loading ngay; addon về sau vẫn append thêm vào danh sách.
                        if !result.options.isEmpty {
                            isLoadingStreams = false
                        }
                    }
                }
            }

            await MainActor.run {
                guard streamFetchToken == token else { return }
                print("[Stremio] Có \(streamOptions.count) nguồn phát, \(extraSubtitleStreams.count) sub rời riêng cho \(streamId)")
                isLoadingStreams = false
                if streamOptions.isEmpty {
                    errorMessage = "Không tìm được nguồn phát cho mục này"
                }
            }
        }
    }

    private func play(with option: StremioStreamOption) {
        print("[Stremio] Chọn nguồn: \(option.label)")

        // Gộp sub rời tìm thấy riêng trong /stream (không nằm trong "subtitles" của bản được chọn) vào chung.
        let mergedSubtitles = (option.stream.subtitles ?? []) + extraSubtitleStreams.compactMap { stream -> StremioStreamSubtitle? in
            guard let url = stream.url else { return nil }
            return StremioStreamSubtitle(id: nil, url: url, lang: stream.title ?? stream.name)
        }
        let streamForPlayback = StremioStream(url: option.stream.url, title: option.stream.title, name: option.stream.name, subtitles: mergedSubtitles)

        let streamItem = StremioMeta(id: resolvedStreamId, type: item.type, name: item.name, poster: item.poster)
        // Ảnh ngang cho lớp che khi load: ưu tiên still của tập → background phim → cuối cùng mới poster dọc.
        let coverImage = metaDetail?.background ?? item.poster
        guard let playbackData = StremioPlaybackConverter.buildPlaybackData(
            item: streamItem,
            stream: streamForPlayback,
            resumeOffsetMs: resumeOffsetMs,
            knownDurationMs: knownDurationMs,
            libraryItemId: StremioAccountAPI.shared.authKey != nil ? libraryItemId : nil,
            existing: existingLibraryItem,
            coverImageUrl: coverImage
        ) else {
            errorMessage = "Nguồn phát không hợp lệ"
            return
        }

        // Đã bấm Phát = chốt xem tập này, không còn là "đang chọn tập tay" nữa. Bỏ cờ để khi xem xong
        // quay về, advanceToNextUnwatchedEpisode được phép nhảy sang tập kế (nếu tập này đã đạt 95%).
        userPickedEpisode = false

        navPathManager.push(.videoPlayer(playbackData: playbackData))
    }
}
