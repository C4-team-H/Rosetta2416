import CoreML
import Foundation

@MainActor
final class CoreMLLabelCatalog {
    let availableLabels: Set<String>

    init(availableLabels: Set<String>? = nil) {
        if let availableLabels {
            self.availableLabels = Set(availableLabels.map(Self.normalize))
            return
        }

        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuOnly
            let model = try SketchClassifierV3(configuration: configuration)
            self.availableLabels = Set(
                (model.model.modelDescription.classLabels ?? [])
                    .compactMap { $0 as? String }
                    .map(Self.normalize)
            )
        } catch {
            assertionFailure("Unable to load SketchClassifierV3 labels: \(error)")
            self.availableLabels = Set(Self.categoryLabels.values.flatMap { $0 })
        }
    }

    func labels(in category: DrawingCategory) -> [String] {
        (Self.categoryLabels[category] ?? [])
            .filter(availableLabels.contains)
            .sorted()
    }

    func contains(_ label: String, in category: DrawingCategory) -> Bool {
        labels(in: category).contains(Self.normalize(label))
    }

    func category(of label: String) -> DrawingCategory? {
        let label = Self.normalize(label)
        return DrawingCategory.allCases.first { Self.categoryLabels[$0]?.contains(label) == true }
    }

    nonisolated static let categoryLabels: [DrawingCategory: Set<String>] = [
        .animal: Set([
            "ant", "bee", "butterfly", "camel", "cat", "crab", "crocodile", "feather",
            "fish", "frog", "giraffe", "hedgehog", "kangaroo", "lobster", "mouse",
            "octopus", "owl", "penguin", "pig", "rabbit", "rooster", "sea turtle",
            "sheep", "snail", "snake", "spider", "swan", "tiger", "zebra"
        ]),
        .plant: Set(["cactus", "flower with stem", "leaf", "palm tree", "potted plant", "tree"]),
        .human: Set([
            "brain", "crown", "ear", "eye", "eyeglasses", "face", "foot", "hand", "hat",
            "helmet", "human-skeleton", "mouth", "nose", "pant", "person sitting",
            "person walking", "shoe", "skull", "socks", "suitcase", "t-shirt", "tooth",
            "wrist-watch"
        ]),
        .landscape: Set([
            "castle", "cloud", "fire hydrant", "house", "rainbow", "skyscraper",
            "streetlight", "tent", "traffic light", "windmill"
        ]),
        .transportation: Set([
            "bicycle", "helicopter", "kayak", "rollerblades", "sedan", "ship",
            "skateboard", "rocket", "train"
        ]),
        .otherObject: Set(["diamond", "envelope", "gift", "parachute", "teddy bear"]),
        .tool: Set([
            "axe", "calculator", "comb", "computer mouse", "fork", "frying-pan", "hammer",
            "key", "knife", "ladder", "paper clip", "pen", "power outlet", "scissors",
            "screwdriver", "spoon", "stapler", "teapot", "toothbrush", "wheel", "wineglass"
        ]),
        .equipment: Set([
            "backpack", "binoculars", "book", "bowl", "flashlight", "hourglass", "microscope",
            "mug", "syringe"
        ]),
        .furniture: Set([
            "bed", "bell", "cabinet", "candle", "chair", "chandelier", "closet", "door", "fan",
            "guitar", "lightbulb", "table", "tennis racket", "umbrella"
        ]),
        .electronics: Set([
            "alarm clock", "camera", "computer monitor", "head-phones", "laptop", "microphone",
            "radio", "satellite"
        ]),
        .weapon: Set(["cannon"]),
        .celestial: Set(["moon", "sun", "ufo"]),
        .food: Set([
            "apple", "banana", "grapes", "pear", "pineapple", "pumpkin", "strawberry", "tomato",
            "bread", "cake", "carrot", "cone ice cream", "donut", "hamburger", "hot-dog",
            "mushroom", "pizza", "pretzel"
        ])
    ]

    private static func normalize(_ label: String) -> String {
        label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
