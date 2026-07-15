//
//  SlashScreenView.swift
//  VuaPhimBui
//
//  Created by Monster on 21/6/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var moveV = false
    @State private var showArt = false
    @State private var zoomAndFade = false
    @State private var shouldShowSlogan = false
    @State private var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    @State private var buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

    var body: some View {
        ZStack {
            Color("SplashScreenBackground")
                .ignoresSafeArea()

            VStack {
                
                Spacer()
                ZStack {
                    VStack(spacing: 12) {
                        Image("bLoopIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                        
                        if shouldShowSlogan {
                            Text("Ngôi Nhà Chung Của Quanh và Quắc")
                                .font(.custom("Caveat-VariableFont_wght", size: 15))
                                .foregroundColor(Color("BackgroundColor"))
                                .bold()
                        }
                    }
                }
                .scaleEffect(zoomAndFade ? 5.0 : 1.0)
                .opacity(zoomAndFade ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 1.2), value: zoomAndFade)
                
                Spacer()
                
                Text("v\(appVersion) (\(buildNumber))")
                    .foregroundColor(Color("BackgroundColor"))
                    .bold()
            }
            
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                moveV = true
                showArt = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    zoomAndFade = true
                }
            }
            
            if let userCached = loadUserDataFromDefaults() {
                if userCached.username == "anhquoc3524" || userCached.username == "OanhsQ" {
                    shouldShowSlogan = true
                }
            }
        }
    }
    
    func loadUserDataFromDefaults() -> PlexUserData? {
        guard let data = UserDefaults.standard.data(forKey: "userData") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(PlexUserData.self, from: data)
        } catch {
            print("❌ Failed to decode user data: \(error)")
            return nil
        }
    }
}
