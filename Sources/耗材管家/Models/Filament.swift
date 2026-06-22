import Foundation
import SwiftData
import SwiftUI

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
    private static let defaultPresetBrands = [
        "Bambu Lab", "eSun", "Polymaker", "天瑞",
        "Sunlu", "Elegoo", "Anycubic", "Creality",
        "闪铸", "三绿", "金丝", "其他"
    ]

    private static let defaultPresetMaterials = [
        "PLA", "PLA+", "PETG", "ABS", "ASA",
        "TPU", "PA(尼龙)", "PA-CF(碳纤尼龙)", "PC",
        "PETG-CF", "PLA-CF", "PVA(水溶)", "HIPS", "其他"
    ]

    private static let defaultPresetColors = [
        "黑色", "白色", "灰色", "深空灰",
        "红色", "蓝色", "深蓝", "绿色",
        "黄色", "橙色", "紫色", "粉色",
        "棕色", "透明", "夜光绿", "丝绸银",
        "丝绸金", "渐变", "哑光黑", "木质",
        "米色", "奶白", "象牙白", "银色", "金色",
        "玫瑰金", "青色", "湖蓝", "天蓝", "墨绿",
        "军绿色", "酒红", "荧光绿", "荧光橙", "彩虹", "其他"
    ]

    static var presetBrands: [String] {
        mergedPresets(defaultPresetBrands, key: "filament_custom_brands")
    }

    static var presetMaterials: [String] {
        mergedPresets(defaultPresetMaterials, key: "filament_custom_materials")
    }

    static var presetColors: [String] {
        mergedPresets(defaultPresetColors, key: "filament_custom_colors")
    }

    static func rememberPreset(brand: String? = nil, material: String? = nil, color: String? = nil) {
        appendPreset(brand, defaults: defaultPresetBrands, key: "filament_custom_brands")
        appendPreset(material, defaults: defaultPresetMaterials, key: "filament_custom_materials")
        appendPreset(color, defaults: defaultPresetColors, key: "filament_custom_colors")
    }

    static func colorValue(for name: String) -> Color {
        let colors: [String: Color] = [
            "黑色": .black, "白色": Color(white: 0.95), "灰色": .gray, "深空灰": Color(white: 0.3),
            "红色": .red, "蓝色": .blue, "深蓝": Color(red: 0, green: 0, blue: 0.5),
            "绿色": .green, "黄色": .yellow, "橙色": .orange, "紫色": .purple,
            "粉色": .pink, "棕色": .brown, "透明": Color(white: 0.7).opacity(0.3),
            "夜光绿": Color(red: 0, green: 0.9, blue: 0.3), "丝绸银": Color(white: 0.7),
            "丝绸金": Color(red: 0.85, green: 0.65, blue: 0.2), "哑光黑": Color(white: 0.15),
            "木质": Color(red: 0.6, green: 0.4, blue: 0.2), "米色": Color(red: 0.86, green: 0.78, blue: 0.62),
            "奶白": Color(red: 0.96, green: 0.93, blue: 0.84), "象牙白": Color(red: 1.0, green: 0.96, blue: 0.82),
            "银色": Color(white: 0.78), "金色": Color(red: 0.95, green: 0.72, blue: 0.18),
            "玫瑰金": Color(red: 0.86, green: 0.55, blue: 0.47), "青色": .cyan,
            "湖蓝": Color(red: 0.0, green: 0.55, blue: 0.8), "天蓝": Color(red: 0.35, green: 0.7, blue: 1.0),
            "墨绿": Color(red: 0.0, green: 0.24, blue: 0.16), "军绿色": Color(red: 0.29, green: 0.36, blue: 0.18),
            "酒红": Color(red: 0.45, green: 0.0, blue: 0.12), "荧光绿": Color(red: 0.45, green: 1.0, blue: 0.0),
            "荧光橙": Color(red: 1.0, green: 0.38, blue: 0.0)
        ]
        return colors[name] ?? Color(white: 0.6)
    }

    private static func mergedPresets(_ defaults: [String], key: String) -> [String] {
        let custom = UserDefaults.standard.stringArray(forKey: key) ?? []
        return (defaults + custom).reduce(into: [String]()) { result, item in
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty && !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
    }

    private static func appendPreset(_ value: String?, defaults: [String], key: String) {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return }
        guard !defaults.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        var custom = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !custom.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        custom.append(trimmed)
        UserDefaults.standard.set(custom, forKey: key)
    }
}
