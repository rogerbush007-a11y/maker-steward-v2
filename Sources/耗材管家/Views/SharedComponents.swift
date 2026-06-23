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
                    colorMenu(customName: customText) { customText = $0 }
                }
                Button("预设") { useCustom = false; selection = "" }.controlSize(.small).font(.caption)
            } else {
                Picker("", selection: $selection) {
                    Text("请选择").tag("")
                    ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
                }.labelsHidden()
                if label == "颜色" {
                    colorMenu(customName: "") { selection = $0 }
                }
                Button("手动") { useCustom = true }.controlSize(.small).font(.caption)
            }
        }
    }

    private func colorMenu(customName: String, onSelect: @escaping (String) -> Void) -> some View {
        Button {
            showColorPalette.toggle()
        } label: {
            Image(systemName: "paintpalette")
        }
        .buttonStyle(.borderless)
        .help("色盘")
        .popover(isPresented: $showColorPalette, arrowEdge: .bottom) {
            ColorPaletteGrid(customName: customName) { colorName in
                onSelect(colorName)
                showColorPalette = false
            } onCustomColor: { name, color in
                Filament.rememberCustomColor(name: name, color: color)
                onSelect(name)
                showColorPalette = false
            }
        }
    }
}

struct ColorPaletteGrid: View {
    let customName: String
    let onSelect: (String) -> Void
    let onCustomColor: (String, Color) -> Void
    @State private var customColor: Color = .orange
    @State private var deleteCandidate: String?
    @State private var paletteRefreshID = UUID()

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 8), count: 6)
    private var trimmedCustomName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择颜色")
                .font(.headline)
            HStack(spacing: 10) {
                ColorPicker("自定义", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 40)
                RoundedRectangle(cornerRadius: 4)
                    .fill(customColor)
                    .frame(width: 34, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                Button("使用自定义颜色") {
                    onCustomColor(trimmedCustomName, customColor)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(trimmedCustomName.isEmpty)
            }
            if trimmedCustomName.isEmpty {
                Text("先输入颜色名称，再点选颜色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("将颜色保存为「\(trimmedCustomName)」")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
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
                    .contextMenu {
                        if Filament.isCustomColor(colorName) {
                            Button("删除自定义颜色", role: .destructive) {
                                deleteCandidate = colorName
                            }
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.6) {
                        if Filament.isCustomColor(colorName) {
                            deleteCandidate = colorName
                        }
                    }
                }
            }
            .id(paletteRefreshID)
        }
        .padding(12)
        .frame(width: 300)
        .alert("删除自定义颜色？", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let deleteCandidate {
                    Filament.forgetCustomColor(deleteCandidate)
                    paletteRefreshID = UUID()
                }
                deleteCandidate = nil
            }
            Button("取消", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            Text(deleteCandidate.map { "将从预设中删除「\($0)」，已记录的耗材名称不会被改动。" } ?? "")
        }
    }
}
