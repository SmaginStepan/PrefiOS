import Foundation

public final class ColorRasklad {

    public func remove(_ move: ColoredMove) {
        remove(move.myMove, move.nextMove, move.prevMove)
    }

    public func remove(_ myCard: Int, _ nextCard: Int, _ prevCard: Int) {
        let move = ColoredMove()
        move.myMove = myCard
        move.nextMove = nextCard
        move.prevMove = prevCard
        if prevHand.contains(prevCard) {
            prevHand.removeValue(prevCard)
        } else {
            move.prevMove = 0
        }
        if myHand.contains(myCard) {
            myHand.removeValue(myCard)
        } else {
            move.myMove = 0
        }
        if nextHand.contains(nextCard) {
            nextHand.removeValue(nextCard)
        } else {
            move.nextMove = 0
        }
        removed.append(move)
    }

    public func popLast() {
        let move = removed.removeLast()
        restoreMove(move)
    }

    private func restoreMove(_ move: ColoredMove) {
        if move.prevMove > 0 && !prevHand.contains(move.prevMove) {
            prevHand.append(move.prevMove)
        }
        if move.myMove > 0 && !myHand.contains(move.myMove) {
            myHand.append(move.myMove)
        }
        if move.nextMove > 0 && !nextHand.contains(move.nextMove) {
            nextHand.append(move.nextMove)
        }
    }

    public func restore() {
        // java.util.ArrayDeque iterates head-first (most recently pushed first).
        for move in removed.reversed() {
            restoreMove(move)
        }
        removed.removeAll()
    }

    private var removed: [ColoredMove] = []

    public var coatColor: Int = 0
    public var prevHand: IntList = IntList()
    public var myHand: IntList = IntList()
    public var nextHand: IntList = IntList()
    public var probability: Double = 0.0

    public init() {}

    public func getRaskladForContractor(_ contractor: Int) throws -> ColorRasklad {
        if contractor == 0 {
            return self
        }
        if contractor == -1 {
            let it = ColorRasklad()
            it.probability = probability
            it.myHand = prevHand
            it.prevHand = nextHand
            it.nextHand = myHand
            return it
        }
        if contractor == 1 {
            let it = ColorRasklad()
            it.probability = probability
            it.myHand = nextHand
            it.prevHand = myHand
            it.nextHand = prevHand
            return it
        }
        throw PrefError("Неправильно задан играющий!")
    }
}
