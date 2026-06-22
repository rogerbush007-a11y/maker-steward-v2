import Foundation
import SwiftUI
import SwiftData

/// 耗材数据管理与统计逻辑
@Observable
final class FilamentStore {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - 耗材增删改查

    func addFilament(_ filament: Filament) {
        Filament.rememberPreset(brand: filament.brand, material: filament.material, color: filament.color)
        modelContext.insert(filament)
        // 入库同时记一笔价格记录
        let priceRecord = PriceRecord(
            filament: filament,
            brand: filament.brand,
            material: filament.material,
            color: filament.color,
            price: filament.price,
            createdAt: filament.purchaseDate
        )
        modelContext.insert(priceRecord)
        filament.priceHistory.append(priceRecord)
        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
    }

    func deleteFilament(_ filament: Filament) {
        modelContext.delete(filament)
        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
    }

    func recordConsumption(filament: Filament, weightUsed: Int, modelName: String = "") {
        filament.remainingWeight = max(0, filament.remainingWeight - weightUsed)
        if filament.remainingWeight <= 0 {
            // 用完即删
            modelContext.delete(filament)
        } else {
            let record = ConsumptionRecord(
                filament: filament,
                weightUsed: weightUsed,
                modelName: modelName
            )
            filament.consumptions.append(record)
            modelContext.insert(record)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
    }

    // 入库补充
    func restockFilament(filament: Filament, additionalWeight: Int? = nil, price: Double? = nil) {
        filament.remainingWeight = filament.weight  // 重置为满卷
        if filament.status == FilamentStatus.usedUp.rawValue {
            filament.status = FilamentStatus.active.rawValue
        }
        if let price = price {
            filament.price = price
            let priceRecord = PriceRecord(
                filament: filament,
                brand: filament.brand,
                material: filament.material,
                color: filament.color,
                price: price,
                createdAt: .now
            )
            modelContext.insert(priceRecord)
            filament.priceHistory.append(priceRecord)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: filamentDataChanged, object: nil)
    }

    // MARK: - 统计计算

    /// 获取某材质的所有价格记录（用于趋势图）
    func priceHistoryFor(material: String, brand: String? = nil) -> [PriceRecord] {
        let predicate: Predicate<PriceRecord>
        if let brand = brand {
            predicate = #Predicate { $0.material == material && $0.brand == brand }
        } else {
            predicate = #Predicate { $0.material == material }
        }
        let descriptor = FetchDescriptor<PriceRecord>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 某品牌+材质的平均价
    func averagePrice(for brand: String, material: String, color: String) -> Double {
        let predicate = #Predicate<Filament> {
            $0.brand == brand && $0.material == material && $0.color == color
        }
        let descriptor = FetchDescriptor<Filament>(predicate: predicate)
        let filaments = (try? modelContext.fetch(descriptor)) ?? []
        guard !filaments.isEmpty else { return 0 }
        return filaments.map(\.price).reduce(0, +) / Double(filaments.count)
    }

    /// 某品牌+材质的历史最低价
    func lowestPrice(for brand: String, material: String, color: String) -> Double {
        let predicate = #Predicate<Filament> {
            $0.brand == brand && $0.material == material && $0.color == color
        }
        let descriptor = FetchDescriptor<Filament>(predicate: predicate)
        let filaments = (try? modelContext.fetch(descriptor)) ?? []
        return filaments.map(\.price).min() ?? 0
    }

    /// 最近 N 个月每种材质的消耗总量
    func consumptionByMaterial(lastMonths: Int = 6) -> [(material: String, total: Int)] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -lastMonths, to: .now) ?? .now
        let predicate = #Predicate<ConsumptionRecord> { $0.createdAt >= cutoff }
        let descriptor = FetchDescriptor<ConsumptionRecord>(predicate: predicate)
        let records = (try? modelContext.fetch(descriptor)) ?? []
        var dict: [String: Int] = [:]
        for r in records {
            let mat = r.filament?.material ?? "未知"
            dict[mat, default: 0] += r.weightUsed
        }
        return dict.sorted { $0.value > $1.value }.map { (material: $0.key, total: $0.value) }
    }

    /// 最近 N 个月每月消耗量
    func monthlyConsumption(lastMonths: Int = 6) -> [(month: String, total: Int)] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -lastMonths, to: .now) ?? .now
        let predicate = #Predicate<ConsumptionRecord> { $0.createdAt >= cutoff }
        let descriptor = FetchDescriptor<ConsumptionRecord>(predicate: predicate)
        let records = (try? modelContext.fetch(descriptor)) ?? []
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        var dict: [String: Int] = [:]
        for r in records {
            let key = formatter.string(from: r.createdAt)
            dict[key, default: 0] += r.weightUsed
        }
        let months = (0..<lastMonths).compactMap { i -> String? in
            guard let d = Calendar.current.date(byAdding: .month, value: -i, to: .now) else { return nil }
            return formatter.string(from: d)
        }.reversed()
        return months.map { ($0, dict[$0] ?? 0) }
    }

    /// 品牌花费汇总
    func spendingByBrand() -> [(brand: String, total: Double)] {
        let descriptor = FetchDescriptor<Filament>()
        let filaments = (try? modelContext.fetch(descriptor)) ?? []
        var dict: [String: Double] = [:]
        for f in filaments {
            dict[f.brand, default: 0] += f.price
        }
        return dict.sorted { $0.value > $1.value }.map { (brand: $0.key, total: $0.value) }
    }
}
