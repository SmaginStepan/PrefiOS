import Foundation

public final class MiserEstimation: Estimation {

    public final class Color {
        public var risk: Double = 0.0
        public var exit: Double = 0.0
        public var exit2: Double = 0.0
        public var exit3: Double = 0.0
        public var exit4: Double = 0.0
        public var intercept: Double = 0.0
        public var take: Double = 0.0
        public var take2: Double = 0.0
        public var take3: Double = 0.0
        public var take4: Double = 0.0
        public var takes: Double {
            take + take2 + take3 + take4
        }

        public var prevDiscards: Double = 0.0
        public var nextDiscards: Double = 0.0

        public var prevNeedToBeDiscarded: Double = 0.0
        public var nextNeedToBeDiscarded: Double = 0.0

        public var prevCanBeDiscarded: Double = 0.0
        public var nextCanBeDiscarded: Double = 0.0

        public var scissorsTakes: Double = 0.0
        public var scissorsPrevDiscards: Double = 0.0

        public var prevTakes: Double = 0.0
        public var nextTakes: Double = 0.0
        public var prevToNext: Double = 0.0
        public var nextToPrev: Double = 0.0

        public init() {}
    }

    public var colors: [Int: Color] = [:]

    public var isHidden: Bool = false

    public var iamSure: Bool = true

    public override init() {
        super.init()
        for i in 0..<4 {
            colors[i] = Color()
        }
    }

    public override func calcRasklad(_ givenRasklad: ColorRasklad) throws {
        let cnts = Color()
        try forRasklad(cnts, givenRasklad)
        colors[givenRasklad.coatColor] = cnts
    }

    public override func calcAllRasklads(_ color: Int, _ rEnumerator: ColorRaskladEnumerator) throws {
        let cnts = Color()

        var rasklad = rEnumerator.getNext()
        var rCnt = 0.0
        while rasklad != nil {
            try forRasklad(cnts, rasklad!)
            rCnt += rasklad!.probability
            rasklad = rEnumerator.getNext()
        }
        cnts.risk /= rCnt
        cnts.exit /= rCnt
        cnts.exit2 /= rCnt
        cnts.exit3 /= rCnt
        cnts.exit4 /= rCnt
        cnts.intercept /= rCnt
        cnts.take /= rCnt
        cnts.take2 /= rCnt
        cnts.take3 /= rCnt
        cnts.take4 /= rCnt

        cnts.prevTakes /= rCnt
        cnts.nextTakes /= rCnt
        cnts.nextToPrev /= rCnt
        // NOTE: preserved from the original C# (prevToNext was assigned from nextToPrev)
        cnts.prevToNext = cnts.nextToPrev / rCnt

        cnts.nextDiscards /= rCnt
        cnts.prevDiscards /= rCnt
        cnts.nextNeedToBeDiscarded /= rCnt
        cnts.prevNeedToBeDiscarded /= rCnt

        cnts.scissorsPrevDiscards /= rCnt
        cnts.scissorsTakes /= rCnt
        cnts.nextNeedToBeDiscarded /= rCnt
        cnts.nextCanBeDiscarded /= rCnt
        cnts.prevNeedToBeDiscarded /= rCnt
        cnts.prevCanBeDiscarded /= rCnt

        colors[color] = cnts
    }

    private func forRasklad(_ cnts: Color, _ iRasklad: ColorRasklad) throws {
        guard let contractorValue = contractor else {
            throw PrefError("Не задан играющий!")
        }
        let rasklad = contractorValue == 0 ? iRasklad : try iRasklad.getRaskladForContractor(contractorValue)

        if !isHidden {
            rasklad.probability = 1.0
        }

        // Длина возможного "паровозика"
        if rasklad.nextHand.count >= rasklad.prevHand.count {
            if rasklad.myHand.count >= rasklad.nextHand.count {
                cnts.risk += Double(rasklad.myHand.count - rasklad.nextHand.count + 1)
            }
        } else {
            if rasklad.myHand.count >= rasklad.prevHand.count {
                cnts.risk += Double(rasklad.myHand.count - rasklad.prevHand.count + 1)
            }
        }

        if rasklad.myHand.count >= 2 && (rasklad.nextHand.count >= 2 || rasklad.prevHand.count >= 2) {
            // Есть ли перехват (можно гарантированно взять а затем гарантированно отдаться)
            let myMin1 = rasklad.myHand.isEmpty ? 0 : rasklad.myHand[0]
            let myMax = rasklad.myHand.last!
            let nextMax = rasklad.nextHand.isEmpty ? 0 : rasklad.nextHand.last!
            let prevMax = rasklad.prevHand.isEmpty ? 0 : rasklad.prevHand.last!
            var intercept = 0
            var nextIntercept = 0
            var prevIntercept = 0

            if nextMax < myMax && prevMax < myMax {
                intercept = 1
            }
            if nextMax < myMax {
                nextIntercept = 1
            }
            if prevMax < myMax {
                prevIntercept = 1
            }

            if intercept > 0 || nextIntercept > 0 || prevIntercept > 0 {
                let nextMin1 = rasklad.nextHand.count <= 1 ? 0 : rasklad.nextHand[0]
                // NOTE: preserved from the original C# (prevMin1 also read from nextHand)
                let prevMin1 = rasklad.nextHand.count <= 1 ? 0 : rasklad.nextHand[0]
                if intercept > 0 && (nextMin1 > myMin1 || prevMin1 > myMin1) {
                    cnts.intercept = rasklad.probability
                }
            }
        }

        // Считаем взятки и отцепки
        let subEst = MiserSubEstimation(rasklad)
        subEst.calcColor(cnts)

        // Считаем возможность передать заход
        if rasklad.nextHand.count >= 2 && rasklad.prevHand.count >= 2 && rasklad.myHand.count >= 2 {
            let next = rasklad.nextHand[1]
            let prev = rasklad.prevHand[1]
            if next > prev {
                cnts.prevToNext += rasklad.probability
            } else {
                cnts.nextToPrev += rasklad.probability
            }
        } else if !rasklad.nextHand.isEmpty && !rasklad.prevHand.isEmpty && !rasklad.myHand.isEmpty {
            let next = rasklad.nextHand[0]
            let prev = rasklad.prevHand[0]
            if next > prev {
                cnts.prevToNext += rasklad.probability
            } else {
                cnts.nextToPrev += rasklad.probability
            }
        }

        if !isHidden {
            // Возможность проноса
            cnts.nextDiscards = Double(Swift.min(rasklad.prevHand.count, rasklad.myHand.count) - rasklad.nextHand.count)
            cnts.prevDiscards = Double(Swift.min(rasklad.nextHand.count, rasklad.myHand.count) - rasklad.prevHand.count)

            if cnts.nextDiscards < 0 {
                cnts.nextDiscards = 0.0
            }
            if cnts.prevDiscards < 0 {
                cnts.prevDiscards = 0.0
            }

            cnts.nextNeedToBeDiscarded = 0.0
            cnts.prevNeedToBeDiscarded = 0.0

            // Взятки на "подрезке"
            if cnts.takes == 0.0 && rasklad.myHand.count >= 2 && rasklad.nextHand.count >= 2 && !rasklad.prevHand.isEmpty {
                if subEst.nextMin < subEst.myMin2 && subEst.prevMin < subEst.myMin2 {
                    while subEst.prevMin2 > subEst.myMin2 {
                        subEst.discardPrev()
                        cnts.scissorsPrevDiscards += 1
                    }
                    cnts.scissorsTakes += 1

                    if cnts.scissorsPrevDiscards > 0 {
                        subEst.reset()
                    }
                }
            }

            // Необходимость проноса
            if cnts.prevTakes > 0 && cnts.takes == 0.0 {
                var takes = cnts.takes
                while takes == 0.0 {
                    subEst.discardNext()
                    takes = subEst.calcTakes()
                    cnts.nextNeedToBeDiscarded += 1
                }
            }
            subEst.reset()
            if cnts.nextTakes > 0 && cnts.takes == 0.0 {
                var takes = cnts.takes
                while takes == 0.0 {
                    subEst.discardPrev()
                    takes = subEst.calcTakes()
                    cnts.prevNeedToBeDiscarded += 1
                }
            }
        }
    }

    public override func getIntegral() throws -> Double {
        // Функция полезности
        var res = 0.0
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
        var totalNextNeedToBeDiscarded = 0.0
        var totalPrevNeedToBeDiscarded = 0.0
        var totalScissorsTakes = 0.0
        var totalScissorsPrevNeedToBeDiscarded = 0.0

        for color in 0..<4 {
            let cnts = colors[color]!
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

        for color in 0..<4 {
            let cnts = colors[color]!
            cnts.prevCanBeDiscarded = totalPrevDiscards - cnts.prevDiscards
            cnts.nextCanBeDiscarded = totalNextDiscards - cnts.nextDiscards
            let notThisColorNextToPrev = totalNextToPrev - cnts.nextToPrev

            if cnts.prevNeedToBeDiscarded <= cnts.prevCanBeDiscarded && cnts.prevNeedToBeDiscarded > 0 {
                totalPrevNeedToBeDiscarded += cnts.prevNeedToBeDiscarded
            }

            if cnts.nextNeedToBeDiscarded <= cnts.nextCanBeDiscarded && cnts.nextNeedToBeDiscarded > 0 {
                totalNextNeedToBeDiscarded += cnts.nextNeedToBeDiscarded
            }

            if cnts.scissorsPrevDiscards <= cnts.prevCanBeDiscarded && cnts.scissorsTakes > 0 && (turn == -1 || notThisColorNextToPrev > cnts.scissorsPrevDiscards) {
                totalScissorsPrevNeedToBeDiscarded += cnts.scissorsPrevDiscards
                totalScissorsTakes += cnts.scissorsTakes
            }
        }

        if totalIntercepts > 1 {
            totalIntercepts = 1.0
        }

        if iamSure {
            // Возможности отдаться и перехватить полезны - отжирать их надо только если уверены
            res += 0.0001 * totalExit
            res += 0.0001 * totalIntercepts
        }

        // За взятую взятку:
        if !iamSure {
            res -= 500 * myTakes // TODO: Проверить влияние
        } else if contractor == 0 {
            res -= 1.5 * myTakes // Мизерующий не хочет брать
        } else {
            res -= 1 * myTakes // Ловящие не спешат давать
        }

        if totalNextToPrev < 0.05 && nextTakesSum < 0.05 && turn == 1 {
            return res
        }
        if totalPrevToNext < 0.05 && prevTakesSum < 0.05 && turn == -1 {
            return res
        }

        if totalExit < 0.05 && turn == 0 {
            return res - Double(cardsLeft)
        }

        // Возможности передаться
        res -= 0.000001 * totalNextToPrev
        res -= 0.000001 * totalPrevToNext

        if totalScissorsTakes > 0 {
            res += 0.01 * totalScissorsPrevNeedToBeDiscarded
            res -= 0.5
        }

        if totalNextNeedToBeDiscarded > 0 && (turn == -1 || (turn == 1 && totalNextToPrev >= 1)) {
            res += 0.01 * totalNextNeedToBeDiscarded
            res -= 0.5
        }
        if totalPrevNeedToBeDiscarded > 0 && (turn == 1 || (turn == -1 && totalPrevToNext >= 1)) {
            res += 0.01 * totalPrevNeedToBeDiscarded
            res -= 0.5
        }

        res -= 0.00000001 * totalRisk

        res -= 1 * totalTakes

        if isHidden {
            res -= 0.1 * prevTakesSum
            res -= 0.1 * nextTakesSum
        }

        if turn == -1 {
            res -= 0.000000000001 // Заход хуже всего на руке перед игроком.
        }

        return res
    }
}
