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
    @State private var showColorPalette = false

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
        Button {
            showColorPalette.toggle()
        } label: {
            Image(systemName: "paintpalette")
        }
        .buttonStyle(.borderless)
        .help("色盘")
        .popover(isPresented: $showColorPalette, arrowEdge: .bottom) {
            ColorPaletteGrid { colorName in
                onSelect(colorName)
                showColorPalette = false
            }
        }
    }
}

struct ColorPaletteGrid: View {
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择颜色")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Filament.presetColors, id: \.self) { colorName in
                    Button {
                        onSelect(colorName)
                    } label: {
                        VStack(spacing: 4) {
                            ColorSwatch(colorName, size: 28)
                            Text(colorName)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(width: 34)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(colorName)
                }
            }
        }
        .padding(12)
        .frame(width: 270)
    }
}
