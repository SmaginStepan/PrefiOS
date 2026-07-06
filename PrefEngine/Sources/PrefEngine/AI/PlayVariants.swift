import Foundation

// MARK: - Hidden play variants

public final class ContractHidden: HiddenPlay {
    public override func createEstimation() -> Estimation {
        let est = ContractEstimation()
        est.isHidden = true
        return est
    }
}

public final class MiserHidden: HiddenPlay {
    public override func createEstimation() -> Estimation {
        let est = MiserEstimation()
        est.isHidden = true
        return est
    }
}

public final class RaspasyHidden: HiddenPlay {
    public override func createEstimation() -> Estimation {
        RaspasyEstimation()
    }
}

public final class VistyHidden: HiddenPlay {
    public override func createEstimation() -> Estimation {
        let est = VistyEstimation()
        est.isHidden = true
        return est
    }
}

// MARK: - Open play variants

public final class ContractOpen: OpenPlay {
    public override func createEstimation() -> Estimation {
        let est = ContractEstimation()
        est.isHidden = false
        return est
    }

    public override func isMaximizing(_ player: Int, _ contractor: Int) -> Bool {
        player == contractor
    }

    public override func createExtremum(_ firstMovePerformer: Int, _ contractor: Int) throws -> Extremums {
        let it = Extremums()
        switch firstMovePerformer {
        case 0: // Мы ходим первые
            it.firstMaximizing = true
            it.secondMaximizing = false
            it.thirdMaximizing = false
        case -1: // Мы ходим вторые
            it.firstMaximizing = false
            it.secondMaximizing = true
            it.thirdMaximizing = false
        case 1: // Мы ходим третьи
            it.firstMaximizing = false
            it.secondMaximizing = false
            it.thirdMaximizing = true
        default:
            throw PrefError("Кто ходит первым - непонятно!")
        }
        return it
    }
}

public final class MiserOpen: OpenPlay {
    public override func createEstimation() -> Estimation {
        let est = MiserEstimation()
        est.isHidden = false
        return est
    }

    public override func isMaximizing(_ player: Int, _ contractor: Int) -> Bool {
        player == contractor
    }

    public override func createExtremum(_ firstMovePerformer: Int, _ contractor: Int) throws -> Extremums {
        let it = Extremums()
        switch firstMovePerformer {
        case 0: // Мы ходим первые
            it.firstMaximizing = true
            it.secondMaximizing = false
            it.thirdMaximizing = false
        case -1: // Мы ходим вторые
            it.firstMaximizing = false
            it.secondMaximizing = true
            it.thirdMaximizing = false
        case 1: // Мы ходим третьи
            it.firstMaximizing = false
            it.secondMaximizing = false
            it.thirdMaximizing = true
        default:
            throw PrefError("Кто ходит первым - непонятно!")
        }
        return it
    }

    public override func getPotentialDiscard(_ info: AIInfo) -> [PotentialDiscard]? {
        info.potentialDiscard
    }
}

public final class MiserAntiOpen: OpenPlay {
    public override func createEstimation() -> Estimation {
        let est = MiserAntiEstimation()
        est.iamSure = self.iamSure
        return est
    }

    public override func isMaximizing(_ player: Int, _ contractor: Int) -> Bool {
        player != contractor
    }

    public override func createExtremum(_ firstMovePerformer: Int, _ contractor: Int) throws -> Extremums {
        let it = Extremums()
        switch firstMovePerformer {
        case 0: // Мы ходим первые
            switch contractor {
            case -1: // Играющий сидит перед нами
                it.firstMaximizing = true
                it.secondMaximizing = true
                it.thirdMaximizing = false
            case 1: // Играющий сидит после нас
                it.firstMaximizing = true
                it.secondMaximizing = false
                it.thirdMaximizing = true
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        case -1: // Мы ходим вторые
            switch contractor {
            case -1:
                it.firstMaximizing = false
                it.secondMaximizing = true
                it.thirdMaximizing = true
            case 1:
                it.firstMaximizing = true
                it.secondMaximizing = true
                it.thirdMaximizing = false
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        case 1: // Мы ходим третьи
            switch contractor {
            case -1:
                it.firstMaximizing = true
                it.secondMaximizing = false
                it.thirdMaximizing = true
            case 1:
                it.firstMaximizing = false
                it.secondMaximizing = true
                it.thirdMaximizing = true
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        default:
            throw PrefError("Кто ходит первым - непонятно!")
        }
        return it
    }

    public override func getPotentialDiscard(_ info: AIInfo) -> [PotentialDiscard]? {
        info.potentialDiscard
    }
}

public final class VistyOpen: OpenPlay {
    public override func createEstimation() -> Estimation {
        let est = VistyEstimation()
        est.isHidden = false
        return est
    }

    public override func isMaximizing(_ player: Int, _ contractor: Int) -> Bool {
        player != contractor
    }

    public override func createExtremum(_ firstMovePerformer: Int, _ contractor: Int) throws -> Extremums {
        let it = Extremums()
        switch firstMovePerformer {
        case 0: // Мы ходим первые
            switch contractor {
            case -1: // Играющий сидит перед нами
                it.firstMaximizing = true
                it.secondMaximizing = true
                it.thirdMaximizing = false
            case 1: // Играющий сидит после нас
                it.firstMaximizing = true
                it.secondMaximizing = false
                it.thirdMaximizing = true
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        case -1: // Мы ходим вторые
            switch contractor {
            case -1:
                it.firstMaximizing = false
                it.secondMaximizing = true
                it.thirdMaximizing = true
            case 1:
                it.firstMaximizing = true
                it.secondMaximizing = true
                it.thirdMaximizing = false
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        case 1: // Мы ходим третьи
            switch contractor {
            case -1:
                it.firstMaximizing = true
                it.secondMaximizing = false
                it.thirdMaximizing = true
            case 1:
                it.firstMaximizing = false
                it.secondMaximizing = true
                it.thirdMaximizing = true
            default:
                throw PrefError("Кто второй вистующий - неясно!")
            }
        default:
            throw PrefError("Кто ходит первым - непонятно!")
        }
        return it
    }
}
