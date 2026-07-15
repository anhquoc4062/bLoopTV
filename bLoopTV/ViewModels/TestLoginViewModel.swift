//
//  TestLoginViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 30/6/25.
//
//
//import Foundation
//import Combine
//
//class TestLoginViewModel: ObservableObject {
//    @Published var authToken: String?
//    @Published var loginURL: IdentifiableURL?
//    @Published var isLoggedIn = false
//
//    private var pinID: Int?
//    private var timer: Timer?
//    
//    private let clientID = "com.example.myapp"
//
//    func startLogin() {
//        let url = URL(string: "https://plex.tv/api/v2/pins?strong=true")!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
//        request.setValue("MyApp", forHTTPHeaderField: "X-Plex-Product")
//        request.setValue("1.0", forHTTPHeaderField: "X-Plex-Version")
//        request.setValue("application/json", forHTTPHeaderField: "Accept")
//
//        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
//            guard let data = data,
//                  let pin = try? JSONDecoder().decode(PlexPin.self, from: data) else {
//                return
//            }
//
//            DispatchQueue.main.async {
//                self?.pinID = pin.id
//                self?.loginURL = URL(string: "https://app.plex.tv/auth#?clientID=\(self?.clientID ?? "")&code=\(pin.code)")
//                if let url = URL(string: "https://plex.tv/link") {
//                        loginURL = IdentifiableURL(url: url)
//                    }
//                self?.startPolling()
//            }
//        }.resume()
//    }
//
//    private func startPolling() {
//        guard let pinID = pinID else { return }
//
//        timer?.invalidate()
//        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            let pollURL = URL(string: "https://plex.tv/api/v2/pins/\(pinID)")!
//            var request = URLRequest(url: pollURL)
//            request.setValue(self.clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
//            request.setValue("application/json", forHTTPHeaderField: "Accept")
//
//            URLSession.shared.dataTask(with: request) { data, _, _ in
//                guard let data = data,
//                      let result = try? JSONDecoder().decode(PlexPollResult.self, from: data),
//                      let token = result.authToken else {
//                    return
//                }
//
//                DispatchQueue.main.async {
//                    self.authToken = token
//                    self.loginURL = nil
//                    self.timer?.invalidate()
//                }
//            }.resume()
//        }
//    }
//}
//
//// MARK: - Plex Models
//struct IdentifiableURL: Identifiable {
//    let id = UUID()
//    let url: URL
//}
//
//struct PlexPin: Decodable {
//    let id: Int
//    let code: String
//    let expiresIn: Int
//}
//
//struct PlexPollResult: Decodable {
//    let authToken: String?
//}
