import SwiftUI
import PrefEngine

/// Port of Calc.xaml: the score-sheet section menu.
struct CalcMenuView: View {
    let calc: Calculation?
    let onLoad: () -> Void
    let onNew3: () -> Void
    let onNew4: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("calc_title"))
                .font(.system(size: 40))
                .foregroundColor(Theme.accentGold)
                .padding(.bottom, 24)
            MenuItem(title: L("calc_load"), subtitle: L("calc_load_sub"), onClick: onLoad)
            MenuItem(title: L("calc_3p"), subtitle: L("calc_3p_sub"), onClick: onNew3)
            MenuItem(title: L("calc_4p"), subtitle: L("calc_4p_sub"), onClick: onNew4)
            if calc != nil {
                MenuItem(title: L("calc_continue"), subtitle: L("calc_continue_sub"), onClick: onContinue)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Theme.background)
    }
}
