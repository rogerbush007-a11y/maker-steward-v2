import SwiftUI
import Charts
import SwiftData

private struct ProductSalesGroup: Identifiable {
    let id: String
    let name: String
    let specs: String
    let products: [Product]

    var title: String {
        let trimmedSpecs = specs.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSpecs.isEmpty ? name : "\(name) · \(trimmedSpecs)"
    }

    var representative: Product? {
        products.sorted { $0.createdAt > $1.createdAt }.first
    }

    var salesDetails: [(sale: SaleRecord, product: Product)] {
        products
            .flatMap { product in product.sales.map { (sale: $0, product: product) } }
            .sorted { $0.sale.createdAt > $1.sale.createdAt }
    }

    var totalQuantity: Int {
        salesDetails.reduce(0) { $0 + $1.sale.quantity }
    }

    var totalRevenue: Double {
        salesDetails.reduce(0.0) { $0 + $1.sale.revenue }
    }

    var totalCost: Double {
        salesDetails.reduce(0.0) { sum, detail in
            let materialCost = Double(detail.sale.quantity) * detail.product.costPerUnit
            return sum + materialCost + detail.sale.shippingCost + detail.sale.packagingCost + detail.sale.platformFee
        }
    }

    var profit: Double {
        totalRevenue - totalCost
    }

    static func idFor(product: Product) -> String {
        "\(product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(product.specs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

struct StatisticsView: View {
    var isInline: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var allFilaments: [Filament] { (try? modelContext.fetch(FetchDescriptor<Filament>())) ?? [] }
    private var allConsumptions: [ConsumptionRecord] { (try? modelContext.fetch(FetchDescriptor<ConsumptionRecord>())) ?? [] }
    private var allProducts: [Product] { (try? modelContext.fetch(FetchDescriptor<Product>())) ?? [] }
    private var allDevices: [Device] { (try? modelContext.fetch(FetchDescriptor<Device>())) ?? [] }

    @State private var consumptionDim = "品牌"
    @State private var inventoryMixDim = "品牌"
    @State private var expandedProductID: String? = nil
    private let chartPalette: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .pink, .teal]

    private func chartColor(_ index: Int) -> Color {
        chartPalette[index % chartPalette.count]
    }

    private var totalSpending: Double { allFilaments.reduce(0) { $0 + $1.price } + allDevices.reduce(0) { $0 + $1.purchasePrice } }
    private var totalRevenue: Double { allProducts.flatMap(\.sales).reduce(0) { $0 + $1.revenue } }
    private var totalConsumptionGrams: Int { allConsumptions.reduce(0) { $0 + $1.weightUsed } }
    private var deviceDepreciation: Double { allDevices.reduce(0) { $0 + $1.accumulatedCost } }
    private var totalProfit: Double {
        let allSales = allProducts.flatMap(\.sales)
        let rev = allSales.reduce(0) { $0 + $1.revenue }
        let cost = allSales.reduce(0.0) { sum, sale in
            let mat = Double(sale.quantity) * (sale.product?.costPerUnit ?? 0)
            return sum + mat + sale.shippingCost + sale.packagingCost + sale.platformFee
        }
        return rev - cost - deviceDepreciation
    }

    @State private var showFilamentDetail = false
    @State private var showDeviceDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                overviewSection; Divider()
                spendingSection; Divider()
                inventoryMixSection; Divider()
                salesSection; Divider()
                consumptionSection
            }.padding(20).frame(maxWidth: .infinity)
        }.frame(maxWidth: isInline ? .infinity : 600, maxHeight: isInline ? .infinity : 520)
    }

    // MARK: - 总览卡片
    private var overviewSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
            OverviewCard(value: "¥\(formatK(totalSpending))", label: "总投入", icon: "banknote", color: .blue)
            OverviewCard(value: "¥\(formatK(totalRevenue))", label: "总收入", icon: "arrow.down", color: .green)
            OverviewCard(value: totalConsumptionGrams > 1000 ? "\(String(format: "%.1f", Double(totalConsumptionGrams)/1000))kg" : "\(totalConsumptionGrams)g", label: "总消耗", icon: "drop", color: .orange)
            OverviewCard(value: "¥\(formatK(deviceDepreciation))", label: "设备折旧", icon: "printer", color: .purple)
            OverviewCard(value: "¥\(formatK(totalProfit))", label: "总利润", icon: "chart.line.uptrend.xyaxis", color: totalProfit >= 0 ? .green : .red)
        }
    }

    // MARK: - 花费明细
    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "wallet.pass.fill").foregroundStyle(.blue); Text("花费明细").font(.headline) }
            let filamentCost = allFilaments.reduce(0) { $0 + $1.price }
            let deviceCost = allDevices.reduce(0) { $0 + $1.purchasePrice }

            HStack(spacing: 0) {
                HStack(spacing: 0) { Spacer(); Button(action: { withAnimation { showFilamentDetail.toggle() } }) {
                    VStack(spacing: 2) {
                        Image(systemName: "drop.fill").font(.body).foregroundStyle(.cyan)
                        Text("¥\(formatK(filamentCost))").font(.body).fontWeight(.bold).foregroundStyle(.cyan)
                        Text("耗材购入总花费").font(.caption2)
                        Text("共 \(allFilaments.count) 卷").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.tertiary).rotationEffect(.degrees(showFilamentDetail ? 180 : 0))
                    }.padding(10).frame(width: 150)
                }.buttonStyle(.plain).glassPanel(cornerRadius: 8, opacity: 0.48); Spacer() }.frame(maxWidth: .infinity)

                HStack(spacing: 0) { Spacer(); Button(action: { withAnimation { showDeviceDetail.toggle() } }) {
                    VStack(spacing: 2) {
                        Image(systemName: "printer.fill").font(.body).foregroundStyle(.purple)
                        Text("¥\(formatK(deviceCost))").font(.body).fontWeight(.bold).foregroundStyle(.purple)
                        Text("设备投入总花费").font(.caption2)
                        Text("共 \(allDevices.count) 台").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.tertiary).rotationEffect(.degrees(showDeviceDetail ? 180 : 0))
                    }.padding(10).frame(width: 150)
                }.buttonStyle(.plain).glassPanel(cornerRadius: 8, opacity: 0.48); Spacer() }.frame(maxWidth: .infinity)
            }

            if showFilamentDetail {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("品牌").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        Text("材质").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        Text("颜色").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .center)
                        Text("价格").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                    }.padding(.vertical, 6).padding(.horizontal, 8).background(.clear).clipShape(RoundedRectangle(cornerRadius: 4))
                    ForEach(allFilaments.sorted { $0.createdAt > $1.createdAt }, id: \.persistentModelID) { f in
                        HStack(spacing: 0) {
                            Text(f.brand).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            Text(f.material).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            Text(f.color).font(.caption).frame(maxWidth: .infinity, alignment: .center)
                            Text("¥\(String(format: "%.0f", f.price))").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
                        }.padding(.vertical, 3).padding(.horizontal, 8)
                        Divider().padding(.leading, 8)
                    }
                }.padding(8).glassPanel(cornerRadius: 8, opacity: 0.5)
            }

            if showDeviceDetail {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("品牌").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        Text("型号").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        Text("状态").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .center)
                        Text("净成本").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                    }.padding(.vertical, 6).padding(.horizontal, 8).background(.clear).clipShape(RoundedRectangle(cornerRadius: 4))
                    ForEach(allDevices.sorted { $0.createdAt > $1.createdAt }, id: \.persistentModelID) { d in
                        let netCost = d.status == "已售出" ? d.purchasePrice - (d.sellPrice ?? 0) : d.purchasePrice
                        HStack(spacing: 0) {
                            Text(d.brand).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            Text(d.model).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            Text(d.status).font(.caption).frame(maxWidth: .infinity, alignment: .center)
                            Text("¥\(String(format: "%.0f", netCost))").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
                        }.padding(.vertical, 3).padding(.horizontal, 8)
                        Divider().padding(.leading, 8)
                    }
                }.padding(8).glassPanel(cornerRadius: 8, opacity: 0.5)
            }
        }
    }

    // MARK: - 耗材购入占比
    private var inventoryMixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill").foregroundStyle(.teal)
                Text("耗材购入占比").font(.headline)
                Spacer()
                Picker("", selection: $inventoryMixDim) {
                    Text("按品牌").tag("品牌")
                    Text("按材质").tag("材质")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            let data = inventoryMixData
            if data.isEmpty {
                Text("暂无耗材购入数据").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else {
                HStack(alignment: .center, spacing: 32) {
                    Spacer()
                    Chart(data, id: \.key) { item in
                        let total = data.reduce(0) { $0 + $1.count }
                        let pct = Double(item.count) / Double(max(total, 1)) * 100
                        SectorMark(angle: .value("卷数", item.count), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("类别", item.key))
                            .annotation(position: .overlay) {
                                if pct > 8 {
                                    Text("\(String(format: "%.0f", pct))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .chartForegroundStyleScale(
                        domain: data.map(\.key),
                        range: data.indices.map { chartColor($0) }
                    )
                    .chartLegend(.hidden)
                    .frame(width: 150, height: 150)

                    VStack(spacing: 6) {
                        let total = data.reduce(0) { $0 + $1.count }
                        ForEach(Array(data.prefix(6).enumerated()), id: \.offset) { i, item in
                            let pct = Double(item.count) / Double(max(total, 1)) * 100
                            HStack(spacing: 0) {
                                Circle().fill(chartColor(i)).frame(width: 10, height: 10).padding(.trailing, 6)
                                Text(item.key).font(.subheadline).lineLimit(1).frame(width: 110, alignment: .leading)
                                Text("\(item.count)卷").font(.subheadline).fontWeight(.medium).frame(width: 44, alignment: .center)
                                Text("\(String(format: "%.1f", pct))%").font(.subheadline).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                            }.padding(.vertical, 6)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - 产品销售分析
    private var salesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "cart.fill").foregroundStyle(.blue); Text("产品销售分析").font(.headline) }

            let groups = productSalesGroups
            if groups.isEmpty {
                Text("暂无产品销售数据").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else {
                let totalSold = groups.reduce(0) { $0 + $1.totalQuantity }
                let rankedGroups = groups.sorted { $0.totalQuantity > $1.totalQuantity }
                HStack(alignment: .center, spacing: 32) {
                    Spacer()
                    Chart(rankedGroups, id: \.id) { group in
                        SectorMark(angle: .value("销量", group.totalQuantity), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("产品", group.title))
                            .annotation(position: .overlay) {
                                let pct = Double(group.totalQuantity) / Double(max(totalSold, 1)) * 100
                                if pct > 8 { Text("\(String(format: "%.0f", pct))%").font(.caption).fontWeight(.bold).foregroundStyle(.white) }
                            }
                    }
                    .chartForegroundStyleScale(
                        domain: rankedGroups.map(\.title),
                        range: rankedGroups.indices.map { chartColor($0) }
                    )
                    .chartLegend(.hidden).frame(width: 160, height: 160)

                    VStack(spacing: 6) {
                        ForEach(Array(rankedGroups.prefix(5).enumerated()), id: \.element.id) { i, group in
                            let pct = Double(group.totalQuantity) / Double(max(totalSold, 1)) * 100
                            HStack(spacing: 0) {
                                Circle().fill(chartColor(i)).frame(width: 10, height: 10).padding(.trailing, 6)
                                if let data = group.representative?.imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                Text(group.title).font(.subheadline).lineLimit(1).frame(width: 100, alignment: .leading)
                                Text("\(group.totalQuantity)个").font(.subheadline).fontWeight(.medium).frame(width: 40, alignment: .center)
                                Text("\(String(format: "%.1f", pct))%").font(.subheadline).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                            }.padding(.vertical, 6)
                        }
                    }
                    Spacer()
                }

                Divider().padding(.vertical, 4)

                Text("销售排行").font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 32) {
                    Spacer()
                    VStack(spacing: 4) {
                        let ranked = groups.sorted { $0.totalRevenue > $1.totalRevenue }
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { i, group in
                            salesRankRow(rank: i + 1, group: group)
                        }
                    }.frame(width: 360)
                    Spacer()
                }

                Divider().padding(.vertical, 4)

                platformSalesTable
            }
        }
    }

    private var platformSalesTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("售出平台统计").font(.subheadline).fontWeight(.semibold)
            let rows = platformSalesData
            if rows.isEmpty {
                Text("暂无平台销售数据").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 28) {
                    Spacer()
                    Chart(rows, id: \.platform) { row in
                        let total = rows.reduce(0) { $0 + $1.quantity }
                        let pct = Double(row.quantity) / Double(max(total, 1)) * 100
                        SectorMark(angle: .value("销量", row.quantity), innerRadius: .ratio(0.52))
                            .foregroundStyle(by: .value("平台", row.platform))
                            .annotation(position: .overlay) {
                                if pct >= 8 {
                                    Text("\(String(format: "%.0f", pct))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .chartForegroundStyleScale(
                        domain: rows.map(\.platform),
                        range: rows.indices.map { chartColor($0) }
                    )
                    .chartLegend(.hidden)
                    .frame(width: 150, height: 150)

                    VStack(spacing: 6) {
                        let totalQty = rows.reduce(0) { $0 + $1.quantity }
                        ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { i, row in
                            let pct = Double(row.quantity) / Double(max(totalQty, 1)) * 100
                            HStack(spacing: 0) {
                                Circle().fill(chartColor(i)).frame(width: 10, height: 10).padding(.trailing, 6)
                                Text(row.platform).font(.subheadline).lineLimit(1).frame(width: 90, alignment: .leading)
                                Text("\(row.quantity)个").font(.subheadline).fontWeight(.medium).frame(width: 44, alignment: .center)
                                Text("\(String(format: "%.1f", pct))%").font(.subheadline).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                                Text("¥\(String(format: "%.0f", row.revenue))").font(.subheadline).frame(width: 62, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    Spacer()
                }
                .glassPanel(cornerRadius: 8, opacity: 0.45)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("平台").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        Text("销量").font(.caption).fontWeight(.semibold).frame(width: 60, alignment: .trailing)
                        Text("销售额").font(.caption).fontWeight(.semibold).frame(width: 80, alignment: .trailing)
                        Text("订单").font(.caption).fontWeight(.semibold).frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)

                    ForEach(rows, id: \.platform) { row in
                        HStack(spacing: 0) {
                            Text(row.platform).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(row.quantity)").font(.caption).frame(width: 60, alignment: .trailing)
                            Text("¥\(String(format: "%.0f", row.revenue))").font(.caption).frame(width: 80, alignment: .trailing)
                            Text("\(row.orders)").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        Divider().padding(.leading, 8)
                    }
                }
                .glassPanel(cornerRadius: 8, opacity: 0.45)
            }
        }
    }

    @ViewBuilder
    private func salesRankRow(rank: Int, group: ProductSalesGroup) -> some View {
        let isExpanded = expandedProductID == group.id

        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expandedProductID = isExpanded ? nil : group.id } }) {
                HStack(spacing: 4) {
                    Text("#\(rank)").font(.caption).foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
                    if let data = group.representative?.imageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(group.title).font(.subheadline).fontWeight(.medium).lineLimit(1)
                        .frame(maxWidth: 130, alignment: .leading)
                    Color.clear.frame(width: 60)
                    Text("售\(group.totalQuantity)").font(.caption).foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                    Text("¥\(String(format: "%.0f", group.totalRevenue))").font(.subheadline).fontWeight(.medium).frame(width: 44, alignment: .trailing)
                    Text("+¥\(String(format: "%.2f", group.profit))").font(.caption).fontWeight(.semibold)
                        .foregroundStyle(group.profit >= 0 ? .green : .red).frame(width: 56, alignment: .trailing)
                    Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.tertiary).frame(width: 12)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }.padding(.vertical, 6).padding(.horizontal, 4).contentShape(Rectangle())
                    .glassPanel(cornerRadius: 6, opacity: 0.42)
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.vertical, 4)
                    ForEach(group.salesDetails, id: \.sale.persistentModelID) { detail in
                        let sale = detail.sale
                        let saleRev = Double(sale.quantity) * sale.salePrice
                        let saleMat = Double(sale.quantity) * detail.product.costPerUnit
                        let saleProfit = saleRev - saleMat - sale.shippingCost - sale.packagingCost - sale.platformFee
                        HStack(spacing: 4) {
                            Text(sale.createdAt.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary).fixedSize()
                            Text("\(sale.quantity)个").font(.caption).frame(width: 28, alignment: .center).fixedSize()
                            Text("¥\(String(format: "%.0f", saleRev))").font(.caption).fontWeight(.medium).fixedSize()
                            Spacer(minLength: 2)
                            Text("+¥\(String(format: "%.2f", saleProfit))").font(.caption).fontWeight(.semibold).foregroundStyle(saleProfit >= 0 ? .green : .red).fixedSize()
                        }.padding(.horizontal, 12).padding(.vertical, 4)
                        Divider().padding(.leading, 12)
                    }
                }.padding(.leading, 20).glassPanel(cornerRadius: 6, opacity: 0.34)
            }
        }
    }

    private var productSalesGroups: [ProductSalesGroup] {
        Dictionary(grouping: allProducts.filter { !$0.sales.isEmpty }) { ProductSalesGroup.idFor(product: $0) }
            .compactMap { id, products in
                guard let first = products.first else { return nil }
                return ProductSalesGroup(
                    id: id,
                    name: first.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    specs: first.specs.trimmingCharacters(in: .whitespacesAndNewlines),
                    products: products
                )
            }
    }

    // MARK: - 耗材消耗分析
    private var consumptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").foregroundStyle(.cyan)
                Text("耗材消耗分析").font(.headline)
                Spacer()
                Picker("", selection: $consumptionDim) { Text("按品牌").tag("品牌"); Text("按材质").tag("材质"); Text("按颜色").tag("颜色") }
                    .pickerStyle(.segmented).frame(width: 240)
            }
            let data = consumptionData
            if data.isEmpty {
                Text("暂无消耗数据").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else {
                HStack(alignment: .center, spacing: 32) {
                    Spacer()
                    Chart(data, id: \.key) { item in
                        let total = data.reduce(0) { $0 + $1.total }
                        let pct = Double(item.total) / Double(total) * 100
                        SectorMark(angle: .value("消耗", item.total), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("维度", item.key))
                            .annotation(position: .overlay) { if pct > 8 { Text("\(String(format: "%.0f", pct))%").font(.callout).fontWeight(.bold).foregroundStyle(.white) } }
                    }
                    .chartForegroundStyleScale(
                        domain: data.map(\.key),
                        range: data.indices.map { chartColor($0) }
                    )
                    .chartLegend(.hidden).frame(width: 150, height: 150)

                    VStack(spacing: 6) {
                        let total = data.reduce(0) { $0 + $1.total }
                        ForEach(Array(data.prefix(5).enumerated()), id: \.offset) { i, item in
                            let pct = Double(item.total) / Double(total) * 100
                            HStack(spacing: 0) {
                                Circle().fill(chartColor(i)).frame(width: 10, height: 10).padding(.trailing, 6)
                                Text(item.key).font(.subheadline).foregroundStyle(.primary).lineLimit(1).frame(width: 100, alignment: .leading)
                                Text("\(item.total)g").font(.subheadline).fontWeight(.medium).frame(width: 40, alignment: .center)
                                Text("\(String(format: "%.1f", pct))%").font(.subheadline).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                            }.padding(.vertical, 6)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var consumptionData: [(key: String, total: Int)] {
        var dict: [String: Int] = [:]
        for r in allConsumptions {
            let key: String
            switch consumptionDim {
            case "材质": key = r.filament?.material ?? "未知"
            case "颜色": key = r.filament?.color ?? "未知"
            default: key = r.filament?.brand ?? "未知"
            }
            dict[key, default: 0] += r.weightUsed
        }
        return dict.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var inventoryMixData: [(key: String, count: Int)] {
        var dict: [String: Int] = [:]
        for filament in allFilaments {
            let key = inventoryMixDim == "材质" ? filament.material : filament.brand
            dict[key.isEmpty ? "未知" : key, default: 0] += 1
        }
        return dict.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var platformSalesData: [(platform: String, quantity: Int, revenue: Double, orders: Int)] {
        var dict: [String: (quantity: Int, revenue: Double, orders: Int)] = [:]
        for sale in allProducts.flatMap(\.sales) {
            let platform = sale.buyer.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = platform.isEmpty ? "未填写" : platform
            var current = dict[key] ?? (quantity: 0, revenue: 0, orders: 0)
            current.quantity += sale.quantity
            current.revenue += sale.revenue
            current.orders += 1
            dict[key] = current
        }
        return dict
            .map { (platform: $0.key, quantity: $0.value.quantity, revenue: $0.value.revenue, orders: $0.value.orders) }
            .sorted {
                if $0.revenue != $1.revenue { return $0.revenue > $1.revenue }
                return $0.quantity > $1.quantity
            }
    }

    private func formatK(_ value: Double) -> String {
        if abs(value) >= 10000 { return String(format: "%.1fw", value / 10000) }
        else if abs(value) >= 1000 { return String(format: "%.1fk", value / 1000) }
        return String(format: "%.0f", value)
    }
}

struct OverviewCard: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title2).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption)
        }.padding(14).frame(maxWidth: .infinity).glassPanel(cornerRadius: 10, opacity: 0.5)
    }
}
