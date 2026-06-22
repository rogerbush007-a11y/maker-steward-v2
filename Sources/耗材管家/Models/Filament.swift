import Foundation
import SwiftData

/// 耗材状态
enum FilamentStatus: String, Codable, CaseIterable {
    case active = "使用中"
    case usedUp = "已用完"
    case archived = "已归档"
}

/// 耗材卷
@Model
final class Filament {
    /// 品牌
    var brand: String
    /// 材质
    var material: String
    /// 颜色
    var color: String
    /// 单卷总重量（克）
    var weight: Int
    /// 剩余重量（克）
    var remainingWeight: Int
    /// 购买价格（单卷）
    var price: Double
    /// 预警线（克）
    var alertThreshold: Int
    /// 购买日期
    var purchaseDate: Date
    /// 状态
    var status: String  // active, usedUp, archived
    /// 创建时间
    var createdAt: Date
    /// 图片
    var imageData: Data?

    // 关联
    @Relationship(deleteRule: .cascade) var consumptions: [ConsumptionRecord] = []
    @Relationship(deleteRule: .cascade) var priceHistory: [PriceRecord] = []

    init(
        brand: String,
        material: String,
        color: String,
        weight: Int,
        remainingWeight: Int? = nil,
        price: Double,
        alertThreshold: Int = 200,
        purchaseDate: Date = .now,
        status: FilamentStatus = .active,
        imageData: Data? = nil
    ) {
        self.brand = brand
        self.material = material
        self.color = color
        self.weight = weight
        self.remainingWeight = remainingWeight ?? weight
        self.price = price
        self.alertThreshold = alertThreshold
        self.purchaseDate = purchaseDate
        self.status = status.rawValue
        self.imageData = imageData
        self.createdAt = .now
    }

    // MARK: - 计算属性

    /// 已使用的重量
    var usedWeight: Int { weight - remainingWeight }

    /// 使用百分比
    var usagePercent: Double {
        guard weight > 0 else { return 0 }
        return Double(remainingWeight) / Double(weight) * 100
    }

    /// 是否需要补货预警
    var needsReorder: Bool {
        remainingWeight <= alertThreshold && status == FilamentStatus.active.rawValue
    }

    /// 最近6个月的消耗量（克）
    func consumptionInLastMonths(_ months: Int = 6) -> Int {
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: .now) ?? .now
        return consumptions
            .filter { $0.createdAt >= cutoff }
            .reduce(0) { $0 + $1.weightUsed }
    }

    /// 月均消耗速度（克/月）
    var monthlyConsumptionRate: Double {
        let total = consumptionInLastMonths(6)
        let daysSinceFirst = daysSinceFirstConsumption
        guard daysSinceFirst > 0 else { return 0 }
        return Double(total) / (Double(daysSinceFirst) / 30.0)
    }

    /// 预计用完还剩多少天
    var estimatedDaysUntilEmpty: Int? {
        let rate = monthlyConsumptionRate
        guard rate > 0, remainingWeight > 0 else { return nil }
        return Int(Double(remainingWeight) / rate * 30.0)
    }

    private var daysSinceFirstConsumption: Int {
        guard let first = consumptions.sorted(by: { $0.createdAt < $1.createdAt }).first else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: first.createdAt, to: .now).day ?? 0
    }

    /// 建议补货数量
    var suggestedReorderQuantity: Int {
        guard needsReorder, monthlyConsumptionRate > 0 else { return 0 }
        // 基于月消耗量，建议补 2-3 个月的量
        let monthlyVolume = monthlyConsumptionRate / Double(weight)
        let suggested = max(1, Int(ceil(monthlyVolume * 2.5)))
        return min(suggested, 10) // 最多建议 10 卷
    }

    /// 当前库存状态描述
    var statusDescription: String {
        if status == FilamentStatus.usedUp.rawValue { return "已用完" }
        if status == FilamentStatus.archived.rawValue { return "已归档" }
        if needsReorder {
            return "⚠️ 需补货（剩余\(remainingWeight)g）"
        }
        return "剩余\(remainingWeight)g"
    }
}

// MARK: - 预设值
extension Filament {
    static let presetBrands = [
        "Bambu Lab", "eSun", "Polymaker", "天瑞",
        "Sunlu", "Elegoo", "Anycubic", "Creality",
        "闪铸", "三绿", "金丝", "其他"
    ]

    static let presetMaterials = [
        "PLA", "PLA+", "PETG", "ABS", "ASA",
        "TPU", "PA(尼龙)", "PA-CF(碳纤尼龙)", "PC",
        "PETG-CF", "PLA-CF", "PVA(水溶)", "HIPS", "其他"
    ]

    static let presetColors = [
        "黑色", "白色", "灰色", "深空灰",
        "红色", "蓝色", "深蓝", "绿色",
        "黄色", "橙色", "紫色", "粉色",
        "棕色", "透明", "夜光绿", "丝绸银",
        "丝绸金", "渐变", "哑光黑", "木质", "其他"
    ]
}
