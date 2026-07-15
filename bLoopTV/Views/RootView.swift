//
//  RootView.swift
//  bLoopTV
//
//  Created by Monster on 20/1/26.
//

import SwiftUI

struct RootView: View {
    @StateObject var loginViewModel = TVLoginViewModel()
    @State private var showSplash = true

    var body: some View {
        Group {
            if loginViewModel.isLoggedIn {
                ZStack {
                    if loginViewModel.hasFetchedBaseUrl {
                        ContentView()
                    } else {
                        RefetchBaseURLView()
                    }
                    if showSplash {
                        SplashScreenView()
                            .transition(.opacity)
                            .zIndex(1)
                    }
                }
            } else {
                TVLoginView(
                    onLoginSuccess: {
                        showSplash = true
                    }
                )
            }
        }
        .onAppear {
            let tokens = UserDefaults.standard.array(forKey: "plexServerTokens") as? [String]
            
            loginViewModel.isLoggedIn = (tokens != nil && !tokens!.isEmpty)
            
            if loginViewModel.isLoggedIn {
                loginViewModel.fetchServerAccessToken(onlyUpdate: true)
                loginViewModel.fetchClientIdentifier()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showSplash = false
                }
            }
        }
        .environmentObject(loginViewModel)
        
    }
}
