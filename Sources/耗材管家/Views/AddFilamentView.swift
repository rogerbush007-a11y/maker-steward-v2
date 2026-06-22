import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import AppKit

struct AddFilamentView: View {
    var store: FilamentStore?
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var mode = "手动"

    // 手动录入
    @State private var brand = ""
    @State private var material = ""
    @State private var color = ""
    @State private var weight = 1000
    @State private var quantity = 1
    @State private var price = ""
    @State private var alertThreshold = 200
    @State private var purchaseDate = Date()
    @State private var useCustomBrand = false
    @State private var useCustomMaterial = false
    @State private var useCustomColor = false
    @State private var customBrandText = ""
    @State private var customMaterialText = ""
    @State private var customColorText = ""
    @State private var brandImageData: Data? = nil
    @State private var errorMessage: String?

    // 截图导入
    @State private var isTargeted = false
    @State private var isLoading = false
    @State private var showResult = false
    @State private var recognizedItems: [RecognizedItem] = []
    @State private var importError: String?

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
            TrafficTitlebar(title: "新增耗材")
            Divider()

            Picker("", selection: $mode) {
                Text("手动录入").tag("手动")
                Text("截图导入").tag("导入")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if mode == "手动" {
                manualForm
            } else {
                importView
            }
        }
        .frame(width: mode == "手动" ? 420 : 540, height: mode == "手动" ? 540 : 400)
    }

    // MARK: - 手动录入

    private var manualForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    // 品牌
                    HStack {
                        Text("品牌").frame(width: 60, alignment: .leading)
                        if useCustomBrand {
                            let cbBinding = Binding<String>(get: { customBrandText }, set: {
                                customBrandText = $0
                                if !$0.isEmpty {
                                    let all = (try? modelContext.fetch(FetchDescriptor<Filament>())) ?? []
                                    let brandName = $0
                                    if let existing = all.first(where: { $0.brand == brandName && $0.imageData != nil }) {
                                        brandImageData = existing.imageData
                                    }
                                }
                            })
                            TextField("输入品牌名称", text: cbBinding).textFieldStyle(.roundedBorder)
                            Button("预设") { useCustomBrand = false; brand = "" }.controlSize(.small)
                        } else {
                            let brandBinding = Binding<String>(get: { brand }, set: { newVal in
                                brand = newVal
                                if !newVal.isEmpty {
                                    let all = (try? modelContext.fetch(FetchDescriptor<Filament>())) ?? []
                                    if let existing = all.first(where: { f in f.brand == newVal && f.imageData != nil }) {
                                        brandImageData = existing.imageData
                                    }
                                }
                            })
                            Picker("", selection: brandBinding) {
                                Text("请选择").tag("")
                                ForEach(Filament.presetBrands, id: \.self) { b in Text(b).tag(b) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                            Button("手动") { useCustomBrand = true }.controlSize(.small)
                        }
                    }

                    // 品牌图片
                    HStack {
                        Text("图").frame(width: 60, alignment: .leading)
                        Spacer()
                        ZStack {
                            if let data = brandImageData, let img = NSImage(data: data) {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(alignment: .topTrailing) {
                                        Button(action: { brandImageData = nil }) {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5))).font(.caption)
                                        }.buttonStyle(.plain).padding(2)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .frame(width: 60, height: 60)
                                    .overlay(Image(systemName: "photo.badge.plus").font(.title3).foregroundStyle(.secondary))
                            }
                            Color.clear.contentShape(Rectangle()).onTapGesture(perform: pickBrandImage)
                        }
                        .frame(width: 60, height: 60)
                        Spacer()
                    }

                    // 材质
                    HStack {
                        Text("材质").frame(width: 60, alignment: .leading)
                        if useCustomMaterial {
                            TextField("输入材质名称", text: $customMaterialText).textFieldStyle(.roundedBorder)
                            Button("预设") { useCustomMaterial = false; material = "" }.controlSize(.small)
                        } else {
                            Picker("", selection: $material) {
                                Text("请选择").tag("")
                                ForEach(Filament.presetMaterials, id: \.self) { m in Text(m).tag(m) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                            Button("手动") { useCustomMaterial = true }.controlSize(.small)
                        }
                    }

                    // 颜色
                    HStack {
                        Text("颜色").frame(width: 60, alignment: .leading)
                        if useCustomColor {
                            TextField("输入颜色名称", text: $customColorText).textFieldStyle(.roundedBorder)
                            Button("预设") { useCustomColor = false; color = "" }.controlSize(.small)
                        } else {
                            Picker("", selection: $color) {
                                Text("请选择").tag("")
                                ForEach(Filament.presetColors, id: \.self) { c in Text(c).tag(c) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                            Button("手动") { useCustomColor = true }.controlSize(.small)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // 重量
                    HStack {
                        Text("重量").frame(width: 60, alignment: .leading)
                        Picker("", selection: $weight) {
                            Text("200g").tag(200); Text("500g").tag(500); Text("1kg").tag(1000)
                            Text("2kg").tag(2000); Text("3kg").tag(3000)
                        }.labelsHidden()
                        Spacer(); Text("克").foregroundStyle(.secondary)
                    }

                    // 数量
                    HStack {
                        Text("数量").frame(width: 60, alignment: .leading)
                        Stepper(value: $quantity, in: 1...99) {
                            Text("\(quantity) 卷").frame(width: 60, alignment: .leading)
                        }
                        Spacer()
                    }

                    // 总价
                    HStack {
                        Text("总价").frame(width: 60, alignment: .leading)
                        TextField("输入总价", text: $price).textFieldStyle(.roundedBorder).frame(width: 120)
                        Spacer()
                        Text("元").foregroundStyle(.secondary)
                        if let total = Double(price), total > 0, quantity > 1 {
                            Text("（¥\(String(format: "%.2f", total / Double(quantity)))/卷）")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    // 预警线
                    HStack {
                        Text("预警").frame(width: 60, alignment: .leading)
                        Stepper(value: $alertThreshold, in: 50...1000, step: 50) {
                            Text("\(alertThreshold) 克").frame(width: 80, alignment: .leading)
                        }
                        Spacer()
                    }

                    // 购买日期
                    HStack {
                        Text("日期").frame(width: 60, alignment: .leading)
                        DatePicker("", selection: $purchaseDate, displayedComponents: .date).labelsHidden()
                        Spacer()
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
                    if let err = saveFilament() {
                        errorMessage = err
                    } else {
                        onSave?()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    // MARK: - 截图导入

    private var importView: some View {
        VStack(spacing: 16) {
            if showResult {
                importResultView
            } else {
                importDropZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importDropZone: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isTargeted ? Color.accentColor : Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial.opacity(isTargeted ? 0.7 : 0.38)))
                    .frame(height: 140)

                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("拖入订单截图，或点击下方按钮").font(.headline)
                    Text("支持淘宝、京东等平台的订单截图").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .onDrop(of: [.image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers in
                loadImage(from: providers); return true
            }

            HStack(spacing: 12) {
                Button("选择图片...") { selectImageFromFile() }.buttonStyle(.bordered)
                Button("从剪贴板粘贴") { pasteImageFromClipboard() }.buttonStyle(.bordered)
            }

            if isLoading {
                ProgressView("正在识别图片文字...")
            }
            if let error = importError {
                Text(error).foregroundStyle(.red).font(.callout).padding(.horizontal)
            }
            Spacer()
        }
    }

    private var importResultView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("从截图识别到以下耗材，请确认或修改").font(.subheadline)
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial.opacity(0.65))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($recognizedItems) { $item in
                        VStack(spacing: 8) {
                            HStack {
                                Text("耗材 \(recognizedItems.firstIndex(where: { $0.id == item.id })! + 1)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Button("-") { if item.quantity > 1 { item.quantity -= 1 } }.buttonStyle(.borderless).frame(width: 20)
                                    Text("\(item.quantity) 卷").font(.callout).frame(width: 50)
                                    Button("+") { if item.quantity < 99 { item.quantity += 1 } }.buttonStyle(.borderless).frame(width: 20)
                                }
                            }

                            PickerGroup(label: "品牌", selection: $item.brand, useCustom: $item.useCustomBrand, customText: $item.customBrand, options: Filament.presetBrands)
                            PickerGroup(label: "材质", selection: $item.material, useCustom: $item.useCustomMaterial, customText: $item.customMaterial, options: Filament.presetMaterials)
                            PickerGroup(label: "颜色", selection: $item.color, useCustom: $item.useCustomColor, customText: $item.customColor, options: Filament.presetColors)

                            HStack {
                                Text("价格").frame(width: 50, alignment: .leading).font(.callout).foregroundStyle(.secondary)
                                TextField("单价", text: $item.unitPrice).textFieldStyle(.roundedBorder).frame(width: 100)
                                Text("元").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .glassPanel(cornerRadius: 8, opacity: 0.48)
                    }

                    Button("＋ 添加一项") {
                        recognizedItems.append(RecognizedItem(brand: "", material: "", color: "", quantity: 1, unitPrice: ""))
                    }
                    .buttonStyle(.borderless).font(.callout)
                }
                .padding(16)
            }

            Divider()
            HStack {
                Button("重新选择") { showResult = false; recognizedItems = []; importError = nil }
                Spacer()
                Button("确认入库") { importItems(); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(recognizedItems.isEmpty)
            }
            .padding(16)
        }
    }
}

// MARK: - 保存与导入逻辑

extension AddFilamentView {
    private var resolvedBrand: String { useCustomBrand ? customBrandText : brand }
    private var resolvedMaterial: String { useCustomMaterial ? customMaterialText : material }
    private var resolvedColor: String { useCustomColor ? customColorText : color }

    private var canSave: Bool {
        let b = useCustomBrand ? (!customBrandText.isEmpty) : (!brand.isEmpty)
        let m = useCustomMaterial ? (!customMaterialText.isEmpty) : (!material.isEmpty)
        let c = useCustomColor ? (!customColorText.isEmpty) : (!color.isEmpty)
        return b && m && c && (Double(price) ?? 0) > 0 && quantity > 0
    }

    private func saveFilament() -> String? {
        guard let totalPrice = Double(price), totalPrice > 0 else { return "请输入有效的总价" }
        guard !resolvedBrand.isEmpty, !resolvedMaterial.isEmpty, !resolvedColor.isEmpty else { return "请填写完整信息" }
        Filament.rememberPreset(brand: resolvedBrand, material: resolvedMaterial, color: resolvedColor)
        let unitPrice = totalPrice / Double(quantity)
        for _ in 0..<quantity {
            let f = Filament(brand: resolvedBrand, material: resolvedMaterial, color: resolvedColor, weight: weight, price: unitPrice, alertThreshold: alertThreshold, purchaseDate: purchaseDate, imageData: brandImageData)
            modelContext.insert(f)
            let pr = PriceRecord(filament: f, brand: f.brand, material: f.material, color: f.color, price: unitPrice, createdAt: f.purchaseDate)
            modelContext.insert(pr)
            f.priceHistory.append(pr)
        }
        if let img = brandImageData {
            BrandImageStore.save(image: img, for: resolvedBrand)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
        return nil
    }

    private func pickBrandImage() {
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
            brandImageData = jpeg
        }
    }

    // MARK: - 导入逻辑
    private func importItems() {
        for item in recognizedItems {
            guard let price = Double(item.unitPrice), price > 0 else { continue }
            let brand = item.useCustomBrand ? item.customBrand : item.brand
            let material = item.useCustomMaterial ? item.customMaterial : item.material
            let color = item.useCustomColor ? item.customColor : item.color
            Filament.rememberPreset(brand: brand, material: material, color: color)
            for _ in 0..<item.quantity {
                let f = Filament(brand: brand.isEmpty ? "未知" : brand, material: material.isEmpty ? "PLA+" : material, color: color.isEmpty ? "其它" : color, weight: 1000, price: price, purchaseDate: .now)
                modelContext.insert(f)
                let pr = PriceRecord(filament: f, brand: f.brand, material: f.material, color: f.color, price: f.price, createdAt: .now)
                modelContext.insert(pr)
                f.priceHistory.append(pr)
            }
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
    }

    private func loadImage(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    guard let nsImage = image as? NSImage, let tiffData = nsImage.tiffRepresentation else {
                        self.importError = "无法读取图片"; return
                    }
                    self.isLoading = true; self.performOCR(imageData: tiffData)
                }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                var d: Data?
                if let url = item as? URL { d = try? Data(contentsOf: url) }
                else if let data = item as? Data { d = data }
                else if let img = item as? NSImage { d = img.tiffRepresentation }
                guard let data = d else { self.importError = "无法读取图片"; return }
                self.isLoading = true; self.performOCR(imageData: data)
            }
        }
    }

    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else {
                self.importError = "无法读取图片文件"; return
            }
            self.isLoading = true; self.importError = nil; self.performOCR(imageData: data)
        }
    }

    private func pasteImageFromClipboard() {
        guard let img = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
              let d = img.tiffRepresentation else { importError = "剪贴板中没有图片"; return }
        isLoading = true; importError = nil; performOCR(imageData: d)
    }

    private func performOCR(imageData: Data) {
        let tmpURL = AppPaths.ocrTempFile("filament_ocr_input.png")
        try? imageData.write(to: tmpURL)
        guard let toolPath = AppPaths.ocrToolPath else {
            isLoading = false; importError = "OCR 工具未找到"; return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: toolPath)
            proc.arguments = [tmpURL.path]
            let out = Pipe()
            proc.standardOutput = out
            proc.standardError = Pipe()
            do {
                try proc.run(); proc.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                guard proc.terminationStatus == 0, let str = String(data: data, encoding: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: str.data(using: .utf8)!) as? [String: String],
                      json["error"] == nil, let text = json["text"], !text.isEmpty else {
                    DispatchQueue.main.async { self.isLoading = false; self.importError = "OCR 识别失败" }; return
                }
                DispatchQueue.main.async { self.parseOrderText(text) }
            } catch {
                DispatchQueue.main.async { self.isLoading = false; self.importError = "OCR 出错: \(error.localizedDescription)" }
            }
        }
    }

    private func parseOrderText(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let knownBrands = Filament.presetBrands + ["Bambu", "TINMORRY", "Flashforge", "拓竹", "易生", "天瑞", "闪铸", "三绿", "金丝"]
        let knownMaterials = Filament.presetMaterials + ["PLA+", "PLA", "PETG", "TPU", "ABS", "ASA", "PA", "PC", "PVA", "HIPS", "尼龙", "碳纤"]
        var items: [RecognizedItem] = []
        var seenKeys = Set<String>()
        for index in lines.indices {
            let context = nearbyText(lines, index: index)
            let matchedBrand = bestMatch(in: context, candidates: knownBrands)
            let matchedMaterial = bestMatch(in: context, candidates: knownMaterials)
            guard matchedBrand != nil || matchedMaterial != nil ||
                  context.localizedCaseInsensitiveContains("耗材") ||
                  context.localizedCaseInsensitiveContains("打印") ||
                  context.localizedCaseInsensitiveContains("线材") ||
                  context.localizedCaseInsensitiveContains("filament") else { continue }
            let prices = extractPrices(from: context).filter { $0 >= 5 && $0 <= 2000 }
            let quantity = extractQuantity(from: context)
            let color = bestMatch(in: context, candidates: Filament.presetColors) ?? "丝绸银"
            let brandValue = matchedBrand ?? "eSun"
            let materialValue = matchedMaterial ?? "PLA+"
            let priceValue = prices.last.map { String(format: "%.2f", $0) } ?? ""
            let key = "\(brandValue)|\(materialValue)|\(color)|\(priceValue)|\(quantity)"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            items.append(RecognizedItem(brand: brandValue, material: materialValue, color: color, quantity: quantity, unitPrice: priceValue))
        }
        if items.isEmpty { items.append(RecognizedItem(brand: "eSun", material: "PLA+", color: "丝绸银", quantity: 1, unitPrice: "")) }
        // 提取总价
        for line in lines {
            if line.localizedCaseInsensitiveContains("合计") || line.localizedCaseInsensitiveContains("总额") || line.localizedCaseInsensitiveContains("实付") {
                if let t = extractPrices(from: line).first { _ = t }
            }
        }
        recognizedItems = items; showResult = true; isLoading = false
    }

    private func extractPrices(from line: String) -> [Double] {
        let p = try? NSRegularExpression(pattern: "(?:¥|￥|CNY|RMB)?\\s*\\d+(?:[\\.,]\\d{1,2})?")
        return (p?.matches(in: line, range: NSRange(line.startIndex..., in: line)) ?? []).compactMap { m -> Double? in
            guard let r = Range(m.range, in: line) else { return nil }
            let cleaned = line[r]
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: "￥", with: "")
                .replacingOccurrences(of: "CNY", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "RMB", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            return Double(cleaned)
        }
    }

    private func extractQuantity(from line: String) -> Int {
        let p = try? NSRegularExpression(pattern: "\\d+[枚卷个件]")
        guard let m = p?.matches(in: line, range: NSRange(line.startIndex..., in: line)).first, let r = Range(m.range, in: line) else { return 1 }
        return Int(line[r].trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) ?? 1
    }

    private func nearbyText(_ lines: [String], index: Int) -> String {
        let start = max(lines.startIndex, index - 1)
        let end = min(lines.index(before: lines.endIndex), index + 2)
        return lines[start...end].joined(separator: " ")
    }

    private func bestMatch(in text: String, candidates: [String]) -> String? {
        candidates
            .filter { !$0.isEmpty && text.localizedCaseInsensitiveContains($0) }
            .sorted { $0.count > $1.count }
            .first
    }
}
