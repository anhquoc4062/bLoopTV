//
//  TVLoginView.swift
//  VuaPhimBui
//
//  Created by Monster on 31/10/25.
//
import SwiftUI

struct TVLoginView: View {
    @EnvironmentObject private var viewModel: TVLoginViewModel
    var onLoginSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoggedIn {
                Text("✅ Đăng nhập thành công!")
                    .foregroundColor(.green)
            } else if viewModel.isWaitingForLogin {
                VStack(spacing: 10) {
                    Text("Vui lòng truy cập:")
                        .font(.headline)
                    Text("https://plex.tv/link")
                        .foregroundColor(.blue)
                    Text("và nhập mã PIN sau:")
                        .font(.subheadline)
                    Text(viewModel.pinCode)
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    ProgressView("Chờ xác thực...")
                }
            } else {
                Button("Đăng nhập bằng Plex") {
                    viewModel.startLoginFlow()
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onChange(of: viewModel.isLoggedIn) { newValue in
            if newValue {
                onLoginSuccess()
            }
        }
    }
}

#Preview {
    // LoginView()
}
