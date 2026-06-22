import SwiftUI
import SwiftData
import Charts

/// 同一品牌+材质的耗材分组（不区分颜色）
struct FilamentGroup: Identifiable, Hashable {
    let id: String // "brand|material"
    let brand: String
    let material: String
    var filaments: [Filament]

    /// 颜色变体
    var colorVariants: [(color: String, count: Int)] {
        let grouped = Dictionary(grouping: filaments) { $0.color }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    /// 总数量
    var totalCount: Int { filaments.count }
    /// 未开封（剩余=满重）的数量
    var unopenedCount: Int { filaments.filter { $0.remainingWeight == $0.weight }.count }
    /// 已开封数量
    var openedCount: Int { filaments.filter { $0.remainingWeight < $0.weight }.count }
    /// 总剩余量
    var totalRemaining: Int { filaments.reduce(0) { $0 + $1.remainingWeight } }
    /// 预警总值（所有卷的预警线之和）
    var totalAlertThreshold: Int { filaments.reduce(0) { $0 + $1.alertThreshold } }
    /// 是否需补货（总剩余 < 总预警值）
    var needsReorder: Bool { totalRemaining <= totalAlertThreshold }
    /// 总消耗量
    var totalConsumed: Int { filaments.reduce(0) { $0 + $1.usedWeight } }

    /// 月均消耗
    var monthlyConsumption: Double {
        filaments.reduce(0.0) { $0 + $1.monthlyConsumptionRate }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: FilamentGroup, rhs: FilamentGroup) -> Bool {
        lhs.id == rhs.id
    }
}

let filamentDataChanged = Notification.Name("filamentDataChanged")

// MARK: - 品牌图片存储器（按品牌名独立存储）
struct BrandImageStore {
    private static func key(for brand: String) -> String { "brand_img_\(brand.lowercased())" }
    static func save(image: Data, for brand: String) {
        UserDefaults.standard.set(image, forKey: key(for: brand))
    }
    static func image(for brand: String) -> Data? {
        UserDefaults.standard.data(forKey: key(for: brand))
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearance") private var appearance = "light"
    @State private var store: FilamentStore?
    @State private var selectedGroup: FilamentGroup?
    @State private var selectedProduct: Product?
    @State private var selectedDevice: Device?
    @State private var showAddSheet = false
    @State private var showDeviceEdit = false
    @State private var filaments: [Filament] = []
    @State private var sidebarTab = "耗材"
    @State private var refreshToken = UUID()

    private var groups: [FilamentGroup] {
        let filtered = filaments
        return groupFilaments(filtered).sorted { g1, g2 in
            let a1 = g1.filaments.contains { $0.status == FilamentStatus.active.rawValue || $0.status == "" }
            let a2 = g2.filaments.contains { $0.status == FilamentStatus.active.rawValue || $0.status == "" }
            if a1 != a2 { return a1 && !a2 }
            return g1.totalRemaining > g2.totalRemaining
        }
    }

    /// 获取某品牌的图片（从所有耗材中查询）
    private func brandImage(for brand: String) -> Data? {
        filaments.first(where: { $0.brand == brand && $0.imageData != nil })?.imageData
    }

    private func groupFilaments(_ list: [Filament]) -> [FilamentGroup] {
        var dict: [String: [Filament]] = [:]
        for f in list {
            let b = f.brand.trimmingCharacters(in: .whitespaces)
            let m = f.material.trimmingCharacters(in: .whitespaces)
            let key = "\(b.lowercased())|\(m.lowercased())"
            dict[key, default: []].append(f)
        }
        return dict.map { key, group in
            let first = group.first!
            return FilamentGroup(id: key, brand: first.brand.trimmingCharacters(in: .whitespaces), material: first.material.trimmingCharacters(in: .whitespaces), filaments: group)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
                Picker("", selection: $sidebarTab) {
                Text("🖨 \(Localized.str("设备"))").tag("设备")
                Text("📄 \(Localized.str("耗材"))").tag("耗材")
                Text("📦 \(Localized.str("产品"))").tag("产品")
                Text("📊 \(Localized.str("统计"))").tag("统计")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if sidebarTab == "统计" {
                StatisticsView(isInline: true)
            } else {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        if sidebarTab == "耗材" {
                            SidebarView(groups: groups, selectedGroup: $selectedGroup, store: store,
                                onAdd: { showAddSheet = true })
                        } else if sidebarTab == "设备" {
                            DeviceListView(selectedDevice: $selectedDevice, showEditSheet: $showDeviceEdit)
                        } else {
                            ProductListView(selectedProduct: $selectedProduct)
                        }
                    }
                    .frame(width: 260)
                    

                    Divider()

                    if sidebarTab == "耗材" {
                        if let group = selectedGroup {
                            GroupDetailView(group: group, store: store)
                                .frame(maxWidth: .infinity)
                                
                        } else {
                            emptyDetail
                                .frame(maxWidth: .infinity)
                        }
                    } else if sidebarTab == "设备" {
                        if let device = selectedDevice {
                            DeviceDetailView(device: device)
                                .frame(maxWidth: .infinity)
                                
                        } else {
                            emptyDetail
                                .frame(maxWidth: .infinity)
                                
                        }
                    } else {
                        if let product = selectedProduct {
                            ProductDetailView(product: product)
                                .frame(maxWidth: .infinity)
                                
                        } else {
                            emptyDetail
                                .frame(maxWidth: .infinity)
                                
                        }
                    }
                }
            }
        }
        .id(refreshToken)
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        
        .onAppear {
            store = FilamentStore(modelContext: modelContext)
            refreshData()
            // 监听数据变更通知
            NotificationCenter.default.addObserver(forName: filamentDataChanged, object: nil, queue: .main) { _ in
                refreshData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: filamentDataChanged)) { _ in
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("deviceEditRequested"))) { _ in
            showDeviceEdit = true
        }
        .sheet(isPresented: $showAddSheet) {
            AddFilamentView(store: store, onSave: nil)
        }
        .sheet(isPresented: $showDeviceEdit) {
            if let d = selectedDevice {
                EditDeviceView(device: d)
            }
        }
    }

    // MARK: - 空状态

    @State private var showAlertSheet = false

    private var emptyDetail: some View {
        VStack(spacing: 0) {
            // 补货提醒横幅
            let alertGroups = filamentGroupsNeedingReorder()
            if !alertGroups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("需补货提醒").font(.headline)
                        Spacer()
                        Text("\(alertGroups.count) 组").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(alertGroups) { group in
                        HStack(spacing: 8) {
                            Text("\(group.brand) \(group.material)").font(.callout).lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("剩\(group.totalRemaining)g").font(.caption).fontWeight(.medium).foregroundStyle(.orange)
                                let rate = group.monthlyConsumption
                                if rate > 0 {
                                    Text("约\(Int(Double(group.totalRemaining) / rate * 30))天用完").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture { selectedGroup = group }
                    }
                }
                .padding(16)
                .background(.clear).clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 32).padding(.top, 16)
            }
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "shippingbox").font(.system(size: 36)).foregroundStyle(.secondary)
                Text("选择一个耗材查看详情").foregroundStyle(.secondary)
                Text("或点左侧「新增」添加第一卷耗材").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func filamentGroupsNeedingReorder() -> [FilamentGroup] {
        let descriptor = FetchDescriptor<Filament>()
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        let dict = Dictionary(grouping: all) { "\($0.brand)|\($0.material)" }
        return dict.compactMap { key, list -> FilamentGroup? in
            let p = key.split(separator: "|").map(String.init)
            let g = FilamentGroup(id: key, brand: p[safe: 0] ?? "", material: p[safe: 1] ?? "", filaments: list)
            return g.needsReorder ? g : nil
        }
    }

    private func refreshData() {
        let descriptor = FetchDescriptor<Filament>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        filaments = (try? modelContext.fetch(descriptor)) ?? []
        // 更新 selectedGroup 指向新数据中的对应组
        if let oldID = selectedGroup?.id {
            selectedGroup = groups.first { $0.id == oldID }
        }
        refreshToken = UUID()
    }

    private func brandIcon(_ brand: String) -> some View {
        let icon: String
        let color: Color
        switch brand.lowercased() {
        case let b where b.contains("bambu"): icon = "cube.box.fill"; color = .cyan
        case let b where b.contains("esun"): icon = "circle.fill"; color = .green
        case let b where b.contains("polymaker"): icon = "square.fill"; color = .orange
        case let b where b.contains("sunlu"): icon = "triangle.fill"; color = .red
        case let b where b.contains("elegoo"): icon = "hexagon.fill"; color = .purple
        case let b where b.contains("anycubic"): icon = "diamond.fill"; color = .blue
        case let b where b.contains("creality"): icon = "star.fill"; color = .yellow
        default: icon = "drop.fill"; color = .gray
        }
        return Image(systemName: icon).font(.title).foregroundStyle(color)
    }
}

// MARK: - 独立侧栏（减少刷新）

struct SidebarView: View {
    let groups: [FilamentGroup]
    @Binding var selectedGroup: FilamentGroup?
    let store: FilamentStore?
    var onAdd: (() -> Void)? = nil
    @State private var searchText = ""

    /// 按品牌分组的耗材
    private var brandGroups: [(brand: String, materials: [FilamentGroup])] {
        let filtered: [FilamentGroup]
        if searchText.isEmpty {
            filtered = groups
        } else {
            filtered = groups.filter {
                $0.brand.localizedCaseInsensitiveContains(searchText) ||
                $0.material.localizedCaseInsensitiveContains(searchText)
            }
        }
        let grouped = Dictionary(grouping: filtered) { $0.brand }
        return grouped.map { ($0.key, $0.value.sorted { $0.material < $1.material }) }
            .sorted { $0.brand < $1.brand }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 新增按钮行（独立于列表）
            Button(action: { onAdd?() }) {
                Label("新增", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.small)
            .padding(.horizontal, 12).padding(.vertical, 6)
            toolbar
            Divider()
            searchBar
            Divider()
            groupList
        }
        .background(.clear)
    }

    /// 需要补货的组数
    private var alertCount: Int {
        groups.filter { $0.needsReorder }.count
    }

    @Environment(\.modelContext) private var modelContext

    private func exportInventory() {
        let fd = FetchDescriptor<Filament>()
        guard let filaments = try? modelContext.fetch(fd),
              let url = ExportService.exportToCSV(filaments: filaments) else { return }
        ExportService.saveFilePanel(url: url)
    }

    private func exportConsumptions() {
        let fd = FetchDescriptor<Filament>()
        guard let filaments = try? modelContext.fetch(fd),
              let url = ExportService.exportConsumptions(filaments: filaments) else { return }
        ExportService.saveFilePanel(url: url)
    }

    private func exportPurchaseSuggestion() {
        let fd = FetchDescriptor<Filament>()
        guard let filaments = try? modelContext.fetch(fd),
              let url = ExportService.exportPurchaseSuggestion(filaments: filaments) else { return }
        ExportService.saveFilePanel(url: url)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            Text("耗材列表").font(.body).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("库存报表", action: exportInventory)
                Button("消耗记录", action: exportConsumptions)
                Divider()
                Button("采购建议", action: exportPurchaseSuggestion)
            } label: {
                Label("导出", systemImage: "square.and.arrow.up").lineLimit(1).fixedSize()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            if alertCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("\(alertCount)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField("搜索...", text: $searchText).textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }


    private var groupList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(brandGroups, id: \.brand) { brand, materials in
                    HStack {
                        Text(brand).font(.headline).fontWeight(.bold).foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    ForEach(materials) { group in
                        GroupRow(group: group, isSelected: selectedGroup?.id == group.id)
                            .frame(height: 40)
                            .padding(.leading, 16)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedGroup = group }
                    }
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

}

// MARK: - 分组行

struct GroupRow: View {
    let group: FilamentGroup
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text(group.material).font(.body).fontWeight(.medium)
                if group.needsReorder {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                }
                Spacer()
                HStack(spacing: 3) {
                    ForEach(group.colorVariants.prefix(5), id: \.color) { v in
                        ColorSwatch(v.color, size: 8)
                    }
                    if group.colorVariants.count > 5 {
                        Text("+\(group.colorVariants.count - 5)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            HStack(spacing: 0) {
                Text("已开\(group.openedCount)卷").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("未开\(group.unopenedCount)卷").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("剩\(group.totalRemaining)g").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - 分组详情

struct GroupDetailView: View {
    let group: FilamentGroup
    let store: FilamentStore?
    @Environment(\.modelContext) private var modelContext

    /// 月均消耗：不足一个月仅统计当月，足月按月均
    private var realMonthlyConsumption: Double {
        let fd = FetchDescriptor<ConsumptionRecord>()
        guard let allRecords = try? modelContext.fetch(fd) else { return 0 }
        let groupFil = group.filaments
        let recs = allRecords.filter { rec in
            guard let f = rec.filament else { return false }
            return groupFil.contains { gf in
                gf.brand == f.brand && gf.material == f.material
            }
        }
        let total = recs.reduce(0) { $0 + $1.weightUsed }
        guard total > 0, let first = recs.map(\.createdAt).min() else { return 0 }

        let now = Date()
        let monthsSince = Calendar.current.dateComponents([.month], from: first, to: now).month ?? 0
        if monthsSince < 1 {
            // 不足一月：仅统计当月
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
            let thisMonth = recs.filter { $0.createdAt >= monthStart }.reduce(0) { $0 + $1.weightUsed }
            return Double(thisMonth)
        } else {
            // 足月：总消耗 ÷ 月数
            return Double(total) / Double(monthsSince)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 预警
                if group.needsReorder {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("部分耗材需要补货，月均消耗 \(String(format: "%.0f", realMonthlyConsumption))g")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 标题（点击品牌 logo 可更换图片）
                HStack(spacing: 12) {
                    // 品牌 logo（按品牌名独立存储，点击更换）
                    if let data = BrandImageStore.image(for: group.brand) ?? group.filaments.first(where: { $0.imageData != nil })?.imageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill").font(.caption).foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { pickBrandLogo() }
                    } else {
                        BrandTextLogo(brand: group.brand)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "plus.circle.fill").font(.caption).foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { pickBrandLogo() }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.brand) \(group.material)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }

                Divider()

                // 统计卡片
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatCard(value: "\(group.totalCount)", label: "总卷数")
                    StatCard(value: "\(group.totalRemaining)g", label: "总剩余")
                    StatCard(value: "\(group.totalConsumed)g", label: "总消耗")
                    StatCard(value: consumedCost, label: "消耗成本")
                    StatCard(value: group.unopenedCount > 0 ? "\(group.unopenedCount)卷未开" : "\(group.openedCount)卷已开", label: "开封状态")
                    StatCard(value: "\(String(format: "%.0f", realMonthlyConsumption))g/月", label: "月均消耗")
                    StatCard(value: filamentsPriceSummary, label: "价格范围")
                }

                Divider()

                // 消耗趋势图（过去一周）
                VStack(alignment: .leading, spacing: 8) {
                    Text("本周消耗趋势")
                        .font(.headline)

                    let weekData = weeklyConsumptionData
                    if weekData.isEmpty {
                        Text("暂无消耗数据")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Chart(weekData, id: \.0) { item in
                            LineMark(
                                x: .value("日期", item.0, unit: .day),
                                y: .value("消耗(g)", item.1)
                            )
                            .foregroundStyle(.blue.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("日期", item.0, unit: .day),
                                y: .value("消耗(g)", item.1)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(30)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday().day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel()
                                AxisGridLine()
                            }
                        }
                        .frame(height: 140)
                    }
                }

                Divider()

                // 各卷明细
                HStack {
                    Text("各卷明细")
                        .font(.headline)
                    Spacer()
                    Text("点击卡片可记录消耗和查看详情")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(group.filaments.sorted(by: { $0.remainingWeight > $1.remainingWeight })) { f in
                    FilamentMiniCard(filament: f, store: store)
                }
            }
            .padding(24)
        }
        .background(.clear)
    }

    /// 消耗总成本（均价×消耗）
    private var consumedCost: String {
        let total = group.totalConsumed
        guard total > 0 else { return "—" }
        let avgPricePerGram = group.filaments.reduce(0.0) { $0 + $1.price / Double(max($1.weight, 1)) } / Double(group.filaments.count)
        let cost = Double(total) * avgPricePerGram
        return "¥\(String(format: "%.2f", cost))"
    }

    private var filamentsPriceSummary: String {
        let prices = group.filaments.map(\.price)
        guard let min = prices.min(), let max = prices.max() else { return "—" }
        if min == max { return "¥\(String(format: "%.2f", min))" }
        return "¥\(String(format: "%.2f", min))~¥\(String(format: "%.2f", max))"
    }

    private func colorFromName(_ name: String) -> Color {
        Filament.colorValue(for: name)
    }

    /// 过去7天每日消耗数据（按品牌+材质过滤）
    private var weeklyConsumptionData: [(Date, Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fd = FetchDescriptor<ConsumptionRecord>()
        let groupFil = group.filaments
        let all = ((try? modelContext.fetch(fd)) ?? []).filter { rec in
            guard let f = rec.filament else { return false }
            return groupFil.contains { gf in
                gf.brand == f.brand && gf.material == f.material
            }
        }
        var result: [(Date, Int)] = []
        for day in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -(6 - day), to: today) else { continue }
            let next = cal.date(byAdding: .day, value: 1, to: d) ?? d
            let g = all.filter { $0.createdAt >= d && $0.createdAt < next }.reduce(0) { $0 + $1.weightUsed }
            result.append((d, g))
        }
        return result
    }

    /// 点击品牌 logo 更换图片
    private func pickBrandLogo() {
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
            // 存入品牌图片存储器 + 保存到组内第一个耗材（确保数据库可查到）
            BrandImageStore.save(image: jpeg, for: group.brand)
            if let first = group.filaments.first {
                first.imageData = jpeg
                try? modelContext.save()
            }
            NotificationCenter.default.post(name: filamentDataChanged, object: nil)
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct BrandTextLogo: View {
    let brand: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
            Text(shortBrand)
                .font(.system(size: shortBrand.count > 4 ? 10 : 12, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .padding(4)
        }
    }

    private var shortBrand: String {
        let trimmed = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "LOGO" : trimmed
    }
}

    private func brandIcon(_ brand: String) -> some View {
        let icon: String
        let color: Color
        switch brand.lowercased() {
        case let b where b.contains("bambu"): icon = "cube.box.fill"; color = .cyan
        case let b where b.contains("esun"): icon = "circle.fill"; color = .green
        case let b where b.contains("polymaker"): icon = "square.fill"; color = .orange
        case let b where b.contains("sunlu"): icon = "triangle.fill"; color = .red
        case let b where b.contains("elegoo"): icon = "hexagon.fill"; color = .purple
        case let b where b.contains("anycubic"): icon = "diamond.fill"; color = .blue
        case let b where b.contains("creality"): icon = "star.fill"; color = .yellow
        default: icon = "drop.fill"; color = .gray
        }
        return Image(systemName: icon).font(.title).foregroundStyle(color)
    }

/// 每卷的迷你卡片
struct FilamentMiniCard: View {
    let filament: Filament
    let store: FilamentStore?

    @State private var showEdit = false
    @State private var showDelete = false
    @State private var showConsumePopover = false
    @State private var consumeWeight = ""
    @State private var consumeModelName = ""
    @State private var productItems: [ProductItem] = [ProductItem()]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 8) {
            CircleSwatch(filament.color, size: 21)

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                // 状态行
                HStack {
                    let isUnopened = filament.remainingWeight == filament.weight
                    Text(isUnopened ? "未开封" : "已开封")
                        .font(.caption)
                        .foregroundStyle(isUnopened ? .green : .orange)
                        .fontWeight(.medium)
                    Spacer()
                    Text("¥\(String(format: "%.0f", filament.price))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 消耗进度条（点击弹出消耗记录）
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        // 灰色背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 200, height: 10)
                        // 剩余量颜色条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(remaining: Double(filament.remainingWeight) / Double(max(filament.weight, 1))))
                            .frame(width: 200 * CGFloat(filament.remainingWeight) / CGFloat(max(filament.weight, 1)), height: 10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { showConsumePopover = true }

                    Text("剩\(filament.remainingWeight)g")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .onTapGesture { showConsumePopover = true }
                }
            }

            // 操作按钮
            VStack(spacing: 4) {
                Button { showEdit = true } label: {
                    Image(systemName: "pencil").font(.caption).frame(width: 20, height: 20)
                }
                .buttonStyle(.plain).help("编辑")

                Button { showDelete = true } label: {
                    Image(systemName: "trash").font(.caption).frame(width: 20, height: 20)
                }
                .buttonStyle(.plain).foregroundStyle(.red).help("删除")
            }
        }
        .padding(8)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .sheet(isPresented: $showConsumePopover) {
            consumePopover
        }
        .sheet(isPresented: $showEdit) {
            EditSingleFilamentView(filament: filament)
        }
        .alert("删除耗材", isPresented: $showDelete) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                modelContext.delete(filament)
                try? modelContext.save()
                NotificationCenter.default.post(name: filamentDataChanged, object: nil)
            }
        } message: {
            Text("确定删除「\(filament.brand) \(filament.material) \(filament.color)」(¥\(String(format: "%.0f", filament.price)))？")
        }
    }

    private var consumePopover: some View {
        VStack(spacing: 0) {
            Text("记录消耗").font(.headline).padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    // 消耗部分
                    GroupBox("耗材消耗") {
                        HStack {
                            Text("克数").frame(width: 50, alignment: .leading)
                            ConsumeTextField(text: $consumeWeight, placeholder: "输入克数").frame(height: 20)
                            Text("g").foregroundStyle(.secondary)
                        }

                        Button("📷 从切片截图识别") {
                            recognizeSlicerScreenshot()
                        }
                        .buttonStyle(.borderless).font(.caption).foregroundStyle(.blue)

                        if filament.remainingWeight < 100 {
                            Button("这卷用完了（剩\(filament.remainingWeight)g）") {
                                let used = filament.remainingWeight
                                filament.remainingWeight = 0
                                let record = ConsumptionRecord(filament: filament, weightUsed: used, modelName: consumeModelName, createdAt: .now)
                                modelContext.insert(record)
                                try? modelContext.save()
                                NotificationCenter.default.post(name: filamentDataChanged, object: nil)
                                showConsumePopover = false
                            }
                            .buttonStyle(.bordered).tint(.red).controlSize(.small)
                        }
                    }

                    // 产品列表（支持多个）
                    GroupBox("转为产品（可选）") {
                        ForEach($productItems) { $item in
                            VStack(spacing: 6) {
                                HStack {
                                    Text("名称").frame(width: 40, alignment: .leading)
                                    ConsumeTextField(text: $item.name, placeholder: "产品名称").frame(height: 20)
                                    Button {
                                        productItems.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash").font(.caption)
                                    }
                                    .buttonStyle(.plain).foregroundStyle(.red)
                                    .disabled(productItems.count <= 1)
                                }
                                HStack {
                                    Text("规格").frame(width: 40, alignment: .leading)
                                    ConsumeTextField(text: $item.specs, placeholder: "如 8×5×3cm").frame(height: 20)
                                }
                                HStack {
                                    Text("数量").frame(width: 40, alignment: .leading)
                                    Stepper(value: $item.quantity, in: 1...999) {
                                        Text("\(item.quantity) 个").frame(width: 50, alignment: .leading)
                                    }.controlSize(.small)
                                }
                                ProductImagePicker(imageData: $item.imageData)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Button("＋ 添加产品") {
                            productItems.append(ProductItem())
                        }
                        .buttonStyle(.borderless).font(.caption)
                    }

                    HStack {
                        Button("取消") {
                            showConsumePopover = false
                            consumeWeight = ""; consumeModelName = ""
                            productItems = [ProductItem()]
                        }
                        .keyboardShortcut(.cancelAction)
                        Spacer()
                        Button("确认") {
                            saveConsumption()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(parsedGramInput(consumeWeight) == nil)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(4)
            }
        }
        .padding(12)
        .frame(width: 320, height: 480)
    }

    private func recognizeSlicerScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.message = "选择切片软件截图"
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            self.performSlicerOCR(imageData: data)
        }
    }

    private func performSlicerOCR(imageData: Data) {
        let tmpURL = AppPaths.ocrTempFile("slicer_ocr.png")
        try? imageData.write(to: tmpURL)
        guard let toolPath = AppPaths.ocrToolPath else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: toolPath)
            proc.arguments = [tmpURL.path]
            let out = Pipe()
            proc.standardOutput = out
            do {
                try proc.run(); proc.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                guard proc.terminationStatus == 0, let str = String(data: data, encoding: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: str.data(using: .utf8)!) as? [String: String],
                      json["error"] == nil, let text = json["text"] else { return }

                // 解析克数 (如 45.3g, 45g, 12.5g)
                let weightPattern = try? NSRegularExpression(pattern: "(\\d+\\.?\\d*)\\s*[gG克]")
                let matches = weightPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text))
                guard let match = matches?.first, let range = Range(match.range(at: 1), in: text),
                      let grams = Double(text[range]) else { return }

                let used = min(max(1, Int(grams.rounded())), self.filament.remainingWeight)
                guard used > 0 else { return }

                DispatchQueue.main.async {
                    // 识别到的克数填入输入框，让用户手动确认
                    self.consumeWeight = "\(used)"
                }
            } catch {}
        }
    }

    private func saveConsumption() {
        let used = min(parsedGramInput(consumeWeight) ?? 0, filament.remainingWeight)
        guard used > 0 else { return }

        filament.remainingWeight -= used

        // 是否创建产品
        var product: Product?
        let validItems = productItems.filter { !$0.name.isEmpty }
        if !validItems.isEmpty {
            // 只关联第一个产品到消耗记录
            let firstItem = validItems[0]
            // 消耗的那一卷购入价格换算到1g
            let unitCost = filament.price / Double(filament.weight)
            let totalUsed = Double(used)
            product = Product(
                name: firstItem.name,
                specs: firstItem.specs,
                color: filament.color,
                stock: firstItem.quantity,
                price: 0,
                costPerUnit: unitCost * totalUsed / Double(firstItem.quantity),
                imageData: firstItem.imageData
            )
            modelContext.insert(product!)

            // 其余产品各自创建
            for item in validItems.dropFirst() {
                let p = Product(
                    name: item.name,
                    specs: item.specs,
                    color: filament.color,
                    stock: item.quantity,
                    price: 0,
                    costPerUnit: unitCost * totalUsed / Double(item.quantity),
                    imageData: item.imageData
                )
                modelContext.insert(p)
            }
        }

        let record = ConsumptionRecord(
            filament: filament,
            product: product,
            weightUsed: used,
            modelName: consumeModelName,
            createdAt: .now
        )
        modelContext.insert(record)

        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)

        showConsumePopover = false
        consumeWeight = ""; consumeModelName = ""
        productItems = [ProductItem()]
    }

    private func recordConsumption() {
        showConsumePopover = true
    }

    /// 进度条颜色
    /// 100% → 绿, >70% → 蓝, >50% → 黄, >20% → 橙, ≤20% → 红
    private func progressColor(remaining: Double) -> Color {
        if remaining >= 1.0 { return .green }
        if remaining > 0.7 { return .blue }
        if remaining > 0.5 { return .yellow }
        if remaining > 0.2 { return .orange }
        return .red
    }

    private func filamentColor(_ name: String) -> Color {
        Filament.colorValue(for: name)
    }
}

// MARK: - 单卷编辑

struct EditSingleFilamentView: View {
    let filament: Filament
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var brand = ""
    @State private var material = ""
    @State private var color = ""
    @State private var useCustomBrand = false
    @State private var useCustomMaterial = false
    @State private var useCustomColor = false
    @State private var customBrand = ""
    @State private var customMaterial = ""
    @State private var customColor = ""
    @State private var weight = 1000
    @State private var price = ""
    @State private var alertThreshold = 200

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "编辑耗材")
            Divider()

            VStack(spacing: 14) {
                PickerGroup(label: "品牌", selection: $brand, useCustom: $useCustomBrand, customText: $customBrand, options: Filament.presetBrands)
                PickerGroup(label: "材质", selection: $material, useCustom: $useCustomMaterial, customText: $customMaterial, options: Filament.presetMaterials)
                PickerGroup(label: "颜色", selection: $color, useCustom: $useCustomColor, customText: $customColor, options: Filament.presetColors)
                Divider()
                HStack {
                    Text("重量").frame(width: 60, alignment: .leading)
                    Picker("", selection: $weight) {
                        Text("200g").tag(200); Text("500g").tag(500)
                        Text("1kg").tag(1000); Text("2kg").tag(2000); Text("3kg").tag(3000)
                    }.labelsHidden()
                    Spacer(); Text("克").foregroundStyle(.secondary)
                }
                HStack {
                    Text("价格").frame(width: 60, alignment: .leading)
                    TextField("价格", text: $price).textFieldStyle(.roundedBorder).frame(width: 120)
                    Text("元").foregroundStyle(.secondary); Spacer()
                }
                HStack {
                    Text("预警").frame(width: 60, alignment: .leading)
                    Stepper(value: $alertThreshold, in: 50...1000, step: 50) { Text("\(alertThreshold) 克") }
                    Spacer()
                }
            }
            .padding(20)
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("保存") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(brand.isEmpty || material.isEmpty || color.isEmpty || (Double(price) ?? 0) <= 0)
            }
            .padding(16)
        }
        .frame(width: 380, height: 400)
        .onAppear {
            brand = filament.brand; material = filament.material; color = filament.color
            weight = filament.weight; price = String(format: "%.0f", filament.price)
            alertThreshold = filament.alertThreshold
        }
    }

    private func save() {
        guard let p = Double(price), p > 0 else { return }
        let b = useCustomBrand ? customBrand : brand
        let m = useCustomMaterial ? customMaterial : material
        let c = useCustomColor ? customColor : color
        Filament.rememberPreset(brand: b, material: m, color: c)
        filament.brand = b; filament.material = m; filament.color = c
        filament.weight = weight; filament.price = p; filament.alertThreshold = alertThreshold
        if filament.status == FilamentStatus.usedUp.rawValue {
            filament.status = FilamentStatus.active.rawValue
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
    }
}

// MARK: - 原生输入框（解决 Popover 中无法输入的问题）

struct ConsumeTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.bezelStyle = .roundedBezel
        f.isEditable = true
        f.isSelectable = true
        f.stringValue = text
        f.delegate = context.coordinator
        return f
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ConsumeTextField
        init(parent: ConsumeTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let f = obj.object as? NSTextField else { return }
            parent.text = f.stringValue
        }
    }
}

// MARK: - macOS 风格标题栏组件

struct TrafficTitlebar<Right: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let rightContent: () -> Right

    init(title: String, onClose: (() -> Void)? = nil, @ViewBuilder rightContent: @escaping () -> Right = { EmptyView() }) {
        self.title = title
        self.onClose = onClose
        self.rightContent = rightContent
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            rightContent()
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("关闭")
                .padding(.leading, 8)
            } else {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("关闭")
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.clear)
    }
}

// MARK: - 产品条目

struct ProductItem: Identifiable {
    let id = UUID()
    var name: String = ""
    var specs: String = ""
    var quantity: Int = 1
    var price: String = ""
    var imageData: Data? = nil
}

// MARK: - 颜色方块（支持透明马赛克）

struct ColorSwatch: View {
    let colorName: String
    let size: CGFloat

    init(_ colorName: String, size: CGFloat = 10) {
        self.colorName = colorName
        self.size = size
    }

    var body: some View {
        if colorName == "透明" {
            // 马赛克棋盘格
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<2) { row in
                    GridRow {
                        ForEach(0..<2) { col in
                            Rectangle()
                                .fill((row + col) % 2 == 0 ? Color(white: 0.85) : Color(white: 0.6))
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        } else if colorName == "白色" {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.95))
                .frame(width: size, height: size)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorFromPalette(colorName))
                .frame(width: size, height: size)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5))
        }
    }

    private func colorFromPalette(_ name: String) -> Color {
        Filament.colorValue(for: name)
    }
}

// MARK: - 圆形颜色块（迷你卡片用）

struct CircleSwatch: View {
    let colorName: String
    let size: CGFloat

    init(_ colorName: String, size: CGFloat = 10) {
        self.colorName = colorName
        self.size = size
    }

    var body: some View {
        if colorName == "透明" {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<2) { row in
                    GridRow {
                        ForEach(0..<2) { col in
                            Rectangle().fill((row + col) % 2 == 0 ? Color(white: 0.85) : Color(white: 0.6))
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        } else if colorName == "白色" {
            Circle().fill(Color(white: 0.95)).frame(width: size, height: size)
                .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        } else {
            Circle().fill(colorFromPalette(colorName)).frame(width: size, height: size)
                .overlay(Circle().stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5))
        }
    }

    private func colorFromPalette(_ name: String) -> Color {
        Filament.colorValue(for: name)
    }
}

struct DeviceDetailView: View {
    let device: Device
    @Environment(\.modelContext) private var modelContext
    @State private var showZoom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题 + 图片（左侧大图）
                HStack(alignment: .top, spacing: 16) {
                    if let data = device.imageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                            .onTapGesture { showZoom = true }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(device.brand) \(device.model)")
                            .font(.title2).fontWeight(.semibold)
                        Text("购入于 \(device.purchaseDate.formatted(.dateTime.year().month().day()))")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            deviceStatusBadge
                                .onTapGesture {
                                    guard device.status == "使用中" else { return }
                                    let alert = NSAlert()
                                    alert.messageText = "售出 \(device.brand) \(device.model)"
                                    alert.informativeText = "购入价格 ¥\(String(format: "%.0f", device.purchasePrice))，输入售出价格："
                                    let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                                    alert.accessoryView = tf
                                    alert.addButton(withTitle: "确认售出")
                                    alert.addButton(withTitle: "取消")
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        device.status = "已售出"
                                        device.sellPrice = Double(tf.stringValue) ?? 0
                                        device.sellDate = .now
                                        try? modelContext.save()
                                        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
                                    }
                                }
                        }
                    }
                    Spacer()
                }
                .frame(minHeight: 120)

                Divider()

                // 成本卡片（2列）
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatCard(value: "¥\(String(format: "%.0f", device.purchasePrice))", label: "购入价")
                    StatCard(value: "\(device.daysHeld)天", label: "已持有")
                    StatCard(value: "¥\(String(format: "%.2f", device.dailyCost))", label: "日成本")
                    StatCard(value: "¥\(String(format: "%.0f", device.monthlyCost))", label: "月均成本")
                }

                // 售出信息
                if device.status == "已售出", let sp = device.sellPrice {
                    Divider()
                    GroupBox("售出信息") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("售出价格").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.0f", sp))").font(.title3).fontWeight(.bold).foregroundStyle(.green)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("净成本").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.0f", device.purchasePrice - sp))").font(.title3).fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("实际日成本").font(.caption).foregroundStyle(.secondary)
                                Text("¥\(String(format: "%.2f", device.dailyCost))").font(.title3).fontWeight(.bold)
                            }
                        }
                        .padding(4)
                    }
                }

                // 备注
                if !device.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注").font(.headline)
                        Text(device.notes).font(.body).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .background(.clear)
        .sheet(isPresented: $showZoom) {
            VStack(spacing: 12) {
                HStack {
                    Text("\(device.brand) \(device.model)")
                        .font(.headline)
                    Spacer()
                    Button { showZoom = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
                if let data = device.imageData, let img = NSImage(data: data) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 720, maxHeight: 560)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(width: 780, height: 640)
        }
    }

    private func toggleSellStatus() {
        if device.status == "使用中" {
            let alert = NSAlert()
            alert.messageText = "售出 \(device.brand) \(device.model)"
            alert.informativeText = "购入价格 ¥\(String(format: "%.0f", device.purchasePrice))，输入售出价格："
            let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            alert.accessoryView = tf
            alert.addButton(withTitle: "确认售出")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                device.status = "已售出"
                device.sellPrice = Double(tf.stringValue) ?? 0
                device.sellDate = .now
                try? modelContext.save()
                NotificationCenter.default.post(name: filamentDataChanged, object: nil)
            }
        } else {
            device.status = "使用中"
            device.sellPrice = nil
            device.sellDate = nil
            try? modelContext.save()
            NotificationCenter.default.post(name: filamentDataChanged, object: nil)
        }
    }

    private var deviceStatusBadge: some View {
        if device.status == "已售出" {
            return Text("🔴 已售出")
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
        } else {
            return Text("🟢 使用中")
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - 编辑设备
struct EditDeviceView: View {
    let device: Device
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var brand = ""
    @State private var modelName = ""
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var notes = ""
    @State private var imageData: Data? = nil
    @State private var imageZoom: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "编辑设备")
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        HStack {
                            Text("图片").frame(width: 60, alignment: .leading)
                            Spacer()
                            ZStack {
                                if let data = imageData, let img = NSImage(data: data) {
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
                                Color.clear.contentShape(Rectangle()).onTapGesture(perform: pickDeviceImage)
                            }
                            .frame(width: 80, height: 80)
                            if imageData != nil {
                                Button("清除") { imageData = nil }
                                    .buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
                            }
                            Spacer()
                        }
                        if imageData != nil {
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
                    HStack { Text("品牌").frame(width: 60, alignment: .leading); TextField("品牌", text: $brand).textFieldStyle(.roundedBorder) }
                    HStack { Text("型号").frame(width: 60, alignment: .leading); TextField("型号", text: $modelName).textFieldStyle(.roundedBorder) }
                    Divider().padding(.vertical, 4)
                    HStack { Text("日期").frame(width: 60, alignment: .leading); DatePicker("", selection: $purchaseDate, displayedComponents: .date).labelsHidden(); Spacer() }
                    HStack { Text("价格").frame(width: 60, alignment: .leading); TextField("购入价格", text: $purchasePrice).textFieldStyle(.roundedBorder).frame(width: 120); Spacer(); Text("元").foregroundStyle(.secondary) }
                    HStack(alignment: .top) { Text("备注").frame(width: 60, alignment: .leading); TextField("选填", text: $notes).textFieldStyle(.roundedBorder) }
                }.padding(20)
            }
            Spacer(); Divider()
            HStack {
                Button("删除", role: .destructive) {
                    modelContext.delete(device)
                    try? modelContext.save()
                    NotificationCenter.default.post(name: filamentDataChanged, object: nil)
                    dismiss()
                }.foregroundStyle(.red)
                Spacer()
                Button("保存") {
                    guard let price = Double(purchasePrice), price > 0 else { return }
                    device.brand = brand.trimmingCharacters(in: .whitespaces)
                    device.model = modelName.trimmingCharacters(in: .whitespaces)
                    device.purchaseDate = purchaseDate
                    device.purchasePrice = price
                    device.notes = notes
                    device.imageData = croppedDeviceImageData()
                    try? modelContext.save()
                    NotificationCenter.default.post(name: filamentDataChanged, object: nil)
                    dismiss()
                }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(brand.isEmpty || modelName.isEmpty || (Double(purchasePrice) ?? 0) <= 0)
            }.padding(16)
        }
        .frame(width: 380, height: 400)
        .onAppear {
            brand = device.brand; modelName = device.model; purchaseDate = device.purchaseDate
            purchasePrice = String(format: "%.0f", device.purchasePrice); notes = device.notes; imageData = device.imageData
        }
    }

    private func pickDeviceImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url, let nsImage = NSImage(contentsOf: url) else { return }
            imageData = normalizedImageData(from: nsImage)
            imageZoom = 80
        }
    }

    private func croppedDeviceImageData() -> Data? {
        guard let data = imageData, let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return imageData
        }
        let scale = imageZoom / 80.0
        guard abs(scale - 1.0) > 0.01 else { return imageData }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropW = w / scale
        let cropH = h / scale
        let cropX = (w - cropW) / 2
        let cropY = (h - cropH) / 2
        guard let cropped = cgImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH)) else { return imageData }
        return jpegData(from: NSImage(cgImage: cropped, size: NSSize(width: 400, height: 400)))
    }

    private func normalizedImageData(from nsImage: NSImage) -> Data? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        let size = min(w, h)
        let cropRect = CGRect(x: (w - size) / 2, y: (h - size) / 2, width: size, height: size)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        let result = NSImage(size: NSSize(width: 400, height: 400))
        result.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 400, height: 400).fill()
        NSImage(cgImage: cropped, size: NSSize(width: size, height: size))
            .draw(in: NSRect(x: 0, y: 0, width: 400, height: 400))
        result.unlockFocus()
        return jpegData(from: result)
    }

    private func jpegData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
