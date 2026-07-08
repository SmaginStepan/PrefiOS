import SwiftUI

/// Port of About.xaml.
struct AboutView: View {
    let versionName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("app_name"))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 16)
                Text(L("about_author")).font(.system(size: 20)).padding(.vertical, 4)
                Text(L("about_designer")).font(.system(size: 20)).padding(.vertical, 4)
                Text(LF("about_version", versionName)).font(.system(size: 20)).padding(.vertical, 4)
                Text(L("about_desc")).padding(.top, 16)
                Text(L("about_features")).padding(.top, 12)
                Text(L("about_f1")).padding(.leading, 16).padding(.top, 6)
                Text(L("about_f2")).padding(.leading, 16).padding(.top, 6)
                Text(L("about_f3")).padding(.leading, 16).padding(.top, 6)
                Text(L("about_f4")).padding(.leading, 16).padding(.top, 6)

                Link(destination: URL(string: "https://preferansmaster.com/privacy")!) {
                    Text("Privacy Policy: preferansmaster.com/privacy")
                        .font(.system(size: 15))
                        .underline()
                        .foregroundColor(Theme.accentGold)
                }
                .padding(.top, 24)
                Link(destination: URL(string: "https://preferansmaster.com/support")!) {
                    Text("Support: preferansmaster.com/support")
                        .font(.system(size: 15))
                        .underline()
                        .foregroundColor(Theme.accentGold)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Theme.background)
    }
}
