import SwiftUI

// MARK: - Tab Enum
enum MediaTab: String, CaseIterable {
    case subtitle = "Phụ Đề"
    case audio = "Âm Thanh"
}

// MARK: - Main Panel
struct MediaSettingsPanel: View {
    @Binding var isPresented: Bool
    @Binding var selectedAudioId: Int?
    @Binding var selectedSubtitleId: Int?
    
    let streams: [PlexMediaPartStream]
    let onSelectAudio: (PlexMediaPartStream) -> Void
    let onSelectSubtitle: (PlexMediaPartStream?) -> Void
    /// Phần bù phụ đề (giây) — giữ ở VideoPlayerView để không mất khi đóng/mở lại panel.
    @Binding var subtitleDelay: Double
    let onSubtitleDelayChange: (Double) -> Void

    @State private var selectedTab: MediaTab = .subtitle
    
    // MARK: - Filtered Streams
    private var audioStreams: [PlexMediaPartStream] {
        streams.filter { $0.streamType == 2 }
    }
    
    private var subtitleStreams: [PlexMediaPartStream] {
        let subtitles = streams.filter { $0.streamType == 3 }

        let vi = subtitles.filter {
            $0.languageTag?.lowercased().hasPrefix("vi") == true
        }

        let en = subtitles.filter {
            $0.languageTag?.lowercased().hasPrefix("en") == true
        }

        // Phụ đề không xác định được ngôn ngữ (vd addon để "unknown") vẫn phải hiện ra, không âm thầm ẩn đi.
        let matchedIds = Set((vi + en).map { $0.id })
        let others = subtitles.filter { !matchedIds.contains($0.id) }

        return vi + en + others
    }
    
    @FocusState private var focusedTab: MediaTab?
    @Namespace private var menuNamespace
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Header Tabs
                HStack(spacing: 30) {
                    ForEach(MediaTab.allCases, id: \.self) { tab in
                        TabButton(
                            title: tab.rawValue,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                        .focused($focusedTab, equals: tab)
                        .prefersDefaultFocus(tab == .subtitle, in: menuNamespace)
                    }
                }
                .padding(.vertical, 35)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 60)
                
                // MARK: 2-Column Content
                HStack(alignment: .top, spacing: 50) {
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("CHỌN \(selectedTab.rawValue.uppercased())")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 10)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if selectedTab == .subtitle {
                                    StreamRow(
                                        label: "Tắt phụ đề",
                                        isSelected: selectedSubtitleId == nil
                                    ) {
                                        selectedSubtitleId = nil
                                        onSelectSubtitle(nil)
                                    }
                                    
                                    ForEach(subtitleStreams) { stream in
                                        let codec = stream.codec.uppercased() ?? ""
                                        StreamRow(
                                            label: codec == "SRT"
                                                        ? stream.displayTitle
                                                        : "\(stream.displayTitle) • \(codec)",
                                            isSelected: stream.id == selectedSubtitleId
                                        ) {
                                            selectedSubtitleId = stream.id
                                            onSelectSubtitle(stream)
                                        }
                                    }
                                } else {
                                    ForEach(audioStreams) { stream in
                                        StreamRow(
                                            label: stream.displayTitle,
                                            isSelected: stream.id == selectedAudioId
                                        ) {
                                            selectedAudioId = stream.id
                                            onSelectAudio(stream)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }.scrollClipDisabled()
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("CÀI ĐẶT CHI TIẾT")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 10)
                        
                        VStack(spacing: 10) {
                            if selectedTab == .subtitle {
                                SubtitleOffsetRow(
                                    offset: $subtitleDelay,
                                    onChange: onSubtitleDelayChange
                                )

                                // SettingRow(label: "Tìm Phụ Đề Online", value: "Search", icon: "magnifyingglass")
                                SettingRow(label: "Kích thước", value: "120%", icon: "textformat.size")
                                SettingRow(label: "Vị trí dọc", value: "Cạnh dưới", icon: "arrow.up.and.line.horizontal.and.arrow.down")
                                SettingRow(label: "Phông chữ", value: "Roboto", icon: "text.cursor")
                                SettingRow(label: "Định dạng", value: "Bold (Đậm)", icon: "bold")

                                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)

                                SettingRow(label: "Độ mờ nền", value: "40%", icon: "square.stack.3d.down.right.fill")
                                SettingRow(label: "Màu chữ", value: "Trắng", icon: "paintbrush.fill")
                            } else {
                                SettingRow(label: "Độ trễ âm thanh", value: "0 ms", icon: "speaker.wave.2")
                                SettingRow(label: "Chế độ ban đêm", value: "Tắt", icon: "moon.fill")
                                SettingRow(label: "Tăng cường hội thoại", value: "Bật", icon: "person.wave.2.fill")
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(width: 480)
                }
                .padding(60)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(40)
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedTab = .subtitle
            }
        }
    }
}

// MARK: - Sub-components

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onFocus: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: { onFocus() }) {
            Text(title)
                .font(.headline)
                .foregroundColor(isFocused ? .black : (isSelected ? .white : .white.opacity(0.5)))
                .padding(.vertical, 12)
                .padding(.horizontal, 40)
                .background(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.2) : Color.clear))
                .cornerRadius(30)
        }
        .buttonStyle(.borderless)
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
            if focused { onFocus() }
        }
    }
}

struct StreamRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isFocused ? .black : (isSelected ? Color("VArtThemeColor") : .white.opacity(0.4)))
                    .focusEffectDisabled()
                
                Text(label)
                    .font(.system(size: 28, weight: .medium))
                
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 25)
            .background(isFocused ? Color.white : Color.white.opacity(0.05))
            .foregroundColor(isFocused ? .black : .white)
            .cornerRadius(15)
        }
        .buttonStyle(.card)
        .focused($isFocused)
        // .scaleEffect(isFocused ? 1.03 : 1.0)
    }
}

/// Hàng chỉnh phần bù phụ đề: focus vào rồi vuốt/bấm trái-phải để trừ/cộng 0,1 giây.
/// onMoveCommand nuốt luôn lệnh di chuyển nên focus không nhảy sang cột bên cạnh khi đang chỉnh.
struct SubtitleOffsetRow: View {
    @Binding var offset: Double
    let onChange: (Double) -> Void

    @FocusState private var isFocused: Bool

    private static let step = 0.1
    private static let limit = 60.0

    private var displayValue: String {
        // Định dạng kiểu Việt: dấu phẩy thập phân, có dấu + khi dương cho rõ chiều bù.
        let number = String(format: "%.1f", abs(offset)).replacingOccurrences(of: ".", with: ",")
        let sign = offset > 0 ? "+" : (offset < 0 ? "−" : "")
        return "\(sign)\(number) giây"
    }

    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "timer")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)

                Text("Phần bù phụ đề")
                    .font(.system(size: 26))

                Spacer()

                // Chỉ gợi ý mũi tên khi đang focus để người dùng biết vuốt được.
                if isFocused {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .opacity(0.5)
                }

                Text(displayValue)
                    .font(.system(size: 26).monospacedDigit())
                    .opacity(isFocused ? 1 : 0.6)

                if isFocused {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .opacity(0.5)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 25)
            .background(isFocused ? Color.white : Color.clear)
            .foregroundColor(isFocused ? .black : .white)
            .cornerRadius(15)
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .onMoveCommand { direction in
            switch direction {
            case .left: adjust(-Self.step)
            case .right: adjust(Self.step)
            default: break
            }
        }
    }

    private func adjust(_ delta: Double) {
        // Nhân/chia 10 rồi làm tròn để tránh sai số dấu phẩy động cộng dồn (0.1 + 0.2 = 0.30000000000000004).
        let raw = ((offset + delta) * 10).rounded() / 10
        let clamped = min(max(raw, -Self.limit), Self.limit)
        guard clamped != offset else { return }
        offset = clamped
        onChange(clamped)
    }
}

struct SettingRow: View {
    let label: String
    let value: String
    let icon: String

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .scaleEffect(1.0)
                Text(label)
                    .font(.system(size: 26))
                Spacer()
                Text(value)
                    .font(.system(size: 26))
                    .opacity(isFocused ? 1 : 0.6)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 25)
            .background(isFocused ? Color.white : Color.clear)
            .foregroundColor(isFocused ? .black : .white)
            .cornerRadius(15)
        }
        .buttonStyle(.card)
        .focused($isFocused)
    }
}
