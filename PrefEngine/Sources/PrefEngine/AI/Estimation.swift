import Foundation

open class Estimation {
    public var myTakes: Double = 0.0
    public var prevTakes: Double = 0.0
    public var nextTakes: Double = 0.0
    public var turn: Int = 0
    public var contractor: Int? = -1
    public var cardsLeft: Int = 0
    public var trump: Int = -1
    public var move: Move?
    public var playHistory: PlayHistory?

    public init() {}

    open func calcRasklad(_ givenRasklad: Rasklad) throws {
        for color in 0..<4 {
            guard let cr = givenRasklad.byColor[color] else { continue }
            try calcRasklad(cr)
            givenRasklad.probability *= cr.probability
        }
    }

    open func calcRasklad(_ givenRasklad: ColorRasklad) throws {
        throw PrefError("abstract")
    }

    open func calcAllRasklads(_ color: Int, _ rEnumerator: ColorRaskladEnumerator) throws {
        throw PrefError("abstract")
    }

    open func getIntegral() throws -> Double {
        throw PrefError("abstract")
    }

    open func getDebug() -> String? { nil }
}

/// Replacement for the C# `#if DEBUG / Debug.WriteLine` blocks.
public enum AiDebug {
    public static var enabled: Bool = false

    public static func log(_ message: String) {
        if enabled {
            print(message)
        }
    }
}
