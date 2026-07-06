import Foundation

public final class MiserAntiEstimation: Estimation {

    private let internalEst: MiserEstimation = {
        let it = MiserEstimation()
        it.isHidden = false
        return it
    }()

    public var iamSure: Bool = true

    public override init() {
        super.init()
    }

    private func fillData() {
        switch contractor {
        case 0:
            internalEst.myTakes = myTakes
            internalEst.prevTakes = prevTakes
            internalEst.nextTakes = nextTakes

            internalEst.turn = turn
        case -1:
            internalEst.prevTakes = nextTakes
            internalEst.myTakes = prevTakes
            internalEst.nextTakes = myTakes

            internalEst.turn = turn + 1
            if internalEst.turn > 1 {
                internalEst.turn = -1
            }
        case 1:
            internalEst.myTakes = nextTakes
            internalEst.prevTakes = myTakes
            internalEst.nextTakes = prevTakes

            internalEst.turn = turn - 1
            if internalEst.turn < -1 {
                internalEst.turn = 1
            }
        default:
            break
        }
        if internalEst.myTakes > 0 {
            internalEst.iamSure = iamSure
        }
        internalEst.move = move
        internalEst.playHistory = playHistory
        internalEst.contractor = contractor
        internalEst.cardsLeft = cardsLeft
        internalEst.trump = trump
        internalEst.iamSure = iamSure
    }

    public override func calcRasklad(_ givenRasklad: ColorRasklad) throws {
        fillData()
        try internalEst.calcRasklad(givenRasklad)
    }

    public override func calcAllRasklads(_ color: Int, _ rEnumerator: ColorRaskladEnumerator) throws {
        fillData()
        try internalEst.calcAllRasklads(color, rEnumerator)
    }

    public override func getIntegral() throws -> Double {
        fillData()
        return try -internalEst.getIntegral()
    }

    public override func getDebug() -> String? {
        var res = ""

        var totalRisk = 0.0
        var totalIntercepts = 0.0
        var totalExit = 0.0
        var totalTakes = 0.0
        var totalNextToPrev = 0.0
        var totalPrevToNext = 0.0
        var nextTakesSum = 0.0
        var prevTakesSum = 0.0
        var totalNextDiscards = 0.0
        var totalPrevDiscards = 0.0

        for color in 0..<4 {
            guard let cnts = internalEst.colors[color] else { continue }
            res += "\(color):\n"
            res += "Exits: \(cnts.exit) \(cnts.exit2) \(cnts.exit3) \(cnts.exit4) intercepts=\(cnts.intercept) risk=\(cnts.risk) \r\n"
            res += "Takes: \(cnts.take) \(cnts.take2) \(cnts.take3) \(cnts.take4) = \(cnts.takes)\r\n"
            res += "Prev: to next=\(cnts.prevToNext)  needed=\(cnts.prevNeedToBeDiscarded)  can=\(cnts.prevCanBeDiscarded)  discards=\(cnts.prevDiscards)  takes=\(cnts.prevTakes)\r\n"
            res += "Next: to prev=\(cnts.nextToPrev)  needed=\(cnts.nextNeedToBeDiscarded)  can=\(cnts.nextCanBeDiscarded)  discards=\(cnts.nextDiscards)  takes=\(cnts.nextTakes)\r\n"
            res += "Scissor: \(cnts.scissorsTakes) \(cnts.scissorsPrevDiscards) \r\n"

            totalNextToPrev += cnts.nextToPrev
            totalPrevToNext += cnts.prevToNext

            totalRisk += cnts.risk
            totalIntercepts += cnts.intercept
            totalExit += cnts.exit + 0.75 * cnts.exit2 + 0.25 * cnts.exit3 + 0.1 * cnts.exit4
            totalTakes += cnts.take + cnts.take2 + cnts.take3 + cnts.take4
            totalNextDiscards += cnts.nextDiscards
            totalPrevDiscards += cnts.prevDiscards

            nextTakesSum += cnts.nextTakes
            prevTakesSum += cnts.prevTakes
        }
        res += "\n"
        res += "Alredy: prev=\(prevTakes)  next=\(nextTakes)  my=\(myTakes)  turn=\(turn)  contractor=\(contractor.map(String.init) ?? "nil")"
        res += "\n"
        res += "NextToPrev=\(totalNextToPrev)  PrevToNext=\(totalPrevToNext)  Takes=\(totalTakes)  NextDiscards=\(totalNextDiscards)  PrevDiscards=\(totalPrevDiscards)"
        return res
    }
}
