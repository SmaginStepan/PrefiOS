import Foundation

public final class PlayHistory {
    public var discardsByMe: [Card] = []
    public var firstMovesByMe: [Card] = []

    public var discardsByPrev: [Card] = []
    public var firstMovesByPrev: [Card] = []

    public var discardsByNext: [Card] = []
    public var firstMovesByNext: [Card] = []

    private func fill(_ move: Move) {
        if let it = move.myMove {
            if it.coatColor != move.playColor {
                discardsByMe.append(it)
            }
            if move.firstMovePerformer == 0 {
                firstMovesByMe.append(it)
            }
        }
        if let it = move.nextMove {
            if it.coatColor != move.playColor {
                discardsByNext.append(it)
            }
            if move.firstMovePerformer == 1 {
                firstMovesByNext.append(it)
            }
        }
        if let it = move.prevMove {
            if it.coatColor != move.playColor {
                discardsByPrev.append(it)
            }
            if move.firstMovePerformer == -1 {
                firstMovesByPrev.append(it)
            }
        }
    }

    private func fill(_ move: AIInfo.Take) throws {
        let playColor = try move.playColor()
        if let it = move.myMove {
            if it.coatColor != playColor {
                discardsByMe.append(it)
            }
            if move.firstMovePerformer == 0 {
                firstMovesByMe.append(it)
            }
        }
        if let it = move.nextMove {
            if it.coatColor != playColor {
                discardsByNext.append(it)
            }
            if move.firstMovePerformer == 1 {
                firstMovesByNext.append(it)
            }
        }
        if let it = move.prevMove {
            if it.coatColor != playColor {
                discardsByPrev.append(it)
            }
            if move.firstMovePerformer == -1 {
                firstMovesByPrev.append(it)
            }
        }
    }

    public init(_ takes: [AIInfo.Take], _ lastMove: Move) throws {
        for take in takes {
            try fill(take)
        }
        fill(lastMove)
    }

    public init(_ takes: [AIInfo.Take], _ moves: [Move]) throws {
        for take in takes {
            try fill(take)
        }
        for move in moves {
            fill(move)
        }
    }
}
