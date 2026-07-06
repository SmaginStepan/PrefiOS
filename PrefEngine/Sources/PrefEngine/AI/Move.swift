import Foundation

public final class Move {
    public var prevMove: Card?
    public var myMove: Card?
    public var nextMove: Card?

    public var playColor: Int {
        firstMove?.coatColor ?? -1
    }

    public var firstMovePerformer: Int = 0

    public var firstMove: Card? {
        get {
            switch firstMovePerformer {
            case -1: return prevMove
            case 0: return myMove
            case 1: return nextMove
            default: return nil
            }
        }
        set {
            switch firstMovePerformer {
            case -1: prevMove = newValue
            case 0: myMove = newValue
            case 1: nextMove = newValue
            default: break
            }
        }
    }

    public var secondMove: Card? {
        get {
            switch firstMovePerformer {
            case 1: return prevMove
            case -1: return myMove
            case 0: return nextMove
            default: return nil
            }
        }
        set {
            switch firstMovePerformer {
            case 1: prevMove = newValue
            case -1: myMove = newValue
            case 0: nextMove = newValue
            default: break
            }
        }
    }

    public var thirdMove: Card? {
        get {
            switch firstMovePerformer {
            case 0: return prevMove
            case 1: return myMove
            case -1: return nextMove
            default: return nil
            }
        }
        set {
            switch firstMovePerformer {
            case 0: prevMove = newValue
            case 1: myMove = newValue
            case -1: nextMove = newValue
            default: break
            }
        }
    }

    public var estimation: Double = 0.0

    public init() {}

    public func clone() -> Move {
        let it = Move()
        it.firstMovePerformer = firstMovePerformer
        it.prevMove = prevMove
        it.myMove = myMove
        it.nextMove = nextMove
        it.estimation = estimation
        return it
    }

    public func getTaker(_ trump: Int) throws -> Int {
        try Helper.getTaker(myMove, prevMove, nextMove, playColor, trump)
    }

    public func getMaxCard(_ trump: Int) -> Card? {
        Helper.getMaxCard(myMove, prevMove, nextMove, playColor, trump)
    }
}

public final class ColoredMove {
    public var prevMove: Int = 0
    public var myMove: Int = 0
    public var nextMove: Int = 0

    public init() {}
}
