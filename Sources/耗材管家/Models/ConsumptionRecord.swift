import Foundation
import SwiftData

/// 消耗记录
@Model
final class ConsumptionRecord {
    /// 关联的耗材
    @Relationship(inverse: \Filament.consumptions) var filament: Filament?
    /// 关联的产品（消耗转为产品，无反向关联避免循环引用）
    var product: Product?
    /// 消耗重量（克）
    var weightUsed: Int
    /// 打印的模型名称
    var modelName: String
    /// 备注
    var note: String
    /// 记录时间
    var createdAt: Date

    init(
        filament: Filament? = nil,
        product: Product? = nil,
        weightUsed: Int,
        modelName: String = "",
        note: String = "",
        createdAt: Date = .now
    ) {
        self.filament = filament
        self.product = product
        self.weightUsed = weightUsed
        self.modelName = modelName
        self.note = note
        self.createdAt = createdAt
    }
}

/// 价格记录（每次入库都记一笔，用于价格趋势）
@Model
final class PriceRecord {
    /// 关联的耗材
    @Relationship(inverse: \Filament.priceHistory) var filament: Filament?
    /// 品牌
    var brand: String
    /// 材质
    var material: String
    /// 颜色
    var color: String
    /// 价格
    var price: Double
    /// 记录时间
    var createdAt: Date

    init(
        filament: Filament? = nil,
        brand: String,
        material: String,
        color: String,
        price: Double,
        createdAt: Date = .now
    ) {
        self.filament = filament
        self.brand = brand
        self.material = material
        self.color = color
        self.price = price
        self.createdAt = createdAt
    }
}

/// 订单导入记录
@Model
final class OrderImport {
    /// 来源截图文件名
    var screenshotName: String
    /// 订单总价
    var orderTotal: Double
    /// 导入时间
    var createdAt: Date
    /// 备注
    var note: String

    init(screenshotName: String, orderTotal: Double, createdAt: Date = .now, note: String = "") {
        self.screenshotName = screenshotName
        self.orderTotal = orderTotal
        self.createdAt = createdAt
        self.note = note
    }
}
