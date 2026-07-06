import Foundation

public final class ColorRaskladEnumerator {
    private var opponentCards: IntList
    private let myCards: IntList
    private let color: Int
    private let nextMax: Int
    private let prevMax: Int
    private var pos = 0
    private var max = 0

    private var current: ColorRasklad?

    public init(_ myCards: [Int], _ outOfPlayCards: [Int], _ color: Int, _ nextMax: Int, _ prevMax: Int) {
        self.color = color
        self.nextMax = nextMax
        self.prevMax = prevMax
        self.myCards = IntList(myCards.sorted())

        var opponents: [Int] = []
        for v in 7..<15 {
            if !myCards.contains(v) && !outOfPlayCards.contains(v) {
                opponents.append(v)
            }
        }
        self.opponentCards = IntList(opponents.sorted())
        max = 1
        for _ in 0..<self.opponentCards.count {
            max *= 2
        }
        reset()
    }

    private func internalNext() -> ColorRasklad? {
        if current == nil {
            return nil
        }
        var next: ColorRasklad? = {
            let it = ColorRasklad()
            it.coatColor = color
            it.myHand = myCards.copy()
            it.nextHand = IntList()
            it.prevHand = IntList()
            it.probability = 1.0
            return it
        }()
        pos += 1
        if pos >= max {
            next = nil
        } else if prevMax == 0 || nextMax == 0 {
            next = nil
        } else {
            var m = 1
            var n = pos
            for i in 0..<opponentCards.count {
                m *= 2
                if n % m == 0 {
                    next!.nextHand.append(opponentCards[i])
                } else {
                    next!.prevHand.append(opponentCards[i])
                }
                n -= n % m
            }
        }
        let res = current
        current = next
        return res
    }

    public func getNext() -> ColorRasklad? {
        internalNext()
    }

    public func reset() {
        let it = ColorRasklad()
        it.coatColor = color
        it.myHand = myCards // shared on purpose (see IntList)
        it.nextHand = opponentCards // shared on purpose
        it.prevHand = IntList()
        it.probability = 1.0
        current = it
        if nextMax == 0 {
            current!.prevHand = current!.nextHand
            current!.nextHand = IntList()
        }
        pos = 0
    }

    @discardableResult
    public func moveNext() -> Bool {
        getNext() != nil
    }
}
