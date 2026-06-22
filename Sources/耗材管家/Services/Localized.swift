import SwiftUI

/// 轻量级本地化支持
enum Localized {
    @AppStorage("language") static var language = "zh"

    static func str(_ key: String) -> String {
        translations[key]?[language] ?? key
    }
}

/// 翻译表
private let translations: [String: [String: String]] = [
    // 主菜单
    "设备": ["en": "Devices"],
    "耗材": ["en": "Filaments"],
    "产品": ["en": "Products"],
    "统计": ["en": "Stats"],

    // 操作按钮
    "新增": ["en": "Add"],
    "编辑": ["en": "Edit"],
    "删除": ["en": "Delete"],
    "保存": ["en": "Save"],
    "取消": ["en": "Cancel"],
    "导出": ["en": "Export"],

    // 设备
    "设备列表": ["en": "Device List"],
    "使用中": ["en": "In Use"],
    "已售出": ["en": "Sold"],
    "已报废": ["en": "Scrapped"],
    "购入价": ["en": "Price"],
    "已持有": ["en": "Held"],
    "日成本": ["en": "Daily Cost"],
    "月均成本": ["en": "Monthly Cost"],
    "当前净值": ["en": "Net Value"],
    "已折旧": ["en": "Depreciated"],
    "标记已售出": ["en": "Mark as Sold"],
    "购入日期": ["en": "Purchase Date"],
    "购入价格": ["en": "Purchase Price"],

    // 耗材
    "耗材列表": ["en": "Filament List"],
    "品牌": ["en": "Brand"],
    "材质": ["en": "Material"],
    "颜色": ["en": "Color"],
    "重量": ["en": "Weight"],
    "数量": ["en": "Quantity"],
    "总价": ["en": "Total"],
    "预警": ["en": "Alert"],
    "购买日期": ["en": "Purchase Date"],
    "剩余": ["en": "Remaining"],
    "已使用": ["en": "Used"],

    // 产品
    "产品列表": ["en": "Product List"],
    "库存": ["en": "Stock"],
    "售价": ["en": "Price"],
    "单位成本": ["en": "Unit Cost"],
    "已售": ["en": "Sold"],
    "售卖中": ["en": "Selling"],
    "需补货": ["en": "Reorder"],
    "补货中": ["en": "Restocking"],
    "售出": ["en": "Sell"],
    "单件毛利": ["en": "Margin"],

    // 统计
    "统计分析": ["en": "Statistics"],
    "总投入": ["en": "Total Invested"],
    "总收入": ["en": "Total Revenue"],
    "总消耗": ["en": "Total Consumed"],
    "总利润": ["en": "Total Profit"],
    "设备折旧": ["en": "Device Depreciation"],
    "耗材消耗": ["en": "Filament Consumption"],
    "产品销售分析": ["en": "Product Sales"],
    "销售排行": ["en": "Sales Ranking"],

    // 设置
    "外观": ["en": "Appearance"],
    "外观模式": ["en": "Appearance Mode"],
    "跟随系统": ["en": "System"],
    "深色": ["en": "Dark"],
    "亮色": ["en": "Light"],
    "语言": ["en": "Language"],
    "中文": ["en": "Chinese"],
    "英文": ["en": "English"],

    // 其他
    "搜索": ["en": "Search"],
    "暂无数据": ["en": "No Data"],
    "确认": ["en": "Confirm"],
    "图片": ["en": "Image"],
    "备注": ["en": "Notes"],
    "拍照": ["en": "Camera"],
    "从剪贴板": ["en": "Paste"],
    "选择文件": ["en": "Browse"],
    "选择图片": ["en": "Select Image"],
]
