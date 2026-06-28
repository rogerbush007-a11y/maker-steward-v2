import SwiftUI
import AppKit

struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPresetBrand = "Bambu Lab"
    @State private var selectedModel = "X1C"
    @State private var useCustomBrand = false
    @State private var customBrand = ""
    @State private var useCustomModel = false
    @State private var customModel = ""
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var notes = ""
    @State private var imageData: Data? = nil
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "新增设备")
            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    // 品牌
                    HStack {
                        Text("品牌").frame(width: 60, alignment: .leading)
                        if useCustomBrand {
                            TextField("输入品牌", text: $customBrand).textFieldStyle(.roundedBorder)
                            Button("预设") { useCustomBrand = false; selectedPresetBrand = "" }.controlSize(.small)
                        } else {
                            Picker("", selection: $selectedPresetBrand) {
                                ForEach(Device.presetBrands, id: \.brand) { item in
                                    Text(item.brand).tag(item.brand)
                                }
                            }
                            .labelsHidden()
                            Button("手动") { useCustomBrand = true }.controlSize(.small)
                        }
                    }

                    // 型号
                    HStack {
                        Text("型号").frame(width: 60, alignment: .leading)
                        if useCustomModel {
                            TextField("输入型号", text: $customModel).textFieldStyle(.roundedBorder)
                            Button("预设") { useCustomModel = false; selectedModel = "" }.controlSize(.small)
                        } else {
                            let models = brandModels
                            ModelPopUp(selection: $selectedModel, models: models)
                                .frame(maxWidth: .infinity, minHeight: 22)
                                .disabled(models.isEmpty)
                            Button("手动") { useCustomModel = true }.controlSize(.small)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // 购入日期
                    HStack {
                        Text("日期").frame(width: 60, alignment: .leading)
                        DatePicker("", selection: $purchaseDate, displayedComponents: .date).labelsHidden()
                        Spacer()
                    }

                    // 购入价格
                    HStack {
                        Text("价格").frame(width: 60, alignment: .leading)
                        TextField("购入价格", text: $purchasePrice).textFieldStyle(.roundedBorder).frame(width: 120)
                        Spacer()
                        Text("元").foregroundStyle(.secondary)
                    }

                    // 备注
                    HStack(alignment: .top) {
                        Text("备注").frame(width: 60, alignment: .leading)
                        TextField("选填", text: $notes).textFieldStyle(.roundedBorder)
                    }

                    // 图片
                    VStack(spacing: 4) {
                        HStack {
                            Text("图片").frame(width: 60, alignment: .leading)
                            Spacer()
                            ZStack {
                                if let data = imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                                        .overlay(alignment: .topTrailing) {
                                            Button(action: { imageData = nil }) {
                                                Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5))).font(.caption)
                                            }.buttonStyle(.plain).padding(2)
                                        }
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .frame(width: 80, height: 80)
                                        .overlay(Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary))
                                }
                                Color.clear.contentShape(Rectangle()).onTapGesture(perform: pickImage)
                            }
                            .frame(width: 80, height: 80)
                            Spacer()
                        }
                    }

                    if let error = errorMessage {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
                .padding(20)
            }

            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("保存") {
                    if let err = validateAndSave() {
                        errorMessage = err
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 380, height: 440)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url, let nsImage = NSImage(contentsOf: url),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let w = cgImage.width, h = cgImage.height
            let size = min(w, h)
            guard let cropped = cgImage.cropping(to: CGRect(x: (w - size) / 2, y: (h - size) / 2, width: size, height: size)) else { return }
            let finalSize: CGFloat = 400
            let result = NSImage(size: NSSize(width: finalSize, height: finalSize))
            result.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: finalSize, height: finalSize).fill()
            let img = NSImage(cgImage: cropped, size: NSSize(width: size, height: size))
            img.draw(in: NSRect(x: 0, y: 0, width: finalSize, height: finalSize))
            result.unlockFocus()
            guard let tiff = result.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
            imageData = jpeg
        }
    }

    private var resolvedBrand: String { useCustomBrand ? customBrand : selectedPresetBrand }
    private var resolvedModel: String { useCustomModel ? customModel : selectedModel }

    private var brandModels: [String] {
        if useCustomBrand { return [] }
        return Device.presetBrands.first(where: { $0.brand == selectedPresetBrand })?.models ?? []
    }

    private var canSave: Bool {
        let b = useCustomBrand ? (!customBrand.isEmpty) : (!selectedPresetBrand.isEmpty)
        let m = useCustomModel ? (!customModel.isEmpty) : (!selectedModel.isEmpty && selectedModel != "自定义")
        return b && m && (Double(purchasePrice) ?? 0) > 0
    }

    private func validateAndSave() -> String? {
        guard let price = Double(purchasePrice), price > 0 else { return "请输入有效的购入价格" }
        let brand = resolvedBrand.trimmingCharacters(in: .whitespaces)
        let model = resolvedModel.trimmingCharacters(in: .whitespaces)
        guard !brand.isEmpty else { return "请选择或输入品牌" }
        guard !model.isEmpty else { return "请选择或输入型号" }

        let device = Device(
            brand: brand,
            model: model,
            purchaseDate: purchaseDate,
            purchasePrice: price,
            notes: notes,
            imageData: imageData
        )
        modelContext.insert(device)
        try? modelContext.save()
        NotificationCenter.default.post(name: .filamentDataChanged, object: nil)
        return nil
    }
}


// MARK: - macOS 原生下拉菜单（支持大量选项）
struct ModelPopUp: NSViewRepresentable {
    @Binding var selection: String
    let models: [String]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let btn = NSPopUpButton(frame: .zero, pullsDown: false)
        btn.addItems(withTitles: models)
        btn.target = context.coordinator
        btn.action = #selector(Coordinator.changed)
        return btn
    }

    func updateNSView(_ btn: NSPopUpButton, context: Context) {
        let current = btn.itemTitles
        if current != models {
            btn.removeAllItems()
            btn.addItems(withTitles: models)
        }
        btn.selectItem(withTitle: selection)
    }

    class Coordinator: NSObject {
        let parent: ModelPopUp
        init(_ p: ModelPopUp) { parent = p }
        @objc func changed(_ sender: NSPopUpButton) {
            parent.selection = sender.titleOfSelectedItem ?? ""
        }
    }
}
