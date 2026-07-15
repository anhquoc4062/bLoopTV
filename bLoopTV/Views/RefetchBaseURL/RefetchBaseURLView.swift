//
//  RefetchBaseURLView.swift
//  VuaPhimBui
//
//  Created by Monster on 17/11/25.
//

import SwiftUI

struct RefetchBaseURLView: View {
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())

                Text("Đang tải chờ xíu")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                ContentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor"))
        .onAppear {
            refetchBaseURL()
        }
    }

    private func refetchBaseURL() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
        }
    }
}
