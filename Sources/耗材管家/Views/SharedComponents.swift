import SwiftUI

func parsedGramInput(_ text: String) -> Int? {
    let normalized = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "，", with: ".")
        .replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: "克", with: "")
        .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
    guard let value = Double(normalized), value > 0 else { return nil }
    return max(1, Int(value.rounded()))
}

// MARK: - 下拉选择 + 手动输入组件

struct PickerGroup: View {
    let label: String
    @Binding var selection: String
    @Binding var useCustom: Bool
    @Binding var customText: String
    let options: [String]

    var body: some View {
        HStack {
            Text(label).frame(width: 50, alignment: .leading).font(.callout).foregroundStyle(.secondary)
            if useCustom {
                TextField("输入\(label)", text: $customText).textFieldStyle(.roundedBorder)
                if label == "颜色" {
                    colorMenu { customText = $0 }
                }
                Button("预设") { useCustom = false; selection = "" }.controlSize(.small).font(.caption)
            } else {
                Picker("", selection: $selection) {
                    Text("请选择").tag("")
                    ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
                }.labelsHidden()
                if label == "颜色" {
                    colorMenu { selection = $0 }
                }
                Button("手动") { useCustom = true }.controlSize(.small).font(.caption)
            }
        }
    }

    private func colorMenu(onSelect: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(Filament.presetColors, id: \.self) { colorName in
                Button {
                    onSelect(colorName)
                } label: {
                    Label(colorName, systemImage: "circle.fill")
                }
            }
        } label: {
            Image(systemName: "paintpalette")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("色盘")
    }
}
