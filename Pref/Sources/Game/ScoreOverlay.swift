import SwiftUI
import PrefEngine

/// Between-deals score for multiplayer, drawn exactly like the single-player
/// score sheet: title, the sheet itself, and the action row underneath it.
/// Read-only; tap the sheet (or Continue) to go on. `onSave` writes the
/// standing as a regular pulka file, `onFinish` (host) ends the match.
struct ScoreOverlay: View {
    let snap: ScoreSnap
    /// Writes the standing as a regular pulka file; returns success.
    var onSave: (() -> Bool)?
    /// Host only: save the pulka and end the match for everyone.
    var onFinish: (() -> Void)?
    let onTap: () -> Void

    @State private var saved = false
    @State private var savedForLimit = -1
    @State private var showResults = false
    // a stray second tap right after closing the results view must not fall
    // through onto the sheet's tap-to-continue surface
    @State private var tapShieldUntil = Date.distantPast

    private func shieldedTap() {
        if Date() >= tapShieldUntil {
            onTap()
        }
    }

    var body: some View {
        let n = snap.names.count
        let cells = n == 4 ? CELLS_4 : CELLS_3
        let nameLabels = n == 4 ? NAMES_4 : NAMES_3
        let arrows = n == 4 ? ARROWS_4 : ARROWS_3
        let lines = n == 4 ? LINES_4 : LINES_3

        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(L(n == 4 ? "sheet4_title" : "sheet3_title"))
                    .font(.system(size: 30))
                    .foregroundColor(Theme.accentGold)
                    .padding(.leading, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                GeometryReader { geo in
                    let kx = geo.size.width / SHEET_W
                    let ky = geo.size.height / SHEET_H

                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            for l in lines {
                                var path = Path()
                                path.move(to: CGPoint(x: l.x1 * size.width, y: l.y1 * size.height))
                                path.addLine(to: CGPoint(x: l.x2 * size.width, y: l.y2 * size.height))
                                context.stroke(path, with: .color(.white), lineWidth: 3)
                            }
                        }

                        Text(String(snap.limit))
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(width: 101 * kx, alignment: .center)
                            .offset(x: 190 * kx, y: 253 * ky)

                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            let value: Int = {
                                switch cell.type {
                                case .Gora: return snap.gora[cell.player]
                                case .Pulya: return snap.pulya[cell.player]
                                case .Visty: return snap.visty[cell.player][cell.refPlayer]
                                }
                            }()
                            Text(String(value))
                                .font(.system(size: 19))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(width: cell.w * kx, alignment: .center)
                                .offset(x: cell.x * kx, y: cell.y * ky)
                        }

                        ForEach(Array(nameLabels.enumerated()), id: \.offset) { _, label in
                            Text(snap.names[label.player])
                                .font(.system(size: 15))
                                .foregroundColor(Theme.accentGold)
                                .lineLimit(1)
                                .frame(width: label.w * kx, alignment: label.align)
                                .offset(x: label.x * kx, y: label.y * ky)
                        }

                        ForEach(Array(arrows.enumerated()), id: \.offset) { _, a in
                            if snap.dealer == a.player {
                                Text(a.up ? "▲" : "▼")
                                    .font(.system(size: 22))
                                    .foregroundColor(Theme.accentGold)
                                    .offset(x: a.x * kx, y: a.y * ky)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { shieldedTap() }
                }

                // action row under the sheet, like the single-player screen
                HStack {
                    Spacer()
                    Button(action: shieldedTap) {
                        Text(L("sheet_continue")).font(.system(size: 12)).lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    Button {
                        showResults = true
                    } label: {
                        Text(L("sheet_score_btn")).font(.system(size: 12)).lineLimit(1).foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if let onFinish = onFinish {
                        Button(action: onFinish) {
                            Text(L("mp_save_finish")).font(.system(size: 12)).lineLimit(1).foregroundColor(.white)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    if let onSave = onSave {
                        Button {
                            saved = onSave()
                            savedForLimit = snapIdentity
                        } label: {
                            Text(L(saveLabelKey)).font(.system(size: 12)).lineLimit(1).foregroundColor(.white)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaved)
                        Spacer()
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)

            // the same final-settlement view the single-player sheet opens
            if showResults {
                ZStack {
                    Theme.background
                        .contentShape(Rectangle())
                        .onTapGesture { /* swallow taps so they don't hit the sheet below */ }
                    CalcResultsView(calc: ScoreOverlay.snapToCalc(snap)) {
                        showResults = false
                        tapShieldUntil = Date().addingTimeInterval(0.4)
                    }
                }
            }
        }
        .onChange(of: snapIdentity) { _ in showResults = false }
    }

    /// The snapshot as a throwaway Calculation, enough for the final settlement.
    static func snapToCalc(_ snap: ScoreSnap) -> Calculation {
        let n = snap.names.count
        let c = Calculation(playersCount: n, limit: snap.limit)
        if snap.leningrad {
            c.rules.scoring = .Leningrad
        }
        for i in 0..<n {
            c.scores[i].name = snap.names[i]
            c.scores[i].pulya = snap.pulya[i]
            c.scores[i].gora = snap.gora[i]
            for j in 0..<n where i != j {
                c.scores[i].visty[j] = snap.visty.indices.contains(i) ? snap.visty[i][j] : 0
            }
        }
        return c
    }

    // "Saved" resets with each new snapshot (Android: remember(snap))
    private var snapIdentity: Int {
        snap.pulya.reduce(0, +) &* 31 &+ snap.gora.reduce(0, +)
    }

    private var isSaved: Bool {
        saved && savedForLimit == snapIdentity
    }

    private var saveLabelKey: String {
        isSaved ? "game_score_saved" : "game_btn_save_score"
    }
}
