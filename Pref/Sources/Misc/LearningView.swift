import SwiftUI

/// Picks the course resource for the app's current language (ru is the original file).
private func courseResourceName(_ name: String) -> String {
    let language = Bundle.main.preferredLocalizations.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    switch language {
    case "ru": return name
    case "es": return "\(name)_es"
    default: return "\(name)_en"
    }
}

/// Loads the tutorial course (DataContract XML): a sequence of <Text> stages.
private func loadCourse(_ name: String) -> [String] {
    guard let url = Bundle.main.url(forResource: courseResourceName(name), withExtension: "xml"),
          let data = try? Data(contentsOf: url) else {
        return []
    }
    let parser = CourseParser()
    let xml = XMLParser(data: data)
    xml.delegate = parser
    xml.parse()
    return parser.stages
}

private final class CourseParser: NSObject, XMLParserDelegate {
    var stages: [String] = []
    private var current: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if elementName == "Text" {
            current = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil {
            current! += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "Text", let text = current {
            stages.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
            current = nil
        }
    }
}

/// Port of Learning.xaml.cs: paged tutorial course.
struct LearningView: View {
    let onFinished: () -> Void

    @State private var stages: [String] = []
    @State private var position = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("learn_title"))
                .font(.system(size: 40))
                .foregroundColor(Theme.accentGold)
                .padding(.bottom, 12)
            ScrollView {
                if !stages.isEmpty {
                    Text(stages[position - 1])
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Button {
                    position -= 1
                } label: {
                    Text(L("learn_prev"))
                }
                .buttonStyle(.bordered)
                .disabled(position <= 1)
                Spacer()
                Text("\(position)/\(stages.count)")
                Spacer()
                Button {
                    if position == stages.count {
                        onFinished()
                    } else {
                        position += 1
                    }
                } label: {
                    Text(L(position == stages.count ? "learn_end" : "learn_next"))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 12)
        }
        .padding(24)
        .background(Theme.background)
        .onAppear {
            if stages.isEmpty {
                stages = loadCourse("tutorial")
            }
        }
    }
}
