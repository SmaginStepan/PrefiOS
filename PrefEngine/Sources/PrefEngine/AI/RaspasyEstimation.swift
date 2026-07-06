import Foundation

public final class RaspasyEstimation: Estimation {

    public final class Color {
        public var risk: Double = 0.0
        public var exit: Double = 0.0
        public var exit2: Double = 0.0
        public var exit3: Double = 0.0
        public var intercept: Double = 0.0
        public var renons: Double = 0.0
        public var renons2: Double = 0.0
        public var take: Double = 0.0
        public var take2: Double = 0.0
        public var take3: Double = 0.0

        public var next: Color?
        public var prev: Color?
        public var prevToNext: Double = 0.0
        public var nextToPrev: Double = 0.0

        public init() {}
    }

    public var colors: [Int: Color] = [:]

    public var alreadyTaken: Double {
        myTakes
    }

    public override init() {
        super.init()
    }

    public override func getIntegral() throws -> Double {
        // Функция полезности
        var res = 0.0
        var totalRisk = 0.0
        var totalIntercepts = 0.0
        var totalRenons = 0.0
        var totalExit = 0.0
        var totalTakes = 0.0
        var totalNextToPrev = 0.0
        var totalPrevToNext = 0.0
        var nextTakesSum = 0.0
        var prevTakesSum = 0.0

        for color in 0..<4 {
            guard let cnts = colors[color] else { continue }
            totalRenons += cnts.renons + 0.5 * cnts.renons2
            totalNextToPrev += cnts.nextToPrev
            totalPrevToNext += cnts.prevToNext

            totalRisk += cnts.risk
            totalIntercepts += cnts.intercept
            totalExit += cnts.exit + 0.75 * cnts.exit2 + 0.25 * cnts.exit3
            totalTakes += cnts.take + 0.75 * cnts.take2 + 0.25 * cnts.take3

            nextTakesSum += cnts.next!.take + cnts.next!.take2 + cnts.next!.take3
            prevTakesSum += cnts.prev!.take + cnts.prev!.take2 + cnts.prev!.take3
        }

        // За взятую взятку:
        res -= alreadyTaken

        if totalIntercepts > 1 {
            totalIntercepts = 1.0
        }

        let risk = (1 + totalRisk) / ((1 + 3 * totalIntercepts * totalIntercepts) * (1 + totalRenons))

        if totalNextToPrev < 0.05 && nextTakesSum < 0.05 && turn == 1 {
            return res + Double(cardsLeft) + (0.5 * totalRenons) / risk
        }
        if totalPrevToNext < 0.05 && prevTakesSum < 0.05 && turn == -1 {
            return res + Double(cardsLeft) + (0.5 * totalRenons) / risk
        }
        if turn == 0 && totalExit == 0.0 {
            return res - Double(cardsLeft)
        }

        res += 1.5 * totalExit
        res += 0.5 * totalRenons
        res += 0.1 * totalIntercepts

        res -= 0.75 * totalTakes

        if turn == 1 {
            var t = 0.25 * totalRenons
            if cardsLeft > 4 {
                t += 0.5
            }
            t /= risk
            res += t
        } else if turn == -1 {
            var t = 0.25 * totalRenons
            t /= risk
            res += t
        }
        // За ренонс оппонента:
        guard let move = move else {
            throw PrefError("Не задан ход!")
        }
        if move.nextMove == nil || move.nextMove!.coatColor != move.playColor {
            res -= 0.75
        }
        if move.prevMove == nil || move.prevMove!.coatColor != move.playColor {
            res -= 0.75
        }
        return res
    }

    public override func calcRasklad(_ givenRasklad: ColorRasklad) throws {
        let cnts = Color()
        cnts.next = Color()
        cnts.prev = Color()
        forRasklad(cnts, givenRasklad)
        colors[givenRasklad.coatColor] = cnts
    }

    public override func calcAllRasklads(_ color: Int, _ rEnumerator: ColorRaskladEnumerator) throws {
        let cnts = Color()
        cnts.next = Color()
        cnts.prev = Color()
        var rasklad = rEnumerator.getNext()
        var rCnt = 0.0
        while rasklad != nil {
            forRasklad(cnts, rasklad!)
            rCnt += rasklad!.probability
            rasklad = rEnumerator.getNext()
        }
        cnts.risk /= rCnt
        cnts.renons /= rCnt
        cnts.renons2 /= rCnt
        cnts.exit /= rCnt
        cnts.exit2 /= rCnt
        cnts.exit3 /= rCnt
        cnts.intercept /= rCnt
        cnts.take /= rCnt
        cnts.take2 /= rCnt
        cnts.take3 /= rCnt

        cnts.next!.take /= rCnt
        cnts.next!.take2 /= rCnt
        cnts.next!.take3 /= rCnt
        cnts.next!.exit /= rCnt
        cnts.next!.exit2 /= rCnt
        cnts.next!.exit3 /= rCnt
        cnts.next!.intercept /= rCnt

        cnts.prev!.take /= rCnt
        cnts.prev!.take2 /= rCnt
        cnts.prev!.take3 /= rCnt
        cnts.prev!.exit /= rCnt
        cnts.prev!.exit2 /= rCnt
        cnts.prev!.exit3 /= rCnt
        cnts.prev!.intercept /= rCnt

        cnts.nextToPrev /= rCnt
        // NOTE: preserved from the original C# (prevToNext was assigned from nextToPrev)
        cnts.prevToNext = cnts.nextToPrev / rCnt

        colors[color] = cnts
    }

    private func forRasklad(_ cnts: Color, _ rasklad: ColorRasklad) {
        rasklad.myHand = IntList(rasklad.myHand.toArray().sorted())
        rasklad.nextHand = IntList(rasklad.nextHand.toArray().sorted())
        rasklad.prevHand = IntList(rasklad.prevHand.toArray().sorted())

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

        if rasklad.myHand.isEmpty {
            // Шанс пронестись при ренонсе
            if !rasklad.nextHand.isEmpty && !rasklad.prevHand.isEmpty {
                cnts.renons += rasklad.probability
            }
        } else {
            // Шанс пронестись при ренонсе
            if rasklad.nextHand.count > rasklad.myHand.count && rasklad.prevHand.count > rasklad.myHand.count {
                cnts.renons2 += 1
            }

            // Есть ли отход (можно ли отцепиться в эту масть с первого захода)
            let myMin = rasklad.myHand[0]
            let nextMin = rasklad.nextHand.isEmpty ? 0 : rasklad.nextHand[0]
            let prevMin = rasklad.prevHand.isEmpty ? 0 : rasklad.prevHand[0]

            if nextMin > myMin || prevMin > myMin {
                cnts.exit += rasklad.probability
            }
            if nextMin > myMin && nextMin > 0 {
                cnts.next!.exit += rasklad.probability
            }
            if prevMin > myMin && prevMin > 0 {
                cnts.prev!.exit += rasklad.probability
            }

            // Могут ли нам всучить?
            if nextMin < myMin && prevMin < myMin && (nextMin > 0 || prevMin > 0) {
                cnts.take += rasklad.probability
            }
            if nextMin < myMin {
                cnts.next!.take += rasklad.probability
            }
            if prevMin < myMin {
                cnts.prev!.take += rasklad.probability
            }

            // Есть ли перехват (можно гарантированно взять а затем гарантированно отдаться)
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
                if intercept > 0 && (nextMin1 > myMin || prevMin1 > myMin) {
                    cnts.intercept = rasklad.probability
                }
                if nextIntercept > 0 && nextMin1 > myMin {
                    cnts.next!.intercept = rasklad.probability
                }
                if prevIntercept > 0 && prevMin1 > myMin {
                    cnts.prev!.intercept = rasklad.probability
                }
            }

            if rasklad.myHand.count >= 2 && (rasklad.nextHand.count >= 2 || rasklad.prevHand.count >= 2) {
                // Можно ли отцепиться за два хода?
                let myMin2 = rasklad.myHand[1]
                let nextMin2 = rasklad.nextHand.count <= 1 ? 0 : rasklad.nextHand[1]
                let prevMin2 = rasklad.prevHand.count <= 1 ? 0 : rasklad.prevHand[1]
                if nextMin2 > myMin2 || prevMin2 > myMin2 {
                    cnts.exit2 += rasklad.probability
                }
                if nextMin2 > myMin2 {
                    cnts.next!.exit2 += rasklad.probability
                }
                if prevMin2 > myMin2 {
                    cnts.prev!.exit2 += rasklad.probability
                }
                // Могут ли нам всучить за два хода?
                if nextMin2 < myMin2 && prevMin2 < myMin2 {
                    cnts.take2 += rasklad.probability
                }
                if nextMin2 < myMin2 && nextMin2 > 0 {
                    cnts.next!.take2 += rasklad.probability
                }
                if prevMin2 < myMin2 && prevMin2 > 0 {
                    cnts.prev!.take2 += rasklad.probability
                }
            }

            if rasklad.myHand.count >= 3 && (rasklad.nextHand.count >= 3 || rasklad.prevHand.count >= 3) {
                // Можно ли отцепиться за три хода?
                let myMin3 = rasklad.myHand[2]
                let nextMin3 = rasklad.nextHand.count <= 2 ? 0 : rasklad.nextHand[2]
                let prevMin3 = rasklad.prevHand.count <= 2 ? 0 : rasklad.prevHand[2]
                if nextMin3 > myMin3 || prevMin3 > myMin3 {
                    cnts.exit3 += rasklad.probability
                }
                if nextMin3 > myMin3 {
                    cnts.next!.exit3 += rasklad.probability
                }
                if prevMin3 > myMin3 {
                    cnts.prev!.exit3 += rasklad.probability
                }
                // Могут ли нам всучить за три хода?
                if nextMin3 < myMin3 && prevMin3 < myMin3 {
                    cnts.take3 += rasklad.probability
                }
                if nextMin3 < myMin3 && nextMin3 > 0 {
                    cnts.next!.take += rasklad.probability
                }
                if prevMin3 < myMin3 && prevMin3 > 0 {
                    cnts.prev!.take += rasklad.probability
                }
            }
        }

        // Считаем возможность отдаться
        if rasklad.nextHand.count >= 3 && rasklad.prevHand.count >= 3 {
            let next = rasklad.nextHand[2]
            let prev = rasklad.prevHand[2]
            if next > prev {
                cnts.prevToNext += rasklad.probability
            } else {
                cnts.nextToPrev += rasklad.probability
            }
        } else if rasklad.nextHand.count >= 2 && rasklad.prevHand.count >= 2 {
            let next = rasklad.nextHand[1]
            let prev = rasklad.prevHand[1]
            if next > prev {
                cnts.prevToNext += rasklad.probability
            } else {
                cnts.nextToPrev += rasklad.probability
            }
        } else if !rasklad.nextHand.isEmpty && !rasklad.prevHand.isEmpty {
            let next = rasklad.nextHand[0]
            let prev = rasklad.prevHand[0]
            if next > prev {
                cnts.prevToNext += rasklad.probability
            } else {
                cnts.nextToPrev += rasklad.probability
            }
        }
    }
}
