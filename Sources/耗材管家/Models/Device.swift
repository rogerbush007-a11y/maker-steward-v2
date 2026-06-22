import Foundation
import SwiftData

/// 设备状态
enum DeviceStatus: String, Codable, CaseIterable {
    case inUse = "使用中"
    case sold = "已售出"
    case scrapped = "已报废"
}

/// 3D 打印机设备
@Model
final class Device {
    var brand: String
    var model: String
    var purchaseDate: Date
    var purchasePrice: Double
    var status: String  // DeviceStatus.rawValue
    var sellPrice: Double?
    var sellDate: Date?
    var notes: String
    var imageData: Data?
    var createdAt: Date

    init(
        brand: String,
        model: String,
        purchaseDate: Date,
        purchasePrice: Double,
        status: DeviceStatus = .inUse,
        sellPrice: Double? = nil,
        sellDate: Date? = nil,
        notes: String = "",
        imageData: Data? = nil
    ) {
        self.brand = brand
        self.model = model
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.status = status.rawValue
        self.sellPrice = sellPrice
        self.sellDate = sellDate
        self.notes = notes
        self.imageData = imageData
        self.createdAt = .now
    }

    // MARK: - 计算属性

    /// 已持有天数
    var daysHeld: Int {
        let end = sellDate ?? .now
        return Calendar.current.dateComponents([.day], from: purchaseDate, to: end).day ?? 0
    }

    /// 日成本（动态计算）
    var dailyCost: Double {
        guard daysHeld > 0 else { return purchasePrice }
        let totalLoss: Double
        switch status {
        case DeviceStatus.sold.rawValue:
            totalLoss = purchasePrice - (sellPrice ?? 0)
        default: // 使用中 / 已报废
            totalLoss = purchasePrice
        }
        return max(0, totalLoss / Double(daysHeld))
    }

    /// 月均成本
    var monthlyCost: Double { dailyCost * 30 }

    /// 累计折旧成本（已产生的总成本）
    var accumulatedCost: Double {
        guard daysHeld > 0 else { return 0 }
        return min(purchasePrice, dailyCost * Double(daysHeld))
    }

    /// 当前净值
    var currentValue: Double {
        max(0, purchasePrice - accumulatedCost)
    }

    /// 折旧百分比
    var depreciationPercent: Double {
        guard purchasePrice > 0 else { return 100 }
        return min(100, accumulatedCost / purchasePrice * 100)
    }

    /// 状态描述
    var statusDescription: String {
        status
    }
}

// MARK: - 预设品牌型号
extension Device {
    static let presetBrands: [(brand: String, models: [String])] = [
        ("Bambu Lab", ["X2D", "X1E", "X1C", "X1", "P2S", "P1S", "P1P", "H2D Pro", "H2D", "H2C", "H2S", "A2L", "A2", "A1", "A1 Mini"]),
        ("Creality", ["K1C", "K1 SE", "K1", "Ender-3 V3", "Ender-3 V3 KE", "CR-10 SE"]),
        ("Prusa", ["MK4S", "MK4", "MK3.5", "XL", "Mini+"]),
        ("Anycubic", ["Kobra 3", "Kobra 2 Pro", "Kobra 2"]),
        ("Elegoo", ["Neptune 4 Plus", "Neptune 4", "Neptune 4 Pro", "Saturn 4 Ultra"]),
        ("Flashforge", ["Adventurer 5M", "Adventurer 5M Pro", "Guider 3 Plus"]),
        ("Qidi Tech", ["Q1 Pro", "X-Max 3", "X-Plus 3", "Plus 4"]),
        ("其他", ["自定义"]),
    ]
}
