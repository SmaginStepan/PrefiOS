import Foundation

public final class VistyEstimation: Estimation {

    public final class Color {
        public var contractTakes: Double = 0.0
        public var contractGives: Double = 0.0

        public var myTakes: Double = 0.0
        public var myGives: Double = 0.0
        public var myCardValues: Double = 0.0

        public var otherTakes: Double = 0.0
        public var otherGives: Double = 0.0

        public var contractCards: Double = 0.0
        public var myCards: Double = 0.0
        public var otherCards: Double = 0.0

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

        var contractHand: [Int]
        var otherHand: [Int]

        switch contractor {
        case -1:
            contractHand = rasklad.prevHand.toArray().sorted(by: >)
            otherHand = rasklad.nextHand.toArray().sorted(by: >)
        case 1:
            contractHand = rasklad.nextHand.toArray().sorted(by: >)
            otherHand = rasklad.prevHand.toArray().sorted(by: >)
        default:
            throw PrefError("Не указан игрок!")
        }

        if isHidden {
            // Вероятность расклада
            if rasklad.coatColor == trump {
                var ourTrump = myHand.count + otherHand.count

                // Считаем расклады, при которых у нас больше козырей, чем у игрока маловероятными
                while ourTrump > contractHand.count {
                    rasklad.probability /= 3
                    ourTrump -= 1
                }
            }
        }

        for card in myHand {
            cnts.myCardValues += Double(card) * rasklad.probability // Считаем суммарную силу карт
        }

        cnts.myCards += Double(myHand.count) * rasklad.probability
        cnts.otherCards += Double(otherHand.count) * rasklad.probability
        cnts.contractCards += Double(contractHand.count) * rasklad.probability

        // Разыгрывает игрок
        let myTmpHand = myHand
        let otherTmpHand = otherHand
        let contractTmpHand = contractHand
        while contractHand.count > 0 || (rasklad.coatColor == trump && (myHand.count > 0 || otherHand.count > 0)) {
            let myMax = myHand.first ?? 0
            let otherMax = otherHand.first ?? 0
            let contractMax = contractHand.first ?? 0

            if contractMax > myMax && contractMax > otherMax {
                // Старшая у игрока
                cnts.contractTakes += rasklad.probability
                // Удаляем у игрока старшую, а у нас младшие карты
                if myHand.count > 0 {
                    myHand.remove(at: myHand.count - 1)
                }
                if otherHand.count > 0 {
                    otherHand.remove(at: otherHand.count - 1)
                }
                if contractHand.count > 0 {
                    contractHand.remove(at: 0)
                }
            } else {
                // Старшая у нас
                cnts.contractGives += rasklad.probability

                var giveMy = false
                var giveOther = false

                // Если у нас только одна старшая, кладём её:
                if myMax > contractMax && contractMax > otherMax {
                    giveMy = true
                } else if otherMax > contractMax && contractMax > myMax {
                    giveOther = true
                } else {
                    // У нас обе старшие: кладём всегда с более короткой руки, если руки одинаковы, то младшую
                    if myHand.count < otherHand.count {
                        giveMy = true
                    } else if otherHand.count < myHand.count {
                        giveOther = true
                    } else if myMax < otherMax {
                        giveMy = true
                    } else if otherMax < myMax {
                        giveOther = true
                    }
                }
                if giveMy {
                    if myHand.count > 0 {
                        myHand.remove(at: 0)
                    }
                    if otherHand.count > 0 {
                        otherHand.remove(at: otherHand.count - 1)
                    }
                    if contractHand.count > 0 {
                        contractHand.remove(at: 0)
                    }
                } else if giveOther {
                    if myHand.count > 0 {
                        myHand.remove(at: myHand.count - 1)
                    }
                    if otherHand.count > 0 {
                        otherHand.remove(at: 0)
                    }
                    if contractHand.count > 0 {
                        contractHand.remove(at: 0)
                    }
                } else {
                    throw PrefError("Не может быть!")
                }
            }
        }
        myHand = myTmpHand
        otherHand = otherTmpHand
        contractHand = contractTmpHand

        // Разыгрываем мы
        // Второго игрока игнорируем
        let myTmpHand2 = myHand
        let otherTmpHand2 = otherHand
        let contractTmpHand2 = contractHand
        while myHand.count > 0 && (contractHand.count > 0 || rasklad.coatColor == trump) {
            let myMax = myHand.first ?? 0
            let contractMax = contractHand.first ?? 0

            if myMax > contractMax {
                // Старшая у нас
                cnts.myTakes += rasklad.probability
                // Удаляем у нас старшую, а у игрока младшую карту
                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
                if contractHand.count > 0 {
                    contractHand.remove(at: contractHand.count - 1)
                }
            } else {
                // Старшая у игрока
                cnts.myGives += rasklad.probability

                if myHand.count > 0 {
                    myHand.remove(at: 0)
                }
                if contractHand.count > 0 {
                    contractHand.remove(at: 0)
                }
            }
        }
        myHand = myTmpHand2
        otherHand = otherTmpHand2
        contractHand = contractTmpHand2

        // Разыгрывает второй вистующий
        // Нас игнорируем
        while otherHand.count > 0 && (contractHand.count > 0 || rasklad.coatColor == trump) {
            let otherMax = otherHand.first ?? 0
            let contractMax = contractHand.first ?? 0

            if otherMax > contractMax {
                cnts.otherTakes += rasklad.probability
                if otherHand.count > 0 {
                    otherHand.remove(at: 0)
                }
                if contractHand.count > 0 {
                    contractHand.remove(at: contractHand.count - 1)
                }
            } else {
                cnts.otherGives += rasklad.probability

                if otherHand.count > 0 {
                    otherHand.remove(at: 0)
                }
                if contractHand.count > 0 {
                    contractHand.remove(at: 0)
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
        cnts.contractTakes /= rCnt
        cnts.contractGives /= rCnt

        cnts.myTakes /= rCnt
        cnts.myGives /= rCnt

        cnts.otherTakes /= rCnt
        cnts.otherGives /= rCnt

        cnts.contractCards /= rCnt
        cnts.myCards /= rCnt
        cnts.otherCards /= rCnt

        cnts.myCardValues /= rCnt

        // NOTE: preserved from the original C#: the result is never stored into Colors here.
    }

    public override func getIntegral() throws -> Double {
        var res = 0.0
        let trumpK = 0.95
        let otherK = 0.9
        var allTrumps = 0.0
        for color in 0..<4 {
            let cnts = colors[color]!

            if color == trump {
                // Козыри
                res -= trumpK * (cnts.contractTakes - cnts.contractGives)
                res += 0.05 * trumpK * (cnts.myTakes - cnts.myGives)
                res += 0.05 * trumpK * (cnts.otherTakes - cnts.otherGives)
                // Козыри бережем!
                res += 0.1 * (cnts.myCards + cnts.otherCards - cnts.contractCards)
                allTrumps = cnts.myCards + cnts.otherCards + cnts.contractCards
            } else {
                // Остальные
                res -= otherK * (cnts.contractTakes - cnts.contractGives)
                res += 0.05 * otherK * (cnts.myTakes - cnts.myGives)
                res += 0.05 * otherK * (cnts.otherTakes - cnts.otherGives)
            }

            if isHidden {
                // Чтобы не вводить второго вистующего в сомнение, всегда стараемся взять или сбросить минимальную карту...
                res += 0.0001 * cnts.myCardValues
            }
        }
        if allTrumps > 0 {
            // Обычно разыгрывать не выгодно:
            if contractor == turn {
                res += 0.1
            }
            // Передавать ход в общем случае выгоднее всего игроку, сидящему перед игроком:
            if contractor == -1 && turn == 1 {
                res += 0.05
            } else if contractor == 1 && turn == 0 {
                res += 0.05
            }
        } else {
            // Бескозырка: стараемся ходить сами
            if contractor != turn {
                res += 0.1
            }
            if contractor == -1 && turn == 1 {
                res += 0.05
            } else if contractor == 1 && turn == 0 {
                res += 0.05
            }
        }

        res += myTakes * 1.001 // Себя любим чууточку больше

        if contractor == -1 {
            res -= prevTakes
        } else {
            res += prevTakes
        }
        if contractor == 1 {
            res -= nextTakes
        } else {
            res += nextTakes
        }

        return res
    }
}
