import SwiftUI

/// Port of CalcHelp.xaml.
struct CalcHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("help_title"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 4)
                Text(L("help_q")).font(.system(size: 20))
                Text(L("help_tap"))
                Text(LF("help_record", L("sheet_record")))
                Text(LF("help_calc", L("sheet_calc")))
                Text(LF("help_save", L("sheet_save")))
                Text(L("help_dealer"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Theme.background)
    }
}
