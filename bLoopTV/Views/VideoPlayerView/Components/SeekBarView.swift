//
//  CustomSeekBar.swift
//  bLoopTV
//
//  Created by Monster on 22/1/26.
//

import SwiftUI
struct FocusableSeekBarModifier: ViewModifier {
    @Binding var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focusable(true) { focused in
                self.isFocused = focused
            }
            // .scaleEffect(isFocused ? 1.05 : 1.0)
            // .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

extension View {
    func focusableSeekBar(isFocused: Binding<Bool>) -> some View {
        self.modifier(FocusableSeekBarModifier(isFocused: isFocused))
    }
}

struct SeekBarView: View {
    @Binding var position: Double
    @Binding var bufferProgress: Double
    let duration: Double
    // New parameters for Intro
    let showSkipIntro: Bool
    let introEndMs: Int
    
    let isScrubbing: Bool
    @Binding var scrubPosition: Double
    
    @FocusState.Binding var focusedElement: FocusField?
    let onSeek: (Double) -> Void
    let onSkipIntro: (Double) -> Void
    
    let gestures: PlayerGestures

    @State private var isFocused: Bool = false
    @Namespace private var seekbarNamespace // Add namespace for focus priority

    enum FocusField {
        case seekbar
        case skipButton
    }

    private let barHeight: CGFloat = 10
    
    var body: some View {
        ZStack {
            VStack(alignment: .trailing, spacing: 20) {
                
                // 1. Skip Intro Button Layer
                if showSkipIntro {
                    Button(action: {
                        onSkipIntro(Double(introEndMs) / 1000.0)
                    }) {
                        SkipIntroLabel()
                    }
                    .buttonStyle(.card)
                    .focused($focusedElement, equals: .skipButton)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // 2. Progress Bar Section
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {

                            // MARK: - Background Track
                            Capsule()
                                .fill(Color.white.opacity(0.2))

                            // MARK: - Buffer Progress
                            Rectangle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: geo.size.width * bufferProgress)

                            // MARK: - Played Progress
                            Rectangle()
                                .fill(
                                    Color("VArtThemeColor")
                                        .opacity(isScrubbing ? 0.5 : 0.8)
                                )
                                .frame(width: geo.size.width * progress)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: barHeight)
                        .clipShape(Capsule())
                        .overlay(alignment: .leading) {
                            if isScrubbing {
                                let thumbX = geo.size.width * CGFloat(scrubPosition / duration)
                                let clampedX = min(max(thumbX, 2), geo.size.width - 2)
                                
                                VStack(spacing: 0) {
                                    Text(formatTime(scrubPosition))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                        .padding(.bottom, 8)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 4, height: 24)
                                        .shadow(color: .black.opacity(0.4), radius: 3)
                                }
                                .fixedSize()
                                .offset(x: clampedX - 52)
                                .offset(y: -30)
                                .animation(.interactiveSpring(), value: scrubPosition)
                            }
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text(formatTime(position))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 55)
            
//            TVGestureView(
//                onSwipeLeft: gestures.onSwipeLeft,
//                onSwipeRight: gestures.onSwipeRight,
//                onSwipeUp: gestures.onSwipeUp,
//                onSwipeDown: gestures.onSwipeDown,
//                onPressLeft: gestures.onPressLeft,
//                onPressRight: gestures.onPressRight,
//                onPressDown: gestures.onPressDown,
//                onPlayPause: gestures.onPlayPause,
//                onTouch: gestures.onTouch,
//                onExit: gestures.onExit
//            ).allowsHitTesting(true)
        }
        
        .focusScope(seekbarNamespace)
//        .onExitCommand {
//            print("avoid exit")
//        }
        
        
        .onChange(of: showSkipIntro) { newValue in
            if newValue {
                // Automatically jump focus to skip button when it appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedElement = .skipButton
                }
            }
        }
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(position / duration)
    }

    private func formatTime(_ time: Double) -> String {
        let total = Int(time)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

struct SkipIntroLabel: View {
    @SwiftUI.Environment(\.isFocused) var isFocused

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "forward.fill")
            Text("Bỏ Qua Giới Thiệu")
                .font(.system(size: 24, weight: .bold))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(isFocused ? Color.white : Color.black.opacity(0.3))
        .foregroundColor(isFocused ? .black : .white)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
