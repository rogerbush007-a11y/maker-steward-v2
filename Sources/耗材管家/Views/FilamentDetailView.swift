import SwiftUI
import SwiftData

struct FilamentDetailView: View {
    let filament: Filament
    let store: FilamentStore?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showConsumptionSheet = false
    @State private var consumeWeight = ""
    @State private var modelName = ""
    @State private var showRestockAlert = false
    @State private var restockPrice = ""
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    // 编辑用临时数据
    @State private var editBrand = ""
    @State private var editMaterial = ""
    @State private var editColor = ""
    @State private var editWeight = 1000
    @State private var editPrice = ""
    @State private var editAlertThreshold = 200

    var body: some View {
        VStack(spacing: 0) {
            TrafficTitlebar(title: "详细信息", rightContent: {
                HStack(spacing: 6) {
                    Button("消耗") { showConsumptionSheet = true }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("入库") { showRestockAlert = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("编辑") { showEditSheet = true }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("删除") { showDeleteAlert = true }
                        .buttonStyle(.bordered).controlSize(.small).foregroundStyle(.red)
                }
            })
            Divider()
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 预警横幅
                if filament.needsReorder {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("剩余 \(filament.remainingWeight)g，按当前速度约 \(filament.estimatedDaysUntilEmpty ?? 0) 天后用完，建议补货 \(filament.suggestedReorderQuantity) 卷")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .glassPanel(cornerRadius: 8, opacity: 0.55)
                }

                // 标题
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            ColorSwatch(filament.color, size: 16)
                            Text("\(filament.brand) \(filament.material)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        Text(filament.color)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("购入于 \(filament.purchaseDate.formatted(.dateTime.year().month().day()))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                Divider()

                // 信息网格
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    InfoTile(label: "品牌", value: filament.brand)
                    InfoTile(label: "材质", value: filament.material)
                    InfoTile(label: "颜色", value: filament.color)
                    InfoTile(label: "单卷重量", value: "\(filament.weight)g")
                    InfoTile(label: "剩余量", value: "\(filament.remainingWeight)g")
                    InfoTile(label: "单价", value: formatPrice(filament.price))
                    InfoTile(label: "预警线", value: "\(filament.alertThreshold)g")
                    if let store = store {
                        InfoTile(label: "历史最低", value: formatPrice(
                            store.lowestPrice(for: filament.brand, material: filament.material, color: filament.color)
                        ))
                    }
                }

                // 剩余进度条
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("剩余量")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(filament.remainingWeight)g / \(filament.weight)g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.thinMaterial)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, filament.needsReorder ? .red : .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(filament.usagePercent) / 100.0, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("已使用 \(filament.usedWeight)g（\(Int(100 - filament.usagePercent))%）")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // 消耗速率
                if filament.monthlyConsumptionRate > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("消耗分析")
                            .font(.headline)
                        HStack(spacing: 20) {
                            StatBox(value: "\(Int(filament.monthlyConsumptionRate))g", label: "月均消耗")
                            if let days = filament.estimatedDaysUntilEmpty {
                                StatBox(value: "\(days) 天", label: "预计用完")
                            }
                            StatBox(value: "\(filament.consumptionInLastMonths(6))g", label: "近半年消耗")
                        }
                    }
                }

                // 消耗记录列表
                if !filament.consumptions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("消耗记录")
                            .font(.headline)
                        ForEach(filament.consumptions.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10)) { record in
                            HStack {
                                Text(record.createdAt.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                Text("\(record.weightUsed)g")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .frame(width: 60, alignment: .leading)
                                Text(record.modelName.isEmpty ? "—" : record.modelName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .background(.thinMaterial.opacity(0.18))
        }
        .sheet(isPresented: $showConsumptionSheet) {
            consumptionSheet
        }
        .alert("补充入库", isPresented: $showRestockAlert) {
            TextField("单卷价格（可选）", text: $restockPrice)
            Button("取消", role: .cancel) { restockPrice = "" }
            Button("入库") {
                let price = Double(restockPrice)
                store?.restockFilament(filament: filament, price: price)
                restockPrice = ""
            }
        } message: {
            Text("将 \(filament.brand) \(filament.material) \(filament.color) 重置为满卷(\(filament.weight)g)")
        }
        .sheet(isPresented: $showEditSheet) {
            editFilamentSheet
        }
        .alert("删除耗材", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                store?.deleteFilament(filament)
                dismiss()
            }
        } message: {
            Text("确定要删除「\(filament.brand) \(filament.material) \(filament.color)」(¥\(String(format: "%.0f", filament.price))) 吗？此操作不可恢复。")
        }
    }

    // MARK: - 消耗表单

    private var consumptionSheet: some View {
        VStack(spacing: 16) {
            Text("记录消耗")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("消耗重量（克）", text: $consumeWeight)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            TextField("打印模型（可选）", text: $modelName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            HStack(spacing: 12) {
                Button("取消") {
                    showConsumptionSheet = false
                    consumeWeight = ""
                    modelName = ""
                }
                .keyboardShortcut(.cancelAction)

                Button("确认消耗") {
                    if let weight = parsedGramInput(consumeWeight), weight <= filament.remainingWeight {
                        store?.recordConsumption(filament: filament, weightUsed: weight, modelName: modelName)
                    }
                    showConsumptionSheet = false
                    consumeWeight = ""
                    modelName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedGramInput(consumeWeight) == nil)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    // MARK: - 编辑表单

    private var editFilamentSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑耗材")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            VStack(spacing: 14) {
                HStack {
                    Text("品牌").frame(width: 60, alignment: .leading)
                    TextField("品牌", text: $editBrand)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("材质").frame(width: 60, alignment: .leading)
                    TextField("材质", text: $editMaterial)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("颜色").frame(width: 60, alignment: .leading)
                    TextField("颜色", text: $editColor)
                        .textFieldStyle(.roundedBorder)
                }
                Divider()
                HStack {
                    Text("重量").frame(width: 60, alignment: .leading)
                    Picker("", selection: $editWeight) {
                        Text("200g").tag(200); Text("500g").tag(500)
                        Text("1kg").tag(1000); Text("2kg").tag(2000); Text("3kg").tag(3000)
                    }
                    .labelsHidden()
                    Spacer()
                    Text("克").foregroundStyle(.secondary)
                }
                HStack {
                    Text("价格").frame(width: 60, alignment: .leading)
                    TextField("价格", text: $editPrice)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("元").foregroundStyle(.secondary)
                    Spacer()
                }
                HStack {
                    Text("预警").frame(width: 60, alignment: .leading)
                    Stepper(value: $editAlertThreshold, in: 50...1000, step: 50) {
                        Text("\(editAlertThreshold) 克")
                    }
                    Spacer()
                }
            }
            .padding(20)

            Spacer()

            Divider()
            HStack {
                Button("取消") { showEditSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    saveEdit()
                    showEditSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editBrand.isEmpty || editMaterial.isEmpty || editColor.isEmpty || (Double(editPrice) ?? 0) <= 0)
            }
            .padding(16)
        }
        .frame(width: 380, height: 400)
        .onAppear {
            editBrand = filament.brand
            editMaterial = filament.material
            editColor = filament.color
            editWeight = filament.weight
            editPrice = String(format: "%.0f", filament.price)
            editAlertThreshold = filament.alertThreshold
        }
    }

    private func saveEdit() {
        guard let price = Double(editPrice), price > 0 else { return }
        Filament.rememberPreset(brand: editBrand, material: editMaterial, color: editColor)
        filament.brand = editBrand
        filament.material = editMaterial
        filament.color = editColor
        filament.weight = editWeight
        filament.price = price
        filament.alertThreshold = editAlertThreshold
        // 如果原来是已用完状态，改回使用中
        if filament.status == FilamentStatus.usedUp.rawValue {
            filament.status = FilamentStatus.active.rawValue
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .filamentDataChanged, object: nil)
    }

    // MARK: - 辅助

    private func formatPrice(_ price: Double) -> String {
        price > 0 ? "¥\(String(format: "%.2f", price))" : "—"
    }

    private func colorFromName(_ name: String) -> Color {
        Filament.colorValue(for: name)
    }
}

// MARK: - 辅助视图

struct InfoTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 6, opacity: 0.5)
    }
}

struct StatBox: View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 6, opacity: 0.5)
    }
}
