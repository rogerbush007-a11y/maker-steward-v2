import SwiftUI
import UniformTypeIdentifiers
import Vision

/// 耗材导入 → 识别 → 确认 → 入库
struct ImportView: View {
    var store: FilamentStore?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isTargeted = false
    @State private var isLoading = false
    @State private var showResult = false
    @State private var errorMessage: String?

    @State private var recognizedItems: [RecognizedItem] = []
    @State private var orderTotal = ""

    struct RecognizedItem: Identifiable {
        let id = UUID()
        var brand: String
        var material: String
        var color: String
        var quantity: Int
        var unitPrice: String
        var useCustomBrand = false
        var useCustomMaterial = false
        var useCustomColor = false
        var customBrand = ""
        var customMaterial = ""
        var customColor = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "耗材导入")
            Divider()

            if showResult {
                resultView
            } else {
                dropZoneView
            }
        }
        .frame(width: 540, height: showResult ? 520 : 320)
    }

    // MARK: - 拖拽区域

    private var dropZoneView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                    )
                    .frame(height: 140)

                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("拖入订单截图，或点击下方按钮")
                        .font(.headline)
                    Text("支持淘宝、京东等平台的订单截图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .onDrop(of: [.image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers in
                loadImage(from: providers)
                return true
            }

            HStack(spacing: 12) {
                Button("选择图片...") { selectImageFromFile() }
                    .buttonStyle(.bordered)
                Button("从剪贴板粘贴") { pasteImageFromClipboard() }
                    .buttonStyle(.bordered)
            }

            if isLoading {
                ProgressView("正在识别图片文字...")
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - 识别结果确认

    private var resultView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("从截图识别到以下耗材，请确认或修改")
                    .font(.subheadline)
                Spacer()
            }
            .padding(12)
            .background(Color.green.opacity(0.08))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($recognizedItems) { $item in
                        VStack(spacing: 8) {
                            // 标题行 + 数量
                            HStack {
                                Text("耗材 \(recognizedItems.firstIndex(where: { $0.id == item.id })! + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Button("-") {
                                        if item.quantity > 1 { item.quantity -= 1 }
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(width: 20)

                                    Text("\(item.quantity) 卷")
                                        .font(.callout)
                                        .frame(width: 50)

                                    Button("+") {
                                        if item.quantity < 99 { item.quantity += 1 }
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(width: 20)
                                }
                            }

                            // 品牌
                            PickerGroup(
                                label: "品牌",
                                selection: $item.brand,
                                useCustom: $item.useCustomBrand,
                                customText: $item.customBrand,
                                options: Filament.presetBrands
                            )

                            // 材质
                            PickerGroup(
                                label: "材质",
                                selection: $item.material,
                                useCustom: $item.useCustomMaterial,
                                customText: $item.customMaterial,
                                options: Filament.presetMaterials
                            )

                            // 颜色
                            PickerGroup(
                                label: "颜色",
                                selection: $item.color,
                                useCustom: $item.useCustomColor,
                                customText: $item.customColor,
                                options: Filament.presetColors
                            )

                            // 价格
                            HStack {
                                Text("价格").frame(width: 50, alignment: .leading)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                TextField("单价", text: $item.unitPrice)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                Text("元")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button("＋ 添加一项") {
                        recognizedItems.append(RecognizedItem(
                            brand: "", material: "", color: "",
                            quantity: 1, unitPrice: ""
                        ))
                    }
                    .buttonStyle(.borderless)
                    .font(.callout)

                    Divider()

                    HStack {
                        Text("订单总价:").foregroundStyle(.secondary)
                        TextField("选填", text: $orderTotal)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Spacer()
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button("重新选择") {
                    showResult = false
                    recognizedItems = []
                    errorMessage = nil
                }
                Spacer()
                Button("确认入库") {
                    importItems()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(recognizedItems.isEmpty)
            }
            .padding(16)
        }
    }
}

// MARK: - 图片加载和 OCR

extension ImportView {
    private func loadImage(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "读取失败: \(error.localizedDescription)"
                        return
                    }
                    guard let nsImage = image as? NSImage,
                          let tiffData = nsImage.tiffRepresentation else {
                        self.errorMessage = "无法读取图片"
                        return
                    }
                    self.isLoading = true
                    self.performOCR(imageData: tiffData)
                }
            }
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "读取失败: \(error.localizedDescription)"
                    return
                }
                var imageData: Data?
                if let url = item as? URL { imageData = try? Data(contentsOf: url) }
                else if let data = item as? Data { imageData = data }
                else if let image = item as? NSImage { imageData = image.tiffRepresentation }

                guard let data = imageData else {
                    self.errorMessage = "无法读取图片"
                    return
                }
                self.isLoading = true
                self.performOCR(imageData: data)
            }
        }
    }

    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let data = try? Data(contentsOf: url) else {
                self.errorMessage = "无法读取图片文件"
                return
            }
            self.isLoading = true
            self.errorMessage = nil
            self.performOCR(imageData: data)
        }
    }

    private func pasteImageFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
              let tiffData = image.tiffRepresentation else {
            errorMessage = "剪贴板中没有图片"
            return
        }
        isLoading = true
        errorMessage = nil
        performOCR(imageData: tiffData)
    }

    // MARK: - OCR（调用独立工具）

    private func performOCR(imageData: Data) {
        let tmpURL = AppPaths.ocrTempFile("filament_ocr_input.png")
        try? imageData.write(to: tmpURL)

        guard let toolPath = AppPaths.ocrToolPath else {
            isLoading = false; errorMessage = "OCR 工具未找到"; return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: toolPath)
            process.arguments = [tmpURL.path]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0,
                      let outputStr = String(data: outputData, encoding: .utf8),
                      let jsonData = outputStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
                      json["error"] == nil,
                      let text = json["text"], !text.isEmpty else {
                    DispatchQueue.main.async { self.isLoading = false; self.errorMessage = "OCR 识别失败" }
                    return
                }

                DispatchQueue.main.async { self.parseOrderText(text) }
            } catch {
                DispatchQueue.main.async { self.isLoading = false; self.errorMessage = "OCR 出错: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - 订单文字解析

    private func parseOrderText(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let knownBrands = ["Bambu Lab", "Bambu", "eSun", "Polymaker", "Sunlu", "Elegoo", "Anycubic", "Creality", "天瑞", "闪铸", "三绿", "金丝"]
        let knownMaterials = ["PLA+", "PLA", "PETG", "TPU", "ABS", "ASA", "PA", "PC", "PVA", "HIPS", "尼龙", "碳纤"]

        var items: [RecognizedItem] = []

        for line in lines {
            let matchedBrand = knownBrands.first { line.localizedCaseInsensitiveContains($0) }
            let matchedMaterial = knownMaterials.first { line.localizedCaseInsensitiveContains($0) }

            guard matchedBrand != nil || matchedMaterial != nil ||
                  line.localizedCaseInsensitiveContains("耗材") ||
                  line.localizedCaseInsensitiveContains("打印") ||
                  line.localizedCaseInsensitiveContains("线材") else { continue }

            let prices = extractPrices(from: line)
            let quantity = extractQuantity(from: line)

            items.append(RecognizedItem(
                brand: matchedBrand ?? "eSun",
                material: matchedMaterial ?? "PLA+",
                color: "丝绸银",
                quantity: quantity,
                unitPrice: prices.first.map { String(format: "%.0f", $0) } ?? ""
            ))

            // 额外：尝试提取颜色关键词
            let knownColors = Filament.presetColors
            if let matchedColor = knownColors.first(where: { line.localizedCaseInsensitiveContains($0) }) {
                items[items.count - 1].color = matchedColor
            }
        }

        // 如果完全没识别到，给一个空条目让用户自己填
        if items.isEmpty {
            items.append(RecognizedItem(brand: "eSun", material: "PLA+", color: "丝绸银", quantity: 1, unitPrice: ""))
        }

        // 尝试提取订单总价
        for line in lines {
            if line.localizedCaseInsensitiveContains("合计") || line.localizedCaseInsensitiveContains("总额") || line.localizedCaseInsensitiveContains("实付") {
                if let total = extractPrices(from: line).first {
                    orderTotal = String(format: "%.0f", total)
                }
            }
        }

        recognizedItems = items
        showResult = true
        isLoading = false
    }

    private func extractPrices(from line: String) -> [Double] {
        let pattern = try? NSRegularExpression(pattern: "[¥￥]?\\d+[\\.]?\\d*")
        let matches = pattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) ?? []
        return matches.compactMap { m -> Double? in
            guard let range = Range(m.range, in: line) else { return nil }
            let str = line[range].replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: "￥", with: "")
            return Double(str)
        }
    }

    private func extractQuantity(from line: String) -> Int {
        let pattern = try? NSRegularExpression(pattern: "\\d+[枚卷个件]")
        let matches = pattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) ?? []
        if let match = matches.first, let range = Range(match.range, in: line) {
            let digits = line[range].trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
            return Int(digits) ?? 1
        }
        return 1
    }

    // MARK: - 入库

    private func importItems() {
        for item in recognizedItems {
            guard let price = Double(item.unitPrice), price > 0 else { continue }
            let brand = item.useCustomBrand ? item.customBrand : item.brand
            let material = item.useCustomMaterial ? item.customMaterial : item.material
            let color = item.useCustomColor ? item.customColor : item.color

            for _ in 0..<item.quantity {
                let filament = Filament(
                    brand: brand.isEmpty ? "未知" : brand,
                    material: material.isEmpty ? "PLA+" : material,
                    color: color.isEmpty ? "其它" : color,
                    weight: 1000,
                    price: price,
                    purchaseDate: .now
                )
                modelContext.insert(filament)
                let pr = PriceRecord(filament: filament, brand: filament.brand, material: filament.material, color: filament.color, price: filament.price, createdAt: .now)
                modelContext.insert(pr)
                filament.priceHistory.append(pr)
            }
        }
        try? modelContext.save()
    }
}
