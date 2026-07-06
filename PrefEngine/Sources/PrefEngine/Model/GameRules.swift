import Foundation

public enum RulesGameType: String, Codable { case Sochy, Leningrad, Rostov }
public enum RaspasyProgression: String, Codable { case NoProgression1, Arifm1233, Geom1244 }
public enum RaspasyExit: String, Codable { case Easy6, Med677, Hard678 }
public enum VistType: String, Codable { case HalfResponsibility, FullResponsibility }
public enum ConsolationType: String, Codable { case Gentlemen, Zlob }
public enum EndingType: String, Codable { case Sum, Each }
public enum ConsolationSum: String, Codable { case Normal, Max10 }
public enum ScoreType: String, Codable { case Normal, Leningrad }

public final class GameRules: Codable {
    public var gameType: RulesGameType = .Sochy
    public var raspasyProgression: RaspasyProgression = .Arifm1233
    public var raspasyExit: RaspasyExit = .Med677
    public var miserRaspExit: Bool = true
    public var vist: VistType = .FullResponsibility
    public var consolation: ConsolationType = .Zlob
    public var vistTakeOnRaspas: Int = 5
    public var ending: EndingType = .Each
    public var scoring: ScoreType = .Normal
    public var consolationBonus: ConsolationSum = .Normal
    public var prikupConsolation: Bool = true
    public var stalindgrad: Bool = true

    public init() {}

    // Note: the original Clone() silently skipped scoring/consolationBonus/
    // prikupConsolation/stalindgrad, so those settings never reached a new game.
    // Fixed here (as in the Kotlin port): all fields are copied.
    public func clone() -> GameRules {
        let it = GameRules()
        it.gameType = gameType
        it.raspasyProgression = raspasyProgression
        it.raspasyExit = raspasyExit
        it.miserRaspExit = miserRaspExit
        it.vist = vist
        it.consolation = consolation
        it.vistTakeOnRaspas = vistTakeOnRaspas
        it.ending = ending
        it.scoring = scoring
        it.consolationBonus = consolationBonus
        it.prikupConsolation = prikupConsolation
        it.stalindgrad = stalindgrad
        return it
    }
}
