//
//  StremioLoginView.swift
//  bLoopTV
//

import SwiftUI

struct StremioLoginView: View {
    @EnvironmentObject var navPathManager: NavigationPathManager

    @State private var email: String = StremioAccountAPI.shared.accountEmail ?? ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loggedInEmail: String? = StremioAccountAPI.shared.authKey != nil ? StremioAccountAPI.shared.accountEmail : nil

    var body: some View {
        VStack(spacing: 30) {
            Text("Đăng nhập Stremio")
                .font(.title2)
                .bold()

            if let loggedInEmail {
                Text("Đã đăng nhập: \(loggedInEmail)")
                    .foregroundColor(.secondary)

                Button("Xem Catalog") {
                    navPathManager.push(.stremioAccountHome)
                }
                .buttonStyle(.card)

                Button("Đăng xuất") {
                    StremioAccountAPI.shared.logout()
                    self.loggedInEmail = nil
                    email = ""
                    password = ""
                }
                .buttonStyle(.card)
            } else {
                TextField("Email", text: $email)
                    .frame(maxWidth: 500)

                SecureField("Mật khẩu", text: $password)
                    .frame(maxWidth: 500)

                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Button("Đăng nhập") {
                    login()
                }
                .buttonStyle(.card)
                .disabled(isLoading)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.all)
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Vui lòng nhập email và mật khẩu"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                print("[Stremio] Đang đăng nhập với email \(email)")
                _ = try await StremioAccountAPI.shared.login(email: email, password: password)
                print("[Stremio] Đăng nhập thành công")

                await MainActor.run {
                    isLoading = false
                    password = ""
                    loggedInEmail = StremioAccountAPI.shared.accountEmail
                    navPathManager.push(.stremioAccountHome)
                }
            } catch {
                print("[Stremio] Lỗi đăng nhập: \(error)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
