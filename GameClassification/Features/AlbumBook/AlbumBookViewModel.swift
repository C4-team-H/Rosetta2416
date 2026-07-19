import Foundation
import Observation

@MainActor
@Observable
final class AlbumBookViewModel {
    nonisolated static let allLabels: [String] = [
        "alarm clock", "angel", "ant", "apple", "axe",
        "backpack", "banana", "bed", "bee", "bell", "bicycle", "binoculars", "book",
        "bowl", "brain", "bread", "butterfly",
        "cabinet", "cactus", "cake", "calculator", "camel", "camera", "candle",
        "cannon", "carrot", "castle", "cat", "chair", "chandelier", "closet",
        "cloud", "comb", "computer monitor", "computer mouse", "cone ice cream",
        "crab", "crocodile", "crown", "diamond", "donut", "door", "ear", "envelope",
        "eye", "eyeglasses", "face", "fan", "feather", "fire hydrant", "fish", "flashlight",
        "flower with stem", "foot", "fork", "frog", "frying-pan", "gift", "giraffe", "grapes",
        "guitar", "hamburger", "hammer", "hand", "hat", "head-phones", "hedgehog",
        "helicopter", "helmet", "hot-dog", "hourglass", "house", "human-skeleton", "kangaroo",
        "kayak", "key", "knife", "ladder", "laptop", "leaf", "lightbulb", "lobster",
        "microphone", "microscope", "moon", "mouse", "mouth", "mug", "mushroom", "nose",
        "octopus", "owl", "palm tree", "pant", "paper clip", "parachute", "pear", "pen",
        "penguin", "person sitting", "person walking", "pig", "pineapple", "pizza", "potted plant",
        "power outlet", "pretzel", "pumpkin", "rabbit", "radio", "rainbow", "rocket",
        "rollerblades", "rooster", "satellite", "scissors", "screwdriver", "sea turtle", "sedan",
        "sheep", "ship", "shoe", "skateboard", "skull", "skyscraper", "snail", "snake", "socks",
        "spider", "spoon", "stapler", "strawberry", "streetlight", "suitcase", "sun", "swan",
        "syringe", "t-shirt", "table", "teapot", "teddy bear", "tennis racket", "tent", "tiger",
        "tomato", "tooth", "toothbrush", "traffic light", "train", "tree", "ufo", "umbrella",
        "wheel", "windmill", "wineglass", "wrist-watch", "zebra"
    ]

    var selectedLabel: String
    var searchText = ""

    init(selectedLabel: String = allLabels[0]) {
        self.selectedLabel = selectedLabel
    }

    var filteredLabels: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.allLabels }
        return Self.allLabels.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}
