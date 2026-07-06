import Foundation

public final class RaskladEnumerator {
    private let myCards: [Card]
    private let outOfPlayCards: [Card]
    private let nextMax: Int
    private let prevMax: Int
    private let nextNotExists: [Int]
    private let prevNotExists: [Int]
    private let unknownPrikupLength: Int
    private let contractor: Int?

    private var enumerators: [Int: ColorRaskladEnumerator] = [:]
    private var current: Rasklad?

    public init(
        _ myCards: [Card],
        _ outOfPlayCards: [Card],
        _ nextMax: Int,
        _ prevMax: Int,
        _ nextNotExists: [Int],
        _ prevNotExists: [Int],
        _ unknownPrikupLength: Int,
        _ contractor: Int?
    ) {
        self.myCards = myCards
        self.outOfPlayCards = outOfPlayCards
        self.nextMax = nextMax
        self.prevMax = prevMax
        self.nextNotExists = nextNotExists
        self.prevNotExists = prevNotExists
        self.unknownPrikupLength = unknownPrikupLength
        self.contractor = contractor

        for i in 0..<4 {
            let cards = myCards.filter { $0.coatColor == i }.sorted { $0.value < $1.value }.map { $0.value }
            let outOfPlay = outOfPlayCards.filter { $0.coatColor == i }.sorted { $0.value < $1.value }.map { $0.value }
            var next = nextMax
            var prev = prevMax
            if nextNotExists.contains(i) {
                next = 0
            }
            if prevNotExists.contains(i) {
                prev = 0
            }
            let enumerator = ColorRaskladEnumerator(cards, outOfPlay, i, next, prev)
            enumerators[i] = enumerator
        }
        reset()
    }

    private func internalNext() -> Rasklad? {
        if current == nil {
            return nil
        }

        var next: Rasklad? = Rasklad()
        for j in 1..<4 {
            next!.byColor[j] = current!.byColor[j]!
        }
        var stop = false
        var i = 0
        while !stop && i < 4 {
            stop = true
            var cr = enumerators[i]!.getNext()
            if cr != nil {
                next!.byColor[i] = cr!
            } else {
                enumerators[i]!.reset()
                cr = enumerators[i]!.getNext()
                if cr != nil {
                    next!.byColor[i] = cr!
                }
                i += 1
                stop = false
            }
        }
        if i == 4 {
            next = nil
        }

        let res = current
        current = next
        return res
    }

    private func checkRaskad(_ rasklad: Rasklad) -> Bool {
        var prevLen = 0
        var nextLen = 0
        var overdraft = 0
        for key in 0..<4 {
            guard let cr = rasklad.byColor[key] else { continue }
            nextLen += cr.nextHand.count
            prevLen += cr.prevHand.count
            if contractor == -1 && prevNotExists.contains(key) && !nextNotExists.contains(key) {
                overdraft = unknownPrikupLength
            }
            if contractor == 1 && nextNotExists.contains(key) && !prevNotExists.contains(key) {
                overdraft = unknownPrikupLength
            }
        }
        if prevLen > (prevMax + unknownPrikupLength) || nextLen > (nextMax + unknownPrikupLength) {
            return false
        }
        if contractor == -1 && nextLen > (nextMax + overdraft) {
            return false // играет предыдущий, значит следующий не может иметь лишних карт
        }
        if contractor == 1 && prevLen > (prevMax + overdraft) {
            return false // играет следующий, значит предыдущий не может иметь лишних карт
        }

        return true
    }

    public func getNext() -> Rasklad? {
        var res = internalNext()
        while res != nil && !checkRaskad(res!) {
            res = internalNext()
        }
        return res
    }

    public func reset() {
        current = Rasklad()
        for key in 0..<4 {
            guard let er = enumerators[key] else { continue }
            er.reset()
            if let r = er.getNext() {
                current!.byColor[key] = r
            }
        }
    }
}
