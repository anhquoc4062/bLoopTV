//
//  Date.swift
//  VuaPhimBui
//
//  Created by Monster on 18/8/25.
//
import SwiftUI

extension Date {
    func toDMYString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M/yyyy"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: self)
    }
}
