//
//  TVLoginViewModel.swift
//  VuaPhimBui
//
//  Created by Monster on 31/10/25.
//

import Foundation
import XMLCoder
import Combine

class TVLoginViewModel: ObservableObject {
    @Published var pinCode: String = ""
    @Published var pinId: Int?
    @Published var isWaitingForLogin = false
    @Published var isLoggedIn = false
    @Published var authToken: String?
    @Published var hasFetchedBaseUrl: Bool = false

    func startLoginFlow() {
        let url = URL(string: "https://plex.tv/pins.xml")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Environment.clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data else {
                print("No data or error: \(error?.localizedDescription ?? "")")
                return
            }

            do {
                let decoder = XMLDecoder()
                decoder.keyDecodingStrategy = .convertFromCapitalized
                let response = try decoder.decode(PlexPinResponse.self, from: data)
                DispatchQueue.main.async {
                    self.pinCode = response.code
                    self.pinId = response.id
                    self.isWaitingForLogin = true
                    self.pollForAuthToken()
                }
            } catch {
                print("Failed to decode XML: \(error)")
            }
        }.resume()
    }

    private func pollForAuthToken() {
        guard let pinId = pinId else { return }

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
            let url = URL(string: "https://plex.tv/api/v2/pins/\(pinId)")!
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(Environment.clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")

            URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data = data else { return }

                if let updated = try? JSONDecoder().decode(PlexPinResponseAuth.self, from: data),
                   let token = updated.authToken {
                    DispatchQueue.main.async {
                        self.authToken = token
                        // Clear cũ trước khi fetch mới nếu đây là luồng login mới hoàn toàn
                        // PlexAPI.clearServers()
                        self.fetchServerAccessToken()
                        UserDefaults.standard.set(token, forKey: "plexToken")
                        timer.invalidate()
                    }
                }
            }.resume()
        }
    }
    
    func fetchServerAccessToken(onlyUpdate: Bool = false) {
        let token: String
        if onlyUpdate {
            guard let savedToken = UserDefaults.standard.string(forKey: "plexToken") else { return }
            token = savedToken
        } else {
            guard let authToken = self.authToken else { return }
            token = authToken
        }

        let urlString = "\(Environment.clientBaseURL)/resources?includeHttps=1&includeIPv6=1&includeRelay=1&X-Plex-Client-Identifier=\(Environment.clientIdentifier)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data else { return }

            do {
                let devices = try JSONDecoder().decode([PlexDevice].self, from: data)
                
                for device in devices {
                    let isServer = device.provides.contains("server")
                    let isOnline = device.presence == true
                    
                    guard isServer && isOnline, let serverToken = device.accessToken else { continue }
                    
                    for connection in device.connections {
                        let isNotLocal = connection.local == false
                        let isNotIpv6 = connection.ipv6 == false
                        let isNotDomain = connection.addressType != .domain
                        
                        if isNotLocal && isNotIpv6 && isNotDomain {
                            let baseUrl = connection.uri
                            
                            PlexAPI.appendServer(token: serverToken, baseUrl: baseUrl, name: device.name)
                            
                            DispatchQueue.main.async {
                                self.hasFetchedBaseUrl = true
                                if !onlyUpdate {
                                    self.isLoggedIn = true
                                    self.isWaitingForLogin = false
                                }
                            }
                            // Nếu chỉ muốn lấy server đầu tiên của mỗi device thì break ở đây
                            break
                        }
                    }
                }
            } catch {
                print("Error decoding resources: \(error)")
            }
        }.resume()
    }
    
    func fetchClientIdentifier() -> String {
        let key = "plexClientIdentifier"
        
        // 1. Kiểm tra xem đã có ID lưu trong máy chưa
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        } else {
            // 2. Nếu chưa có, tạo một UUID mới (duy nhất cho thiết bị này)
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
    }
}

struct PlexPinResponseAuth: Decodable {
    let authToken: String?
}
