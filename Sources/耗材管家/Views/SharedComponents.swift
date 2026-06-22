import SwiftUI

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
                Button("预设") { useCustom = false; selection = "" }.controlSize(.small).font(.caption)
            } else {
                Picker("", selection: $selection) {
                    Text("请选择").tag("")
                    ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
                }.labelsHidden()
                Button("手动") { useCustom = true }.controlSize(.small).font(.caption)
            }
        }
    }
}
