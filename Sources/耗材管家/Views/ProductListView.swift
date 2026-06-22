import SwiftUI
import SwiftData
import Charts
import Vision
import CoreImage

/// 产品分组（按名称+颜色）
struct ProductGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let color: String
    var products: [Product]

    var totalStock: Int { products.reduce(0) { $0 + $1.stock } }
    var totalSales: Int { products.reduce(0) { $0 + $1.sales.count } }
    var needsReorder: Bool { products.contains(where: \.needsReorder) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ProductGroup, rhs: ProductGroup) -> Bool { lhs.id == rhs.id }
}

struct ProductListView: View {
    @Binding var selectedProduct: Product?
    @Environment(\.modelContext) private var modelContext

    @State private var products: [Product] = []
    @State private var searchText = ""
    @State private var editingProduct: Product?

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showAddProduct = true }) {
                Label("新增", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.small)
            .padding(.horizontal, 12).padding(.vertical, 6)
            toolbar
            Divider()
            searchBar
            Divider()
            productList
        }
        .background(.thinMaterial.opacity(0.24))
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("filamentDataChanged"))) { _ in refresh() }
        .sheet(isPresented: $showAddProduct) {
            AddProductView()
        }
    }

    private func refresh() {
        let fd = FetchDescriptor<Product>()
        products = (try? modelContext.fetch(fd)) ?? []
    }

    @State private var showAddProduct = false

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(Localized.str("产品列表")).font(.body).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField("搜索产品...", text: $searchText).textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.color.localizedCaseInsensitiveContains(searchText) }
    }

    private var productList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredProducts) { product in
                    ProductRow(product: product, isSelected: selectedProduct?.id == product.id)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedProduct = product }
                        .contextMenu {
                            Button("编辑") { editingProduct = product }
                        }
                    Divider().padding(.leading, 24)
                }
            }
        }
        .sheet(item: $editingProduct) { product in
            EditProductView(product: product)
        }
    }
}

struct ProductRow: View {
    let product: Product
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if let data = product.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22).clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    ColorSwatch(product.color, size: 12)
                }
                Text(product.name).font(.body).fontWeight(.medium).lineLimit(1)
                if product.needsReorder {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                Text(product.color).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("库存\(product.stock)").font(.caption)
                    .foregroundStyle(product.needsReorder ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("售\(product.sales.count)").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 6)
    }
}

// MARK: - 产品详情

struct ProductDetailView: View {
    let product: Product
    @Environment(\.modelContext) private var modelContext
    @State private var showSaleSheet = false
    @State private var saleQty = 1
    @State private var salePrice = ""
    @State private var saleBuyer = ""
    @State private var saleShipping = ""
    @State private var salePackaging = ""
    @State private var saleCommission = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 预警
                if product.needsReorder {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("库存仅剩 \(product.stock) 个，低于预警线 \(product.effectiveThreshold)（周均 \(Int(round(product.weeklySalesAverage)))）").font(.callout).foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 标题 + 图片（左侧大图，同设备页风格）
                HStack(alignment: .top, spacing: 16) {
                    if let data = product.imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name).font(.title2).fontWeight(.semibold)
                        if !product.color.isEmpty {
                            HStack(spacing: 4) {
                                ColorSwatch(product.color, size: 12)
                                Text(product.color).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        if !product.specs.isEmpty {
                            Text("规格: \(product.specs)").font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            productStatusBadge
                            Button("售出") { showSaleSheet = true }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
                    Spacer()
                }
                .frame(minHeight: 120)

                Divider()

                // 统计卡片（2列，同设备页风格）
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatCard(value: "\(product.stock)", label: "库存")
                    StatCard(value: "¥\(String(format: "%.0f", product.price))", label: "售价")
                    StatCard(value: "¥\(String(format: "%.1f", product.costPerUnit))", label: "单件成本")
                    StatCard(value: "¥\(String(format: "%.2f", product.price - product.costPerUnit))", label: "单件毛利")
                    StatCard(value: product.sales.isEmpty ? "暂无" : "\(product.sales.count)次", label: "已售")
                }

                Divider()

                // 销售统计
                if !product.sales.isEmpty {
                    let totalSold = product.sales.reduce(0) { $0 + $1.quantity }
                    let totalRevenue = product.sales.reduce(0.0) { $0 + $1.revenue }
                    let totalCost = product.sales.reduce(0.0) { $0 + Double($1.quantity) * product.costPerUnit + $1.shippingCost + $1.packagingCost + $1.platformFee }
                    let totalProfit = totalRevenue - totalCost
                    let margin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0

                    GroupBox("销售汇总") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("累计售出").font(.caption).foregroundStyle(.secondary)
                                Text("\(totalSold) 个").font(.title3).fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("总收入").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.2f", totalRevenue))").font(.title3).fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("总利润").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.2f", totalProfit))")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundStyle(totalProfit >= 0 ? .green : .red)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("利润率").font(.caption).foregroundStyle(.secondary)
                                Text("\(String(format: "%.1f", margin))%")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundStyle(margin >= 0 ? .green : .red)
                            }
                        }
                        .padding(4)
                    }

                    // 周销售数量趋势
                    let qtyData = productSalesWeeklyQty()
                    if !qtyData.isEmpty {
                        GroupBox("周销售数量") {
                            Chart(qtyData, id: \.0) { item in
                                LineMark(x: .value("日期", item.0), y: .value("数量", item.1))
                                    .foregroundStyle(.green.gradient).lineStyle(StrokeStyle(lineWidth: 2))
                                PointMark(x: .value("日期", item.0), y: .value("数量", item.1))
                                    .foregroundStyle(.green).symbolSize(20)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.weekday().day())
                                }
                            }
                            .chartYAxisLabel("个")
                            .frame(height: 100)
                            .padding(.top, 4)
                        }
                    }
                }

                Divider()

                // 售出记录
                if product.sales.isEmpty {
                    Text("暂无售出记录").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Text("售出记录").font(.headline)
                    ForEach(product.sales.sorted(by: { $0.createdAt > $1.createdAt })) { sale in
                        HStack {
                            Text(sale.createdAt.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                            Text("\(sale.quantity) 个").font(.callout).fontWeight(.medium)
                            Text("¥\(String(format: "%.2f", Double(sale.quantity) * sale.salePrice))").font(.callout)
                            Text(sale.buyer.isEmpty ? "" : "· \(sale.buyer)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        Divider()
                    }
                }
                Spacer()
            }
            .padding(24)
        }
        .background(.clear)
        .sheet(isPresented: $showSaleSheet) {
            saleSheet
        }
    }

    private var saleSheet: some View {
        VStack(spacing: 14) {
            Text("记录售出").font(.headline).padding(.bottom, 4)

            GroupBox("售出信息") {
                HStack {
                    Text("数量").frame(width: 70, alignment: .leading)
                    Stepper(value: $saleQty, in: 1...product.stock) { Text("\(saleQty) 个") }.controlSize(.small)
                }
                HStack {
                    Text("单价").frame(width: 70, alignment: .leading)
                    TextField("售价", text: $salePrice).textFieldStyle(.roundedBorder)
                    Text("元").foregroundStyle(.secondary).font(.caption)
                }
                HStack {
                    Text("买家").frame(width: 70, alignment: .leading)
                    TextField("选填", text: $saleBuyer).textFieldStyle(.roundedBorder)
                }
            }

            GroupBox("额外成本") {
                HStack {
                    Text("运费").frame(width: 70, alignment: .leading)
                    TextField("¥", text: $saleShipping).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("包装费").frame(width: 70, alignment: .leading)
                    TextField("¥", text: $salePackaging).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("平台抽成").frame(width: 70, alignment: .leading)
                    TextField("百分比", text: $saleCommission).textFieldStyle(.roundedBorder).frame(width: 80)
                    Text("%").foregroundStyle(.secondary).font(.caption)
                }
            }

            // 利润预览
            if let price = Double(salePrice), price > 0 {
                let rev = Double(saleQty) * price
                let shipping = Double(saleShipping) ?? 0
                let packaging = Double(salePackaging) ?? 0
                let commission = (Double(saleCommission) ?? 0) / 100
                let fee = rev * commission
                let unitCost = product.costPerUnit * Double(saleQty)
                let totalCost = unitCost + shipping + packaging + fee
                let profit = rev - totalCost
                VStack(spacing: 2) {
                    HStack {
                        Text("收入").foregroundStyle(.secondary).font(.caption)
                        Text("¥\(String(format: "%.2f", rev))").font(.callout)
                        Spacer()
                        Text("成本").foregroundStyle(.secondary).font(.caption)
                        Text("¥\(String(format: "%.2f", totalCost))").font(.callout)
                    }
                    HStack {
                        Text("利润").foregroundStyle(.secondary).font(.caption)
                        Text("¥\(String(format: "%.2f", profit))")
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(profit >= 0 ? .green : .red)
                    }
                }
                .padding(8)
                .glassPanel(cornerRadius: 6, opacity: 0.5)
            }

            HStack {
                Button("取消") {
                    showSaleSheet = false
                    saleQty = 1; salePrice = ""; saleBuyer = ""; saleShipping = ""; salePackaging = ""; saleCommission = ""
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("确认售出") {
                    let price = Double(salePrice) ?? 0
                    let shipping = Double(saleShipping) ?? 0
                    let packaging = Double(salePackaging) ?? 0
                    let commission = (Double(saleCommission) ?? 0) / 100
                    let sale = SaleRecord(product: product, quantity: saleQty, salePrice: price,
                                         shippingCost: shipping, packagingCost: packaging,
                                         platformCommission: commission, buyer: saleBuyer)
                    product.stock -= saleQty
                    modelContext.insert(sale)
                    try? modelContext.save()
                    showSaleSheet = false
                    saleQty = 1; salePrice = ""; saleBuyer = ""; saleShipping = ""; salePackaging = ""; saleCommission = ""
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(saleQty <= 0 || saleQty > product.stock)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    /// 产品周销售数量
    private func productSalesWeeklyQty() -> [(Date, Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [(Date, Int)] = []
        for day in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -(6 - day), to: today) else { continue }
            let next = cal.date(byAdding: .day, value: 1, to: d) ?? d
            let qty = product.sales.filter { $0.createdAt >= d && $0.createdAt < next }.reduce(0) { $0 + $1.quantity }
            result.append((d, qty))
        }
        return result
    }

    /// 产品状态徽章（同设备页风格）
    private var productStatusBadge: some View {
        if product.stock <= 0 {
            return Text("🔴 补货中")
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
        } else if product.stock <= product.effectiveThreshold {
            return Text("🟠 需补货")
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
        } else {
            return Text("🟢 售卖中")
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - 产品编辑

struct EditProductView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var specs = ""
    @State private var color = ""
    @State private var useCustomColor = false
    @State private var customColor = ""
    @State private var stock = 1
    @State private var costStr = ""
    @State private var alertThreshold = 1
    @State private var imageZoom: CGFloat = 80
    @State private var showCameraEdit = false

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "编辑产品")
            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    // 图片（可缩放）
                    VStack(spacing: 4) {
                        HStack {
                            Text("图片").frame(width: 60, alignment: .leading)
                            Spacer()
                            // 固定 80×80 容器，图片内容可缩放居中
                            ZStack {
                                if let data = product.imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                        .scaleEffect(imageZoom / 80.0, anchor: .center)
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .frame(width: 80, height: 80)
                                        .overlay(Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary))
                                }
                                Color.clear.contentShape(Rectangle()).onTapGesture(perform: pickImage)
                            }
                            .frame(width: 80, height: 80)
                            if product.imageData != nil {
                                Button("清除") { product.imageData = nil; try? modelContext.save() }
                                    .buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
                            }
                            Button(action: { showCameraEdit = true }) {
                                Label("拍照", systemImage: "camera.viewfinder")
                            }.buttonStyle(.borderless).font(.caption)
                            Spacer()
                        }
                        .sheet(isPresented: $showCameraEdit) {
                            SimpleCameraCapture { img in
                                self.saveImage(img)
                                showCameraEdit = false
                            } onCancel: { showCameraEdit = false }
                        }
                        if product.imageData != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "minus").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $imageZoom, in: 80...400, step: 10).frame(width: 100)
                                Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
                                Text("×\(String(format: "%.1f", imageZoom / 80.0))")
                                    .font(.caption2).foregroundStyle(.secondary).frame(width: 40)
                            }
                            .padding(.leading, 60)
                        }
                    }
                HStack {
                    Text("名称").frame(width: 60, alignment: .leading)
                    TextField("产品名称", text: $name).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("规格").frame(width: 60, alignment: .leading)
                    TextField("如 8×5×3cm", text: $specs).textFieldStyle(.roundedBorder)
                }
                PickerGroup(label: "颜色", selection: $color, useCustom: $useCustomColor, customText: $customColor, options: Filament.presetColors)
                Divider()
                HStack {
                    Text("库存").frame(width: 60, alignment: .leading)
                    Stepper(value: $stock, in: 0...999) { Text("\(stock) 个") }
                }
                HStack {
                    Text("成本").frame(width: 60, alignment: .leading)
                    TextField("¥", text: $costStr).textFieldStyle(.roundedBorder).frame(width: 100)
                    Text("元/个").foregroundStyle(.secondary).font(.caption)
                }
                HStack {
                    Text("预警").frame(width: 60, alignment: .leading)
                    Stepper(value: $alertThreshold, in: 0...100) { Text("\(alertThreshold) 个") }
                }
            }
            .padding(20)
            }
            Spacer()
            Divider()
            HStack {
                Button("删除", role: .destructive) {
                    modelContext.delete(product)
                    try? modelContext.save()
                    NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
                    dismiss()
                }
                .foregroundStyle(.red)
                Spacer()
                Button("保存") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 380, height: 460)
        .onAppear {
            name = product.name
            specs = product.specs
            color = product.color
            stock = product.stock
            costStr = String(format: "%.1f", product.costPerUnit)
            alertThreshold = product.alertThreshold
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.processAndSaveImage(url: url)
        }
    }

    private func processAndSaveImage(url: URL) {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let w = cgImage.width, h = cgImage.height
        let size = min(w, h)
        let cropRect = CGRect(x: (w - size) / 2, y: (h - size) / 2, width: size, height: size)
        let finalSize: CGFloat = 400

        // 尝试用 Vision 显著性检测做粗糙抠图
        let request = VNGenerateAttentionBasedSaliencyImageRequest { req, error in
            DispatchQueue.main.async {
                if let salientData = req.results?.first as? VNSaliencyImageObservation {
                    let maskPB = salientData.pixelBuffer
                    var cropped = cgImage
                    if let c = cgImage.cropping(to: cropRect) { cropped = c }

                    let ciInput = CIImage(cgImage: cropped)
                    let ciMask = CIImage(cvPixelBuffer: maskPB)
                        .transformed(by: CGAffineTransform(scaleX: finalSize / ciInput.extent.width, y: finalSize / ciInput.extent.height))
                        .cropped(to: CGRect(x: 0, y: 0, width: finalSize, height: finalSize))

                    let resized = ciInput.transformed(by: CGAffineTransform(scaleX: finalSize / ciInput.extent.width, y: finalSize / ciInput.extent.height))
                        .cropped(to: CGRect(x: 0, y: 0, width: finalSize, height: finalSize))

                    let whiteBg = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: resized.extent)

                    let blend = CIFilter(name: "CIBlendWithMask")!
                    blend.setValue(resized, forKey: kCIInputImageKey)
                    blend.setValue(whiteBg, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(ciMask, forKey: kCIInputMaskImageKey)

                    if let output = blend.outputImage,
                       let cgResult = CIContext(options: nil).createCGImage(output, from: output.extent) {
                        self.saveImage(NSImage(cgImage: cgResult, size: NSSize(width: finalSize, height: finalSize)))
                        return
                    }
                }
                // 降级：直接用白底方形裁剪
                self.drawOnWhiteBackground(cgImage: cgImage, cropRect: cropRect, finalSize: finalSize)
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.drawOnWhiteBackground(cgImage: cgImage, cropRect: cropRect, finalSize: finalSize)
                }
            }
        }
    }

    private func drawOnWhiteBackground(cgImage: CGImage, cropRect: CGRect, finalSize: CGFloat) {
        let cropped = cgImage.cropping(to: cropRect).map { NSImage(cgImage: $0, size: NSSize(width: finalSize, height: finalSize)) }
            ?? NSImage(cgImage: cgImage, size: NSSize(width: finalSize, height: finalSize))
        let result = NSImage(size: NSSize(width: finalSize, height: finalSize))
        result.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: finalSize, height: finalSize).fill()
        cropped.draw(in: NSRect(x: 0, y: 0, width: finalSize, height: finalSize))
        result.unlockFocus()
        saveImage(result)
    }

    private func saveImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        product.imageData = jpeg
        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
    }

    private func save() {
        product.name = name
        product.specs = specs
        product.color = useCustomColor ? customColor : color
        product.stock = stock
        if let c = Double(costStr) { product.costPerUnit = c }
        product.alertThreshold = alertThreshold

        // 应用缩放裁剪到图片
        if let data = product.imageData, let nsImage = NSImage(data: data),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let scale = imageZoom / 80.0
            if abs(scale - 1.0) > 0.01 {
                let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
                let cropW = w / scale, cropH = h / scale
                let cropX = (w - cropW) / 2, cropY = (h - cropH) / 2
                if let cropped = cgImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH)) {
                    let result = NSImage(cgImage: cropped, size: NSSize(width: 400, height: 400))
                    if let tiff = result.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                        product.imageData = jpeg
                    }
                }
            }
        }

        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
    }
}

// MARK: - 产品统计

struct ProductStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var products: [Product] {
        let fd = FetchDescriptor<Product>()
        return (try? modelContext.fetch(fd)) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "产品统计")
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    let list = products
                    let totalStock = list.reduce(0) { $0 + $1.stock }
                    let totalSales = list.reduce(0) { $0 + $1.sales.count }
                    let allSales = list.flatMap(\.sales)
                    let revenue = allSales.reduce(0.0) { $0 + $1.revenue }
                    let totalCost = list.reduce(0.0) { $0 + Double($1.stock) * $1.costPerUnit }
                    let profit = revenue - totalCost

                    // 概览卡片
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        StatCard(value: "\(list.count)", label: "产品数")
                        StatCard(value: "\(totalStock)", label: "总库存")
                        StatCard(value: "\(totalSales)", label: "已售次")
                    }

                    // 周销售额趋势
                    let weeklyData = weeklySalesData()
                    if !weeklyData.isEmpty {
                        GroupBox("周销售额") {
                            Chart(weeklyData, id: \.0) { item in
                                LineMark(x: .value("日期", item.0), y: .value("销售额", item.1))
                                    .foregroundStyle(.blue.gradient)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                PointMark(x: .value("日期", item.0), y: .value("销售额", item.1))
                                    .foregroundStyle(.blue)
                                    .symbolSize(20)
                            }
                            .chartYAxisLabel("¥")
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.weekday().day())
                                }
                            }
                            .frame(height: 120)
                            .padding(.top, 4)
                        }
                    }

                    // 利润
                    GroupBox("利润分析") {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("总收入").font(.caption).foregroundStyle(.secondary)
                                    Text("¥\(String(format: "%.2f", revenue))").font(.title2).fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("总成本").font(.caption).foregroundStyle(.secondary)
                                    Text("¥\(String(format: "%.2f", totalCost))").font(.title2).fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("总利润").font(.caption).foregroundStyle(.secondary)
                                    Text("¥\(String(format: "%.2f", profit))")
                                        .font(.title2).fontWeight(.bold)
                                        .foregroundStyle(profit >= 0 ? .green : .red)
                                }
                            }

                            let now = Date()
                            let cal = Calendar.current
                            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
                            let monthSales = allSales.filter { $0.createdAt >= monthStart }
                            let monthRevenue = monthSales.reduce(0.0) { $0 + $1.revenue }
                            let monthCost = monthSales.reduce(0.0) { sum, sale in
                                let mat = Double(sale.quantity) * (sale.product?.costPerUnit ?? 0)
                                return sum + mat + sale.shippingCost + sale.packagingCost + sale.platformFee
                            }
                            let monthProfit = monthRevenue - monthCost

                            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                            let weekSales = allSales.filter { $0.createdAt >= weekStart }
                            let weekRevenue = weekSales.reduce(0.0) { $0 + $1.revenue }
                            let weekCost = weekSales.reduce(0.0) { sum, sale in
                                let mat = Double(sale.quantity) * (sale.product?.costPerUnit ?? 0)
                                return sum + mat + sale.shippingCost + sale.packagingCost + sale.platformFee
                            }
                            let weekProfit = weekRevenue - weekCost

                            Divider()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("本月收入").foregroundStyle(.secondary).font(.caption)
                                    Text("¥\(String(format: "%.2f", monthRevenue))").font(.callout).fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("本月利润").foregroundStyle(.secondary).font(.caption)
                                    Text("¥\(String(format: "%.2f", monthProfit))")
                                        .font(.callout).fontWeight(.bold)
                                        .foregroundStyle(monthProfit >= 0 ? .green : .red)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("本周收入").foregroundStyle(.secondary).font(.caption)
                                    Text("¥\(String(format: "%.2f", weekRevenue))").font(.callout).fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("本周利润").foregroundStyle(.secondary).font(.caption)
                                    Text("¥\(String(format: "%.2f", weekProfit))")
                                        .font(.callout).fontWeight(.bold)
                                        .foregroundStyle(weekProfit >= 0 ? .green : .red)
                                }
                            }
                        }
                        .padding(8)
                    }

                    Divider()

                    // 库存明细（含预警高亮）
                    let alertCount = list.filter(\.needsReorder).count
                    HStack {
                        Text("库存明细").font(.headline)
                        if alertCount > 0 {
                            Text("⚠️ \(alertCount)").font(.caption).foregroundStyle(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15)).clipShape(Capsule())
                        }
                        Spacer()
                    }
                    if list.isEmpty {
                        Text("暂无产品").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        ForEach(list.sorted { $0.stock < $1.stock }) { p in
                            HStack {
                                if let data = p.imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                        .frame(width: 24, height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    ColorSwatch(p.color, size: 14)
                                }
                                Text(p.name).frame(width: 120, alignment: .leading).lineLimit(1)
                                Text(p.specs).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                                Spacer()
                                Text("库存 \(p.stock)").font(.callout)
                                    .foregroundStyle(p.needsReorder ? .red : .secondary)
                                if p.needsReorder {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                                }
                            }
                            .padding(p.needsReorder ? 4 : 0)
                            .background(p.needsReorder ? Color.orange.opacity(0.06) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            Divider()
                        }
                    }

                    Divider()

                    // 销售排行
                    Text("销售排行").font(.headline).frame(maxWidth: .infinity, alignment: .leading)

                    if list.isEmpty {
                        Text("暂无产品").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        let ranked = list.sorted { $0.sales.count > $1.sales.count }
                        ForEach(ranked.indices, id: \.self) { i in
                            let p = ranked[i]
                            let rev = p.sales.reduce(0.0) { $0 + $1.revenue }
                            HStack {
                                Text("#\(i + 1)").font(.caption).foregroundStyle(.secondary).frame(width: 24)
                                if let data = p.imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                        .frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                Text(p.name).frame(width: 100, alignment: .leading).lineLimit(1)
                                Spacer()
                                Text("售 \(p.sales.count) 次").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.0f", rev))").font(.callout)
                                let cst = Double(p.sales.count) * p.costPerUnit
                                Text("利润 ¥\(String(format: "%.2f", rev - cst))")
                                    .font(.caption).foregroundStyle(rev - cst >= 0 ? .green : .red)
                            }
                            Divider()
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 520)
    }

    /// 周销售额（过去7天）
    private func weeklySalesData() -> [(Date, Double)] {
        let allSales = products.flatMap(\.sales)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [(Date, Double)] = []
        for day in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -(6 - day), to: today) else { continue }
            let next = cal.date(byAdding: .day, value: 1, to: d) ?? d
            let rev = allSales.filter { $0.createdAt >= d && $0.createdAt < next }.reduce(0.0) { $0 + $1.revenue }
            result.append((d, rev))
        }
        return result
    }
}

// MARK: - 手动新增产品

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var specs = ""
    @State private var color = ""
    @State private var useCustomColor = false
    @State private var customColor = ""
    @State private var stock = 1
    @State private var priceStr = ""
    @State private var costStr = ""
    @State private var alertThreshold = 1
    @State private var imageData: Data? = nil
    @State private var showCameraAdd = false

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "新增产品")
            Divider()
            ScrollView {
                VStack(spacing: 14) {
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
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .frame(width: 80, height: 80)
                                        .overlay(Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary))
                                }
                                Color.clear.contentShape(Rectangle()).onTapGesture(perform: pickImage)
                            }
                            if imageData != nil {
                                Button("清除") { imageData = nil }.buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
                            }
                            Button(action: { showCameraAdd = true }) {
                                Label("拍照", systemImage: "camera.viewfinder")
                            }.buttonStyle(.borderless).font(.caption)
                            Spacer()
                        }
                        .sheet(isPresented: $showCameraAdd) {
                            SimpleCameraCapture { img in
                                processAndSaveImage(img)
                                showCameraAdd = false
                            } onCancel: { showCameraAdd = false }
                        }
                    }

                    HStack {
                        Text("名称").frame(width: 60, alignment: .leading)
                        TextField("产品名称", text: $name).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("规格").frame(width: 60, alignment: .leading)
                        TextField("如 8×5×3cm", text: $specs).textFieldStyle(.roundedBorder)
                    }
                    PickerGroup(label: "颜色", selection: $color, useCustom: $useCustomColor, customText: $customColor, options: Filament.presetColors)
                    Divider()
                    HStack {
                        Text("库存").frame(width: 60, alignment: .leading)
                        Stepper(value: $stock, in: 0...999) { Text("\(stock) 个") }
                    }
                    HStack {
                        Text("成本").frame(width: 60, alignment: .leading)
                        TextField("¥", text: $costStr).textFieldStyle(.roundedBorder).frame(width: 100)
                        Text("元/个").foregroundStyle(.secondary).font(.caption)
                    }
                    HStack {
                        Text("定价").frame(width: 60, alignment: .leading)
                        TextField("¥", text: $priceStr).textFieldStyle(.roundedBorder).frame(width: 100)
                        Text("元/个").foregroundStyle(.secondary).font(.caption)
                    }
                    HStack {
                        Text("预警").frame(width: 60, alignment: .leading)
                        Stepper(value: $alertThreshold, in: 0...100) { Text("\(alertThreshold) 个") }
                    }
                }
                .padding(20)
            }
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("保存") {
                    let p = Product(name: name, specs: specs, color: useCustomColor ? customColor : color,
                                   stock: stock, price: Double(priceStr) ?? 0,
                                   costPerUnit: Double(costStr) ?? 0, alertThreshold: alertThreshold,
                                   imageData: imageData)
                    modelContext.insert(p)
                    try? modelContext.save()
                    NotificationCenter.default.post(name: Notification.Name("filamentDataChanged"), object: nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 360, height: 480)
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

    private func processAndSaveImage(_ nsImage: NSImage) {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
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
