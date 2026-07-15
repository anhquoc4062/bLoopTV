//
//  String.swift
//  VuaPhimBui
//
//  Created by Monster on 6/6/25.
//
import SwiftUI

extension String {
    func urlEncoded() -> String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
    
    func htmlToAttributedString() -> AttributedString? {
        let htmlStart = """
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            body { font-family: -apple-system; font-size: 16px; color: white; }
        </style>
        </head>
        <body>
        """
        let htmlEnd = "</body></html>"
        let wrapped = htmlStart + self + htmlEnd

        guard let data = wrapped.data(using: .utf8) else { return nil }

        if let nsAttrStr = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return AttributedString(nsAttrStr)
        }
        return nil
    }
    
    func removeHTMLTag() -> String {
        return self.replacingOccurrences(of: "<[^>]+>",
                                         with: "",
                                         options: .regularExpression,
                                         range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Optional where Wrapped == String {
    func isEastAsianLang() -> Bool {
        guard let lower = self?.lowercased() else { return false }
        return ["zh", "jp", "ko"].contains(lower)
    }
}
