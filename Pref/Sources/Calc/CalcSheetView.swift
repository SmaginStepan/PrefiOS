import SwiftUI
import PrefEngine

// Cell geometry in the original 480x550 canvas units.
private struct Cell {
    let type: ScoreValueType
    let player: Int
    let refPlayer: Int
    let x: Double
    let y: Double
    let w: Double
    var align: Alignment = .center
}

private struct NameLabel {
    let player: Int
    let x: Double
    let y: Double
    let w: Double
    let align: Alignment
}

private struct DealerArrow {
    let player: Int
    let x: Double
    let y: Double
    let up: Bool
}

private struct SheetLine {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

private let CELLS_3: [Cell] = [
    Cell(type: .Visty, player: 1, refPlayer: 0, x: 0, y: 362, w: 71),
    Cell(type: .Visty, player: 1, refPlayer: 2, x: 0, y: 119, w: 71),
    Cell(type: .Pulya, player: 1, refPlayer: 0, x: 83, y: 320, w: 57),
    Cell(type: .Gora, player: 1, refPlayer: 0, x: 139, y: 201, w: 95),
    Cell(type: .Pulya, player: 0, refPlayer: 0, x: 190, y: 414, w: 101),
    Cell(type: .Pulya, player: 2, refPlayer: 0, x: 332, y: 320, w: 71),
    Cell(type: .Gora, player: 0, refPlayer: 0, x: 201, y: 324, w: 80),
    Cell(type: .Gora, player: 2, refPlayer: 0, x: 252, y: 201, w: 93),
    Cell(type: .Visty, player: 0, refPlayer: 1, x: 110, y: 492, w: 80),
    Cell(type: .Visty, player: 0, refPlayer: 2, x: 300, y: 492, w: 80),
    Cell(type: .Visty, player: 2, refPlayer: 0, x: 387, y: 356, w: 95),
    Cell(type: .Visty, player: 2, refPlayer: 1, x: 396, y: 119, w: 80)
]

private let NAMES_3: [NameLabel] = [
    NameLabel(player: 0, x: 83, y: 536, w: 320, align: .center),
    NameLabel(player: 1, x: 0, y: 17, w: 214, align: .leading),
    NameLabel(player: 2, x: 283, y: 17, w: 186, align: .trailing)
]

private let ARROWS_3: [DealerArrow] = [
    DealerArrow(player: 0, x: 209, y: 510, up: false),
    DealerArrow(player: 1, x: 7, y: 43, up: true),
    DealerArrow(player: 2, x: 404, y: 43, up: true)
]

private let LINES_3: [SheetLine] = {
    let s1 = 0.15, s2 = 0.30, s3 = 0.45
    let e1 = 0.85, e2 = 0.70, e3 = 0.55
    return [
        SheetLine(0.5, 0.1, 0.5, s3),
        SheetLine(0.0, 1.0, s3, e3),
        SheetLine(e3, e3, 1.0, 1.0),
        SheetLine(s1, 0.1, s1, e1),
        SheetLine(e1, 0.1, e1, e1),
        SheetLine(s1, e1, e1, e1),
        SheetLine(s2, 0.1, s2, e2),
        SheetLine(e2, 0.1, e2, e2),
        SheetLine(s2, e2, e2, e2),
        SheetLine(0.0, 0.5, s1, 0.5),
        SheetLine(1.0, 0.5, e1, 0.5),
        SheetLine(0.5, 0.95, 0.5, e1)
    ]
}()

private let CELLS_4: [Cell] = [
    Cell(type: .Visty, player: 1, refPlayer: 0, x: 0, y: 410, w: 71),
    Cell(type: .Visty, player: 1, refPlayer: 2, x: 0, y: 91, w: 71),
    Cell(type: .Visty, player: 1, refPlayer: 3, x: 0, y: 266, w: 71),
    Cell(type: .Pulya, player: 1, refPlayer: 0, x: 67, y: 302, w: 57),
    Cell(type: .Gora, player: 1, refPlayer: 0, x: 110, y: 219, w: 95),
    Cell(type: .Pulya, player: 0, refPlayer: 0, x: 190, y: 423, w: 101),
    Cell(type: .Pulya, player: 2, refPlayer: 0, x: 183, y: 89, w: 115),
    Cell(type: .Pulya, player: 3, refPlayer: 0, x: 357, y: 216, w: 57),
    Cell(type: .Gora, player: 0, refPlayer: 0, x: 200, y: 320, w: 80),
    Cell(type: .Gora, player: 2, refPlayer: 0, x: 196, y: 201, w: 93),
    Cell(type: .Gora, player: 3, refPlayer: 0, x: 280, y: 300, w: 79),
    Cell(type: .Visty, player: 0, refPlayer: 1, x: 72, y: 492, w: 80),
    Cell(type: .Visty, player: 0, refPlayer: 2, x: 200, y: 492, w: 80),
    Cell(type: .Visty, player: 3, refPlayer: 0, x: 404, y: 410, w: 76),
    Cell(type: .Visty, player: 3, refPlayer: 1, x: 404, y: 265, w: 76),
    Cell(type: .Visty, player: 3, refPlayer: 2, x: 404, y: 91, w: 76),
    Cell(type: .Visty, player: 0, refPlayer: 3, x: 323, y: 492, w: 83),
    Cell(type: .Visty, player: 2, refPlayer: 0, x: 193, y: 17, w: 95),
    Cell(type: .Visty, player: 2, refPlayer: 1, x: 72, y: 17, w: 80),
    Cell(type: .Visty, player: 2, refPlayer: 3, x: 323, y: 17, w: 83)
]

private let NAMES_4: [NameLabel] = [
    NameLabel(player: 0, x: 187, y: 362, w: 112, align: .center),
    NameLabel(player: 1, x: 72, y: 263, w: 133, align: .center),
    NameLabel(player: 2, x: 187, y: 164, w: 118, align: .center),
    NameLabel(player: 3, x: 280, y: 264, w: 137, align: .center)
]

private let ARROWS_4: [DealerArrow] = [
    DealerArrow(player: 0, x: 210, y: 376, up: true),
    DealerArrow(player: 1, x: 126, y: 284, up: true),
    DealerArrow(player: 2, x: 211, y: 134, up: false),
    DealerArrow(player: 3, x: 296, y: 239, up: false)
]

private let LINES_4: [SheetLine] = {
    let s1 = 0.15, s2 = 0.25, s3 = 0.45
    let e1 = 0.85, e2 = 0.75, e3 = 0.55
    return [
        SheetLine(0.0, 0.0, s3, s3),
        SheetLine(1.0, 1.0, e3, e3),
        SheetLine(0.0, 1.0, s3, e3),
        SheetLine(e3, s3, 1.0, 0.0),
        SheetLine(s1, s1, s1, e1),
        SheetLine(e1, s1, e1, e1),
        SheetLine(s1, s1, e1, s1),
        SheetLine(s1, e1, e1, e1),
        SheetLine(s2, s2, s2, s3),
        SheetLine(s2, e3, s2, e2),
        SheetLine(e2, s2, e2, s3),
        SheetLine(e2, e3, e2, e2),
        SheetLine(s2, s2, e2, s2),
        SheetLine(s2, e2, e2, e2),
        SheetLine(0.0, 0.333, s1, 0.333),
        SheetLine(0.0, 0.666, s1, 0.666),
        SheetLine(1.0, 0.333, e1, 0.333),
        SheetLine(1.0, 0.666, e1, 0.666),
        SheetLine(0.333, 0.0, 0.333, s1),
        SheetLine(0.666, 0.0, 0.666, s1),
        SheetLine(0.333, 1.0, 0.333, e1),
        SheetLine(0.666, 1.0, 0.666, e1)
    ]
}()

private let SHEET_W = 480.0
private let SHEET_H = 550.0

private func cellValue(_ calc: Calculation, _ cell: Cell) -> String {
    switch cell.type {
    case .Gora: return String(calc.scores[cell.player].gora)
    case .Pulya: return String(calc.scores[cell.player].pulya)
    case .Visty: return String(calc.scores[cell.player].visty[cell.refPlayer] ?? 0)
    }
}

/// Port of CalcSheet3a/CalcSheet4a: the pulka sheet with editable cells.
/// - fromGame: read-only mode reached from the game table (3 players).
struct CalcSheetView: View {
    let playersCount: Int
    let fromGame: Bool
    let startWithSetup: Bool
    let onHelp: () -> Void
    let onResults: () -> Void
    let onResultsHighscores: () -> Void
    let onRecordGame: () -> Void
    let onHistory: () -> Void
    let onRules: () -> Void
    let onContinueGame: () -> Void

    @EnvironmentObject private var app: AppState
    @State private var calc: Calculation?
    @State private var version = 0

    // Value-edit popup state
    @State private var editCell: Cell?
    @State private var editValue = ""
    // Setup popup (limit + names): shown on first open of a new sheet
    @State private var showSetup = false
    @State private var showSaved = false
    @State private var showDealer = false
    @State private var setupNames: [String] = []
    @State private var setupLimit = ""

    private func resolveCalc() -> Calculation {
        if let calc = calc {
            return calc
        }
        let resolved: Calculation
        if fromGame {
            resolved = app.game!.calc
        } else if let existing = app.calc, existing.playersCount == playersCount {
            resolved = existing
        } else {
            resolved = Calculation(playersCount: playersCount, limit: 10)
            app.calc = resolved
        }
        return resolved
    }

    var body: some View {
        let calc = resolveCalc()
        let cells = playersCount == 3 ? CELLS_3 : CELLS_4
        let names = playersCount == 3 ? NAMES_3 : NAMES_4
        let arrows = playersCount == 3 ? ARROWS_3 : ARROWS_4
        let lines = playersCount == 3 ? LINES_3 : LINES_4

        VStack(spacing: 0) {
            Text(L(playersCount == 3 ? "sheet3_title" : "sheet4_title"))
                .font(.system(size: 30))
                .foregroundColor(Theme.accentGold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            GeometryReader { geo in
                let kx = geo.size.width / SHEET_W
                let ky = geo.size.height / SHEET_H

                ZStack(alignment: .topLeading) {
                    let _ = version // recompute cells on model change
                    Canvas { context, size in
                        for l in lines {
                            var path = Path()
                            path.move(to: CGPoint(x: l.x1 * size.width, y: l.y1 * size.height))
                            path.addLine(to: CGPoint(x: l.x2 * size.width, y: l.y2 * size.height))
                            context.stroke(path, with: .color(.white), lineWidth: 3)
                        }
                    }

                    // Limit cell (opens setup)
                    Text(String(calc.limit))
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 101 * kx, alignment: .center)
                        .offset(x: 190 * kx, y: 253 * ky)
                        .onTapGesture {
                            if !fromGame {
                                openSetup(calc)
                            }
                        }

                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        Text(cellValue(calc, cell))
                            .font(.system(size: 19))
                            .foregroundColor(.white)
                            .frame(width: cell.w * kx, alignment: .center)
                            .offset(x: cell.x * kx, y: cell.y * ky)
                            .onTapGesture {
                                if !fromGame {
                                    editValue = cellValue(calc, cell)
                                    editCell = cell
                                }
                            }
                    }

                    ForEach(Array(names.enumerated()), id: \.offset) { _, n in
                        Text(calc.scores[n.player].name)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.accentGold)
                            .frame(width: n.w * kx, alignment: n.align)
                            .offset(x: n.x * kx, y: n.y * ky)
                            .onTapGesture {
                                if !fromGame {
                                    openSetup(calc)
                                }
                            }
                    }

                    ForEach(Array(arrows.enumerated()), id: \.offset) { _, a in
                        if calc.dealer == a.player {
                            Text(a.up ? "▲" : "▼")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.accentGold)
                                .offset(x: a.x * kx, y: a.y * ky)
                        }
                    }
                }
            }

            // Bottom action bar
            if fromGame {
                HStack {
                    Spacer()
                    Button { onContinueGame() } label: { Text(L("sheet_continue")) }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button { onResults() } label: { Text(L("sheet_score_btn")) }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button { onHelp() } label: { Text(L("sheet_help")).font(.system(size: 12)) }
                            .buttonStyle(.bordered)
                        Button {
                            calc.save()
                            showSaved = true
                        } label: { Text(L("sheet_save")).font(.system(size: 12)) }
                            .buttonStyle(.bordered)
                        Button { onResults() } label: { Text(L("sheet_calc")).font(.system(size: 12)) }
                            .buttonStyle(.bordered)
                        Button { onRecordGame() } label: { Text(L("sheet_record")).font(.system(size: 12)) }
                            .buttonStyle(.bordered)
                        Button { onHistory() } label: { Text(L("sheet_history")).font(.system(size: 12)) }
                            .buttonStyle(.bordered)
                    }
                    .padding(8)
                }
            }
        }
        .background(Theme.background)
        .onAppear {
            self.calc = calc
            if setupNames.isEmpty {
                setupNames = calc.scores.map { $0.name }
                setupLimit = String(calc.limit)
            }
            if startWithSetup && !fromGame && version == 0 {
                showSetup = true
            }
            if fromGame && calc.isFinished {
                onResultsHighscores()
            }
        }
        // Value editor popup
        .alert(editCellTitle(calc), isPresented: Binding(get: { editCell != nil }, set: { if !$0 { editCell = nil } })) {
            TextField("", text: $editValue)
                .keyboardType(.numbersAndPunctuation)
            Button(L("save")) {
                if let cell = editCell, let value = Int(editValue) {
                    calc.setValue(cell.type, value, cell.player, cell.refPlayer)
                    version += 1
                }
                editCell = nil
            }
            Button(L("close"), role: .cancel) { editCell = nil }
        } message: {
            if let cell = editCell {
                Text(calc.getValueHistory(cell.type, cell.player, cell.refPlayer))
            }
        }
        // Setup popup (limit + names + rules)
        .sheet(isPresented: $showSetup) {
            SetupSheet(
                playersCount: playersCount,
                setupNames: $setupNames,
                setupLimit: $setupLimit,
                onRules: {
                    applySetup(calc)
                    showSetup = false
                    onRules()
                },
                onSave: {
                    applySetup(calc)
                    version += 1
                    showSetup = false
                    showDealer = true
                },
                onClose: { showSetup = false }
            )
        }
        // Saved confirmation
        .alert(L("sheet_saved"), isPresented: $showSaved) {
            Button(L("close"), role: .cancel) {}
        }
        // Dealer selection
        .sheet(isPresented: $showDealer) {
            DealerSheet(calc: calc, playersCount: playersCount, version: $version, onClose: { showDealer = false })
        }
    }

    private func openSetup(_ calc: Calculation) {
        setupNames = calc.scores.map { $0.name }
        setupLimit = String(calc.limit)
        showSetup = true
    }

    private func applySetup(_ calc: Calculation) {
        for i in 0..<playersCount {
            calc.scores[i].name = setupNames[i]
        }
        if let limit = Int(setupLimit) {
            calc.limit = limit
        }
    }

    private func editCellTitle(_ calc: Calculation) -> String {
        guard let cell = editCell else { return "" }
        switch cell.type {
        case .Gora: return calc.scores[cell.player].name + " " + L("sheet_gora")
        case .Pulya: return calc.scores[cell.player].name + " " + L("sheet_pulya")
        case .Visty: return calc.scores[cell.player].name + " " + LF("sheet_visty_on", calc.scores[cell.refPlayer].name)
        }
    }
}

private struct SetupSheet: View {
    let playersCount: Int
    @Binding var setupNames: [String]
    @Binding var setupLimit: String
    let onRules: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L("sheet_limit_label") + " " + L("sheet_limit_hint"))) {
                    TextField(L("sheet_limit_label"), text: $setupLimit)
                        .keyboardType(.numberPad)
                }
                Section(header: Text(L("sheet_names_label"))) {
                    ForEach(0..<playersCount, id: \.self) { i in
                        TextField("", text: Binding(
                            get: { i < setupNames.count ? setupNames[i] : "" },
                            set: { v in
                                if i < setupNames.count {
                                    setupNames[i] = v
                                }
                            }
                        ))
                    }
                }
                Button(L("sheet_rules_btn")) { onRules() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("save")) { onSave() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("close")) { onClose() }
                }
            }
        }
    }
}

private struct DealerSheet: View {
    let calc: Calculation
    let playersCount: Int
    @Binding var version: Int
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L("sheet_dealer_label"))) {
                    ForEach(0..<playersCount, id: \.self) { i in
                        Button {
                            calc.dealer = i
                            version += 1
                        } label: {
                            HStack {
                                Image(systemName: calc.dealer == i ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(Theme.accentGold)
                                Text(calc.scores[i].name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("close")) { onClose() }
                }
            }
        }
    }
}
