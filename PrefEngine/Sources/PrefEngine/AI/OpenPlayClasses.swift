import Foundation

public final class Taken {
    public var prevTakes: Double = 0.0
    public var myTakes: Double = 0.0
    public var nextTakes: Double = 0.0

    public init() {}

    public func take(_ taker: Int) -> Taken {
        let res = Taken()
        res.prevTakes = prevTakes
        res.nextTakes = nextTakes
        res.myTakes = myTakes
        switch taker {
        case 0: res.myTakes += 1
        case 1: res.nextTakes += 1
        case -1: res.prevTakes += 1
        default: break
        }
        return res
    }

    public func addTake(_ taker: Int) throws {
        switch taker {
        case 0: myTakes += 1
        case 1: nextTakes += 1
        case -1: prevTakes += 1
        default: throw PrefError("Неверно задан берущий")
        }
    }

    public func removeTake(_ taker: Int) throws {
        switch taker {
        case 0: myTakes -= 1
        case 1: nextTakes -= 1
        case -1: prevTakes -= 1
        default: throw PrefError("Неверно задан берущий")
        }
    }
}

public final class Extremums {
    public var firstMaximizing: Bool = false
    public var secondMaximizing: Bool = false
    public var thirdMaximizing: Bool = false

    public init() {}
}

public final class PotentialDiscard: Codable {
    public var firstCard: Card?
    public var secondCard: Card?
    public var probability: Double = 0.0
    public var hash: String?

    public init() {}
}

public final class EstimationWithCard {
    public var estimation: Double = 0.0
    public var bestCard: Card?

    public init() {}
}
