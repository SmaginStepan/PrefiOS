import Foundation

public final class ContractEstimation: Estimation {

    public final class Color {
        public var myTakes: Double = 0.0
        public var myGives: Double = 0.0

        public var prevTakes: Double = 0.0
        public var prevGives: Double = 0.0

        public var nextTakes: Double = 0.0
        public var nextGives: Double = 0.0

        public var myCards: Double = 0.0
        public var prevCards: Double = 0.0
        public var nextCards: Double = 0.0

        public init() {}
    }

    public var isHidden: Bool = false

    public var colors: [Int: Color] = [:]

    public override init() {
        super.init()
        for i in 0..<4 {
            colors[i] = Color()
        }
    }

    private func forRasklad(_ cnts: Color, _ rasklad: ColorRasklad) throws {
        var myHand = rasklad.myHand.toArray().sorted(by: >)
        var nextHand = rasklad.nextHand.toArray().sorted(by: >)
        var prevHand = rasklad.prevHand.toArray().sorted(by: >)

        cnts.myCards += Double(myHand.count) * rasklad.probability
        cnts.nextCards += Double(nextHand.count) * rasklad.probability
        cnts.prevCards += Double(prevHand.count) * rasklad.probability

        // Разыгрываем мы
        let myTmpHand = myHand
        let nextTmpHand = nextHand
        let prevTmpHand = prevHand
        while myHand.count > 0 || (rasklad.coatColor == trump && (nextHand.count > 0 || prevHand.count > 0)) {
            let myMax = myHand.first ?? 0
            let nextMax = nextHand.first ?? 0
            let prevMax = prevHand.first ?? 0

            if myMax > prevMax && myMax > nextMax {
                // Старшая у игрока (нас)
                cnts.myTakes += rasklad.probability
                // Удаляем у нас старшую, а у вистующих младшие карты
                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
                if nextHand.count > 0 {
                    nextHand.remove(at: nextHand.count - 1)
                }
                if prevHand.count > 0 {
                    prevHand.remove(at: prevHand.count - 1)
                }
            } else {
                // Старшая у вистующих
                cnts.myGives += rasklad.probability

                var givePrev = false
                var giveNext = false

                // Если у вистующих только одна старшая, кладём её:
                if prevMax > myMax && myMax > nextMax {
                    givePrev = true
                } else if nextMax > myMax && myMax > prevMax {
                    giveNext = true
                } else {
                    // У вистующих обе старшие: кладём всегда с более короткой руки, если руки одинаковы, то младшую
                    if prevHand.count < nextHand.count {
                        givePrev = true
                    } else if nextHand.count < prevHand.count {
                        giveNext = true
                    } else if prevMax < nextMax {
                        givePrev = true
                    } else if nextMax < prevMax {
                        giveNext = true
                    }
                }
                if givePrev {
                    if myHand.count > 0 {
                        myHand.remove(at: 0)
                    }
                    if nextHand.count > 0 {
                        nextHand.remove(at: nextHand.count - 1)
                    }
                    if prevHand.count > 0 {
                        prevHand.remove(at: 0)
                    }
                } else if giveNext {
                    if myHand.count > 0 {
                        myHand.remove(at: 0)
                    }
                    if nextHand.count > 0 {
                        nextHand.remove(at: 0)
                    }
                    if prevHand.count > 0 {
                        prevHand.remove(at: prevHand.count - 1)
                    }
                } else {
                    throw PrefError("Не может быть!")
                }
            }
        }
        myHand = myTmpHand
        nextHand = nextTmpHand
        prevHand = prevTmpHand

        // Разыгрывает первый вистующий
        // Второго вистующего игнорируем
        let myTmpHand2 = myHand
        let nextTmpHand2 = nextHand
        let prevTmpHand2 = prevHand
        while (myHand.count > 0 || rasklad.coatColor == trump) && prevHand.count > 0 {
            let myMax = myHand.first ?? 0
            let prevMax = prevHand.first ?? 0

            if prevMax > myMax {
                // Старшая у вистующего
                cnts.prevTakes += rasklad.probability
                // Удаляем у вистующего старшую, а у нас младшую карту
                if myHand.count > 0 {
                    myHand.remove(at: myHand.count - 1)
                }
                if prevHand.count > 0 {
                    prevHand.remove(at: 0)
                }
            } else {
                // Старшая у игрока (нас)
                cnts.prevGives += rasklad.probability
                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
                if prevHand.count > 0 {
                    prevHand.remove(at: 0)
                }
            }
        }
        myHand = myTmpHand2
        nextHand = nextTmpHand2
        prevHand = prevTmpHand2

        // Разыгрывает второй вистующий
        // Первого вистующего игнорируем
        while (myHand.count > 0 || rasklad.coatColor == trump) && nextHand.count > 0 {
            let nextMax = nextHand.first ?? 0
            let myMax = myHand.first ?? 0

            if nextMax > myMax {
                // Старшая у вистующего
                cnts.nextTakes += rasklad.probability
                // Удаляем у вистующего старшую, а у нас младшую карту
                if nextHand.count > 0 {
                    nextHand.remove(at: nextHand.count - 1)
                }
                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
            } else {
                // Старшая у игрока (нас)
                cnts.nextGives += rasklad.probability

                if nextHand.count > 0 {
                    nextHand.remove(at: 0)
                }
                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
            }
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
        cnts.myTakes /= rCnt
        cnts.myGives /= rCnt

        cnts.prevTakes /= rCnt
        cnts.prevGives /= rCnt

        cnts.nextTakes /= rCnt
        cnts.nextGives /= rCnt

        cnts.myCards /= rCnt
        cnts.prevCards /= rCnt
        cnts.nextCards /= rCnt

        // NOTE: preserved from the original C#: unlike MiserEstimation, the result is
        // never stored into Colors here, so other suits keep their previous/default values.
    }

    public override func getIntegral() throws -> Double {
        var res = 0.0
        let trumpK = 0.95
        let otherK = 0.9
        var myTrumps = 0.0
        var myMinTakes = 10.0
        var myMaxGives = 0.0
        for color in 0..<4 {
            let cnts = colors[color]!

            if color == trump {
                // Козыри
                res += trumpK * (cnts.myTakes - cnts.myGives)
                res -= 0.05 * trumpK * (cnts.prevTakes - cnts.prevGives)
                res -= 0.05 * trumpK * (cnts.nextTakes - cnts.nextGives)
                // Козыри бережем!
                res += 0.1 * (cnts.myCards - (cnts.prevCards + cnts.nextCards))
                myTrumps += cnts.myCards
            } else {
                // Остальные
                res += otherK * (cnts.myTakes - cnts.myGives)
                res -= 0.05 * otherK * (cnts.prevTakes - cnts.prevGives)
                res -= 0.05 * otherK * (cnts.nextTakes - cnts.nextGives)

                if cnts.myTakes < myMinTakes {
                    myMinTakes = cnts.myTakes
                }
                if myMaxGives < cnts.myGives {
                    myMaxGives = cnts.myGives
                }
            }
        }
        if myTrumps == 0.0 {
            // Бескозырка: бережём концы!
            res += 1 * myMinTakes
        }
        res += myTakes
        res -= prevTakes
        res -= nextTakes
        return res
    }
}
