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

    private enum CodingKeys: String, CodingKey {
        case gameType, raspasyProgression, raspasyExit, miserRaspExit, vist, consolation,
             vistTakeOnRaspas, ending, scoring, consolationBonus, prikupConsolation, stalindgrad
    }

    // Lenient decode (like kotlinx with defaults): missing fields keep defaults.
    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameType = try c.decodeIfPresent(RulesGameType.self, forKey: .gameType) ?? .Sochy
        raspasyProgression = try c.decodeIfPresent(RaspasyProgression.self, forKey: .raspasyProgression) ?? .Arifm1233
        raspasyExit = try c.decodeIfPresent(RaspasyExit.self, forKey: .raspasyExit) ?? .Med677
        miserRaspExit = try c.decodeIfPresent(Bool.self, forKey: .miserRaspExit) ?? true
        vist = try c.decodeIfPresent(VistType.self, forKey: .vist) ?? .FullResponsibility
        consolation = try c.decodeIfPresent(ConsolationType.self, forKey: .consolation) ?? .Zlob
        vistTakeOnRaspas = try c.decodeIfPresent(Int.self, forKey: .vistTakeOnRaspas) ?? 5
        ending = try c.decodeIfPresent(EndingType.self, forKey: .ending) ?? .Each
        scoring = try c.decodeIfPresent(ScoreType.self, forKey: .scoring) ?? .Normal
        consolationBonus = try c.decodeIfPresent(ConsolationSum.self, forKey: .consolationBonus) ?? .Normal
        prikupConsolation = try c.decodeIfPresent(Bool.self, forKey: .prikupConsolation) ?? true
        stalindgrad = try c.decodeIfPresent(Bool.self, forKey: .stalindgrad) ?? true
    }

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
