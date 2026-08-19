import SwiftUI
import PrefEngine

/// Between-deals score for multiplayer, drawn as the traditional pulka sheet
/// (same 480x550 geometry as the score calculator, 3 or 4 players). Read-only;
/// tap to continue. `onSave` writes the standing as a regular pulka file.
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
        let lines = n == 4 ? LINES_4 : LINES_3

        GeometryReader { geo in
            let kx = geo.size.width / SHEET_W
            let ky = geo.size.height / SHEET_H

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    for l in lines {
                        var path = Path()
                        path.move(to: CGPoint(x: l.x1 * size.width, y: l.y1 * size.height))
                        path.addLine(to: CGPoint(x: l.x2 * size.width, y: l.y2 * size.height))
                        context.stroke(path, with: .color(.white), lineWidth: 2.5)
                    }
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    let value: Int = {
                        switch cell.type {
                        case .Gora: return snap.gora[cell.player]
                        case .Pulya: return snap.pulya[cell.player]
                        case .Visty: return snap.visty[cell.player][cell.refPlayer]
                        }
                    }()
                    Text(String(value))
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: cell.w * kx, alignment: .center)
                        .offset(x: cell.x * kx, y: cell.y * ky)
                }

                Text(String(snap.limit))
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 101 * kx, alignment: .center)
                    .offset(x: 190 * kx, y: 253 * ky)

                ForEach(Array(nameLabels.enumerated()), id: \.offset) { _, label in
                    let dealer = label.player == snap.dealer
                    Text((dealer ? "▸ " : "") + snap.names[label.player])
                        .font(.system(size: 13))
                        .foregroundColor(Theme.accentGold)
                        .lineLimit(1)
                        .frame(width: label.w * kx, alignment: label.align)
                        .offset(x: label.x * kx, y: label.y * ky)
                }

                // Bottom action bar: one centered row (like the single-player sheet)
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Spacer()
                        Button(action: onTap) {
                            Text(L("sheet_continue")).font(.system(size: 11)).lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(height: 30)
                        Button {
                            showResults = true
                        } label: {
                            Text(L("sheet_score_btn")).font(.system(size: 11)).lineLimit(1).foregroundColor(.white)
                        }
                        .buttonStyle(.bordered)
                        .frame(height: 30)
                        if let onFinish = onFinish {
                            Button(action: onFinish) {
                                Text(L("mp_save_finish")).font(.system(size: 11)).lineLimit(1).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                            .frame(height: 30)
                        }
                        if let onSave = onSave {
                            Button {
                                saved = onSave()
                                savedForLimit = snapIdentity
                            } label: {
                                Text(L(saveLabelKey)).font(.system(size: 11)).lineLimit(1).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSaved)
                            .frame(height: 30)
                        }
                        Spacer()
                    }
                    .padding(4)
                }

                // the same final-settlement view the single-player sheet opens
                if showResults {
                    ZStack {
                        Color(red: 0x10 / 255.0, green: 0x38 / 255.0, blue: 0x14 / 255.0)
                            .contentShape(Rectangle())
                            .onTapGesture { /* swallow taps so they don't hit the sheet below */ }
                        CalcResultsView(calc: ScoreOverlay.snapToCalc(snap)) {
                            showResults = false
                            tapShieldUntil = Date().addingTimeInterval(0.4)
                        }
                    }
                }
            }
        }
        .background(Color(red: 0x10 / 255.0, green: 0x38 / 255.0, blue: 0x14 / 255.0).opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentGold, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { shieldedTap() }
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
