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

                // Bottom action bar (compact)
                VStack {
                    Spacer()
                    HStack {
                        Button(action: onTap) {
                            Text(L("sheet_continue")).font(.system(size: 11)).lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(height: 30)
                        Spacer()
                        if let onFinish = onFinish {
                            Button(action: onFinish) {
                                Text(L("mp_save_finish")).font(.system(size: 11)).lineLimit(1).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                            .frame(height: 30)
                            Spacer()
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
                    }
                    .padding(4)
                }
            }
        }
        .background(Color(red: 0x10 / 255.0, green: 0x38 / 255.0, blue: 0x14 / 255.0).opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentGold, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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
