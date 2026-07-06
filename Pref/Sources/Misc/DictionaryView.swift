import SwiftUI

private struct DictItem {
    let word: String
    let description: String
}

private func loadDictionary() -> [DictItem] {
    guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "txt"),
          let bytes = try? Data(contentsOf: url) else {
        return []
    }
    // The original file is UTF-16 ("Encoding.Unicode"); detect BOM.
    let text: String
    if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        text = String(data: bytes.dropFirst(2), encoding: .utf16LittleEndian) ?? ""
    } else if bytes.count >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        text = String(data: bytes.dropFirst(2), encoding: .utf16BigEndian) ?? ""
    } else {
        text = String(data: bytes, encoding: .utf16LittleEndian) ?? ""
    }
    return text.replacingOccurrences(of: "\r", with: " ")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .compactMap { line in
            let w = line.split(separator: "=", omittingEmptySubsequences: false)
            guard w.count == 2 else { return nil }
            return DictItem(word: String(w[0]).uppercased(), description: String(w[1]))
        }
}

private func formatDescription(_ description: String) -> String {
    var d = description
    if d.hasPrefix("1.") {
        for i in 2...9 {
            d = d.replacingOccurrences(of: "\(i).", with: "\n\(i).")
        }
    }
    d = d.replacingOccurrences(of: "Этимология", with: "\nЭтимология")
    return d
}

/// Port of Dictionary.xaml.cs: search the glossary of Preferans terms.
struct DictionaryView: View {
    @State private var dict: [DictItem] = []
    @State private var search = ""

    private var results: [DictItem] {
        let s = search.uppercased()
        if s.isEmpty {
            return []
        }
        return Array(dict.filter { $0.word.hasPrefix(s) }.sorted { $0.word < $1.word }.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("dict_title"))
                .font(.system(size: 40))
                .foregroundColor(Theme.accentGold)
                .padding(.bottom, 16)
            TextField(L("dict_search"), text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                        Text(item.word)
                            .font(.system(size: 20))
                            .padding(.top, 10)
                        Text(formatDescription(item.description))
                            .font(.system(size: 15))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .onAppear {
            if dict.isEmpty {
                dict = loadDictionary()
            }
        }
    }
}
