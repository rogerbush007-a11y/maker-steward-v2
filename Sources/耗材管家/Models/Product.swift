import Foundation
import SwiftData

/// 3D打印产品
@Model
final class Product {
    /// 产品名称
    var name: String
    /// 规格
    var specs: String
    /// 颜色
    var color: String
    /// 库存数量
    var stock: Int
    /// 定价（售价）
    var price: Double
    /// 单个耗材成本（自动计算）
    var costPerUnit: Double
    /// 预警库存量
    var alertThreshold: Int
    /// 产品图片（正方形，存为 Data）
    var imageData: Data?
    /// 关联的消耗记录
    var consumption: ConsumptionRecord?
    /// 售出记录
    @Relationship(deleteRule: .cascade) var sales: [SaleRecord] = []
    /// 创建时间
    var createdAt: Date

    /// 周均销量（根据售出记录自动计算）
    var weeklySalesAverage: Double {
        let total = sales.reduce(0) { $0 + $1.quantity }
        guard total > 0 else { return 0 }
        let dates = sales.map(\.createdAt)
        guard let first = dates.min() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: first, to: .now).day ?? 0
        let weeks = max(1, Double(days) / 7.0)
        return Double(total) / weeks
    }

    /// 动态预警线（基于周均销量四舍五入，至少为 0）
    var effectiveThreshold: Int {
        max(0, Int(round(weeklySalesAverage)))
    }

    init(name: String, specs: String, color: String, stock: Int, price: Double, costPerUnit: Double = 0, alertThreshold: Int = 0, imageData: Data? = nil, createdAt: Date = .now) {
        self.name = name
        self.specs = specs
        self.color = color
        self.stock = stock
        self.price = price
        self.costPerUnit = costPerUnit
        self.alertThreshold = alertThreshold
        self.imageData = imageData
        self.createdAt = createdAt
    }

    /// 总成本
    var totalCost: Double { costPerUnit * Double(stock) }
    /// 总价值
    var totalValue: Double { price * Double(stock) }
    /// 需要补货（基于周均销量动态计算）
    var needsReorder: Bool { stock <= effectiveThreshold }
}

/// 售出记录
@Model
final class SaleRecord {
    /// 关联产品
    var product: Product?
    /// 售出数量
    var quantity: Int
    /// 售价（单个）
    var salePrice: Double
    /// 运费
    var shippingCost: Double
    /// 包装费
    var packagingCost: Double
    /// 平台抽成比例（如 0.05 表示 5%）
    var platformCommission: Double
    /// 售出平台（历史版本字段名为 buyer）
    var buyer: String
    /// 售出时间
    var createdAt: Date

    /// 收入
    var revenue: Double { Double(quantity) * salePrice }
    /// 平台费
    var platformFee: Double { revenue * platformCommission }
    /// 总成本（不含产品成本）
    var extraCosts: Double { shippingCost + packagingCost + platformFee }
    /// 毛利润 = 收入 - 平台费 - 运费 - 包装费
    var grossProfit: Double { revenue - extraCosts }

    init(product: Product? = nil, quantity: Int, salePrice: Double, shippingCost: Double = 0, packagingCost: Double = 0, platformCommission: Double = 0, buyer: String = "", createdAt: Date = .now) {
        self.product = product
        self.quantity = quantity
        self.salePrice = salePrice
        self.shippingCost = shippingCost
        self.packagingCost = packagingCost
        self.platformCommission = platformCommission
        self.buyer = buyer
        self.createdAt = createdAt
    }
}
