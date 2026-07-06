import SwiftUI
import PrefEngine

/// Loads and caches card sprites from the bundled cards folder.
final class CardImages {
    private var cache: [String: UIImage] = [:]

    private func load(_ name: String) -> UIImage {
        if let img = cache[name] {
            return img
        }
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "cards")
        let img = url.flatMap { UIImage(contentsOfFile: $0.path) } ?? UIImage()
        cache[name] = img
        return img
    }

    func get(_ card: Card?) -> UIImage {
        let cid: String
        if let card = card {
            let suits = ["s", "c", "d", "h"]
            cid = "\(card.value)\(suits[card.coatColor])"
        } else {
            cid = "0"
        }
        return load(cid)
    }

    func background() -> UIImage {
        load("greencloth")
    }
}
