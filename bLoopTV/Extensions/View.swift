//
//  View.swift
//  VuaPhimBui
//
//  Created by Monster on 7/6/25.
//
import SwiftUI

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    func applyAppBackground() -> some View {
        self.modifier(AppBackground())
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func onFirstAppear(_ perform: @escaping () -> Void) -> some View {
        self.modifier(OnFirstAppearModifier(action: perform))
    }
    
    func onHeightChange(_ onChange: @escaping (CGFloat) -> Void) -> some View {
       background(
           GeometryReader { geo in
               Color.clear
                   .preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
           }
       )
       .onPreferenceChange(ContentHeightPreferenceKey.self, perform: onChange)
   }
    
    func debugPrintChanges(_ name: String) -> some View {
       print("Re-render: \(name)")
       return self
   }
    
    @ViewBuilder
    func ifAvailableIOS26<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 26.0, *) {
            transform(self)
        } else {
            self
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct OnFirstAppearModifier: ViewModifier {
    @State private var didAppear = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !didAppear {
                    didAppear = true
                    action()
                }
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct ScrollOffsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            let offset = geo.frame(in: .global).minY
            Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
        }
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
struct CarouselGeometry: Equatable {
    let offset: CGFloat
    let width: CGFloat
}
struct CarouselGeometryKey: PreferenceKey {
    static var defaultValue: CarouselGeometry = CarouselGeometry(offset: 0, width: 0)

    static func reduce(value: inout CarouselGeometry, nextValue: () -> CarouselGeometry) {
        value = nextValue()
    }
}
