//
//  ContentProvider.swift
//  bloopTVTopShelf
//
//  Created by Monster on 14/7/26.
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let items = ContinueWatchingSync.read()
        guard !items.isEmpty else { return nil }

        let shelfItems: [TVTopShelfSectionedItem] = items.compactMap { item in
            guard let deepLinkURL = URL(string: item.deepLinkURLString) else { return nil }

            let shelfItem = TVTopShelfSectionedItem(identifier: item.id)
            shelfItem.title = item.title
            if let posterURLString = item.posterURLString, let posterURL = URL(string: posterURLString) {
                shelfItem.setImageURL(posterURL, for: .screenScale1x)
                shelfItem.setImageURL(posterURL, for: .screenScale2x)
            }
            shelfItem.imageShape = .poster
            shelfItem.playAction = TVTopShelfAction(url: deepLinkURL)
            shelfItem.displayAction = TVTopShelfAction(url: deepLinkURL)
            return shelfItem
        }

        guard !shelfItems.isEmpty else { return nil }

        let section = TVTopShelfItemCollection(items: shelfItems)
        section.title = "Xem Tiếp"

        return TVTopShelfSectionedContent(sections: [section])
    }

}
