import Foundation

public final class MiserTakes {

    public var takes: [Int: MiserTake] = [:]

    public var firstMoveTakes: Double = 0.0

    public final class MiserTake {
        public var takes: Double = 0.0
        public var risk: Double = 0.0
        public var haveMove: Bool = false

        public init() {}
    }

    public var totalTakes: Double {
        takes.values.reduce(0.0) { $0 + $1.takes } + firstMoveTakes
    }

    public var totalRisk: Double {
        takes.values.reduce(0.0) { $0 + $1.risk }
    }

    public var haveMove: Bool {
        takes.values.filter { $0.haveMove }.count > 0
    }

    private func calc1(_ cards: [Card]) -> MiserTake {
        let opponentTotal = 8 - cards.count
        var v = 7
        var notMyTakes = 0
        var myTakes = 0
        var takes = 0.0
        var opponent = opponentTotal
        var my = cards.count
        var risk = Double(my - 2)
        var haveMove = false
        if risk < 0 {
            risk = 0.0
        }
        while v < 15 {
            if cards.first(where: { $0.value == v }) != nil {
                if myTakes > 0 {
                    myTakes -= 1
                    let opp = opponent + myTakes
                    if v == 8 {
                        takes += 0.5
                        haveMove = true
                        firstMoveTakes = -0.5
                    } else if my == 1 && v == 9 {
                        takes += 1
                        haveMove = true
                        firstMoveTakes = -0.5
                    } else if opp == 0 && opponentTotal == 4 {
                        takes += 0.25
                    } else if opp == 1 && opponentTotal >= 4 {
                        takes += 0.5
                    } else if opp == 0 && opponentTotal == 3 {
                        takes += 0.5
                    } else {
                        takes += 1
                    }
                } else {
                    notMyTakes += 1
                    if v == 8 {
                        haveMove = true
                    }
                }
                my -= 1
            } else {
                if notMyTakes > 0 {
                    notMyTakes -= 1
                } else {
                    myTakes += 1
                }
                opponent -= 1
            }
            v += 1
        }

        let it = MiserTake()
        it.haveMove = haveMove
        it.takes = takes
        it.risk = risk
        return it
    }

    public init(_ ai: AIInfo) {
        firstMoveTakes = 0.0
        for i in 0..<4 {
            var cards: [Card] = ai.myHand.visibleHand!.cardByCoat[i]!
            if !cards.isEmpty {
                let mt = calc1(cards)
                var mt1 = mt
                var mt2: MiserTake
                while mt1.takes >= 0.5 && cards.count > 1 {
                    cards = Array(cards.sorted { $0.value > $1.value }.dropFirst(1))
                    mt2 = calc1(cards)
                    if mt1.takes == mt2.takes {
                        mt.takes += 1
                    }
                    mt1 = mt2
                }
                takes[i] = mt
            } else {
                takes[i] = MiserTake()
            }
        }

        if ai.myFirstMove && !haveMove {
            // Анализ захода
            firstMoveTakes = 0.5
        }
        if !ai.myFirstMove {
            firstMoveTakes = 0.0
        }
    }
}
