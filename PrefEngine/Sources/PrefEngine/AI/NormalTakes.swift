import Foundation

public final class NormalTakes {

    public final class ColorCalc {
        public var turns: Double = 0.0
        public var takes: Double = 0.0

        public init() {}
    }

    public final class PotentialContract {
        public var maxContract: Int = 0
        public var takes: Double = 0.0
        public var turns: Double = 0.0

        public init() {}
    }

    public var takes: [Int: ColorCalc] = [:]

    public func prikupPedict(_ takesIn: Double, _ hand: Hand, _ nonTrump: Bool) -> Int {
        var takes = takesIn
        // Эвристики оценки прикупа
        if !nonTrump {
            // Оценивается не бескозырка
            var cntAces = 0
            var cntLong = 0
            for color in 0..<4 {
                guard let cards = hand.cardByCoat[color] else { continue }
                if cards.first(where: { $0.value == 14 }) != nil {
                    cntAces += 1
                }
                if cards.count >= 3 {
                    cntLong += 1
                }
            }
            if cntLong >= 3 {
                takes += 0.5 // Добавляем за 3 длинные масти
            }
            if cntAces >= 3 {
                takes += 0.5 // Добавляем за 3х тузов
            }
        }
        if takes < 4.5 {
            return 0
        }
        if takes < 6 {
            return 6
        }
        if takes < 7 {
            return 7
        }
        return Int(takes.rounded(.down))
    }

    public func getMaxContract(_ trump: Int, _ hand: Hand, _ myFirstTurn: Bool, _ countAdditional: Bool) -> PotentialContract {
        let minTakes = takes.values.map { $0.takes }.min()!
        let maxTurns = takes.values.map { $0.turns }.max()!
        var takesSum = takes.values.reduce(0.0) { $0 + $1.takes }
        if trump < 0 || trump > 3 {
            // Бескозырка
            if minTakes > 0 && maxTurns < 2 {
                let it = PotentialContract()
                it.takes = takesSum
                it.turns = 0.0
                it.maxContract = prikupPedict(takesSum, hand, true)
                return it
            }
            let it = PotentialContract()
            it.takes = 0.0
            it.turns = 0.0
            it.maxContract = 0
            return it
        }
        var neededTurns = takes.filter { $0.key != trump }.values.reduce(0.0) { $0 + $1.turns }

        var cards = hand.cardByCoat[trump]!
        var havingTurns = Double(cards.count)
        var v = 14
        while cards.first(where: { $0.value == v }) == nil && v > 6 {
            v -= 1
            if havingTurns > 0 {
                havingTurns -= 1
            }
        }
        havingTurns += minTakes

        if myFirstTurn {
            havingTurns += 1
        }

        while havingTurns < neededTurns {
            takesSum -= 1.5
            neededTurns -= 1
        }

        if !myFirstTurn {
            // Заложиться на розыгрыш неиграющего козыря
            for color in 0..<4 {
                if trump == color || cards.count <= 1 {
                    continue
                }
                var notMyCards = 0
                cards = hand.cardByCoat[color]!
                v = 14
                while v > 6 && cards.first(where: { $0.value == v }) == nil {
                    notMyCards += 1
                    v -= 1
                }
                let take = takes[color]!
                if take.takes > 0 && take.takes == Double(cards.count - notMyCards) {
                    takesSum -= 0.5
                    break
                }
            }
        }
        if countAdditional {
            // Прибавить копеечку за каждую длинную масть, второго короля и третью даму... нужно для определения лучшего сброса.
            for color in 0..<4 {
                cards = hand.cardByCoat[color]!
                if cards.count >= 3 {
                    takesSum += 0.001 // Длинная масть
                }

                if cards.count == 3 && takes[color]!.takes == 0.0 && cards.first(where: { $0.value == 12 }) != nil {
                    // Третья дама
                    takesSum += 0.001
                }
                if cards.count == 2 && takes[color]!.takes == 0.0 && cards.first(where: { $0.value == 13 }) != nil {
                    // Второй король
                    takesSum += 0.0005
                }
            }
        } else {
            // Если у нас нет длинного козыря - это плохо!
            if hand.cardByCoat[trump]!.count < 4 {
                takesSum -= Double(4 - hand.cardByCoat[trump]!.count) * 0.5
            }
        }
        let it = PotentialContract()
        it.takes = takesSum
        it.turns = havingTurns - neededTurns
        it.maxContract = prikupPedict(takesSum, hand, false)
        return it
    }

    private func calc1(_ calc: ColorCalc, _ opponentStart: Int, _ cards: [Card]) {
        var opponent = opponentStart
        var notMy = 0
        var v = 14
        calc.takes = 0.0
        calc.turns = 0.0
        var turns = 0
        while v > 6 {
            if cards.first(where: { $0.value == v }) != nil {
                // Карта есть
                notMy -= 1
                if notMy < 0 {
                    notMy = 0
                    calc.takes += 1
                    calc.turns += Double(turns)
                    turns = 0
                    opponent -= 1
                }
            } else {
                if opponent > 0 {
                    // Карты нет, но есть у оппонента
                    notMy += 1
                    turns += 1
                    opponent -= 1
                }
            }
            v -= 1
        }
    }

    public init(_ ai: AIInfo) {
        for i in 0..<4 {
            let cards = ai.myHand.visibleHand!.cardByCoat[i]!
            var opponent = 8 - cards.count
            if opponent == 4 {
                opponent = 3 // Не закладываемся на 4 карты на одной руке
            }
            let calc = ColorCalc()
            calc1(calc, opponent, cards)
            if opponent == 3 {
                let calc2 = ColorCalc()
                calc1(calc2, 2, cards)
                calc.turns += (calc2.turns - calc.turns) / 2
                calc.takes += (calc2.takes - calc.takes) / 2
            }

            takes[i] = calc
        }
    }
}
