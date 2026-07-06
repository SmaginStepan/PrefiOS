import Foundation

public final class CalcList {

    public final class Calc {
        public var limit: Int = 0
        public var playersCount: Int = 0
        public var created: Int64 = 0

        public init() {}
    }

    public var calcs: [Calc] = []

    public init() {}

    public func load() {
        calcs = []
        for fileName in PrefStorage.listFiles(prefix: "pulya_").sorted(by: >) {
            let shortName: String
            if let dotIndex = fileName.lastIndex(of: ".") {
                shortName = String(fileName[fileName.startIndex..<dotIndex])
            } else {
                shortName = fileName
            }
            let ss = String(shortName.dropFirst(6)).split(separator: "_").map(String.init)
            guard ss.count >= 3, let players = Int(ss[1]), let limit = Int(ss[2]) else {
                continue // skip malformed file names
            }
            let date = Calculation.parseFileDate(ss[0])
            let calc = Calc()
            calc.created = date
            calc.playersCount = players
            calc.limit = limit
            calcs.append(calc)
        }
    }
}
