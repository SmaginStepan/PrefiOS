import SwiftUI
import PrefEngine

/// Compact score standing shown in multiplayer between deals and at game end.
struct ScoreOverlay: View {
    let snap: ScoreSnap
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LF("score_title_fmt", snap.limit))
                .foregroundColor(Theme.accentGold)
                .font(.system(size: 18, weight: .medium))
                .padding(.bottom, 8)
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text(L("sheet_pulya"))
                    .foregroundColor(.white).font(.system(size: 12))
                    .frame(width: 64, alignment: .trailing)
                Text(L("sheet_gora"))
                    .foregroundColor(.white).font(.system(size: 12))
                    .frame(width: 64, alignment: .trailing)
                Text(L("score_whists"))
                    .foregroundColor(.white).font(.system(size: 12))
                    .frame(width: 64, alignment: .trailing)
            }
            ForEach(snap.names.indices, id: \.self) { i in
                HStack {
                    Text(snap.names[i])
                        .foregroundColor(.white).font(.system(size: 15)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(snap.pulya[i])")
                        .foregroundColor(.white).font(.system(size: 15))
                        .frame(width: 64, alignment: .trailing)
                    Text("\(snap.gora[i])")
                        .foregroundColor(.white).font(.system(size: 15))
                        .frame(width: 64, alignment: .trailing)
                    Text("\(snap.whists[i])")
                        .foregroundColor(.white).font(.system(size: 15))
                        .frame(width: 64, alignment: .trailing)
                }
                .padding(.top, 4)
            }
            Text(L("game_hint_end"))
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 12))
                .padding(.top, 10)
        }
        .padding(14)
        .background(Color(red: 0x10 / 255.0, green: 0x38 / 255.0, blue: 0x14 / 255.0).opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentGold, lineWidth: 1))
        .onTapGesture { onTap() }
    }
}
