import Foundation
import AppKit
import UniformTypeIdentifiers

/// 导出服务
struct ExportService {

    /// 导出库存报表为 CSV（通用格式，Excel/Numbers 都能打开）
    static func exportToCSV(filaments: [Filament]) -> URL? {
        var csv = "品牌,材质,颜色,总重量(g),剩余(g),已用(g),使用率,单价(¥),购买日期,状态\n"

        for f in filaments {
            let line = [
                csvEscape(f.brand),
                csvEscape(f.material),
                csvEscape(f.color),
                "\(f.weight)",
                "\(f.remainingWeight)",
                "\(f.usedWeight)",
                "\(Int(100 - f.usagePercent))%",
                "\(f.price)",
                f.purchaseDate.formatted(.dateTime.year().month().day()),
                csvEscape(f.status)
            ].joined(separator: ",")
            csv += line + "\n"
        }

        guard let data = csv.data(using: .utf8) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("耗材库存报表_\(formattedDate()).csv")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("导出失败: \(error)")
            return nil
        }
    }

    /// 导出消耗记录 CSV
    static func exportConsumptions(filaments: [Filament]) -> URL? {
        var csv = "品牌,材质,颜色,消耗量(g),打印模型,日期\n"

        for f in filaments {
            for c in f.consumptions.sorted(by: { $0.createdAt < $1.createdAt }) {
                let line = [
                    csvEscape(f.brand),
                    csvEscape(f.material),
                    csvEscape(f.color),
                    "\(c.weightUsed)",
                    csvEscape(c.modelName),
                    c.createdAt.formatted(.dateTime.year().month().day())
                ].joined(separator: ",")
                csv += line + "\n"
            }
        }

        guard let data = csv.data(using: .utf8) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("消耗记录_\(formattedDate()).csv")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("导出失败: \(error)")
            return nil
        }
    }

    /// 导出采购建议表
    static func exportPurchaseSuggestion(filaments: [Filament]) -> URL? {
        // 按品牌+材质+颜色分组
        var dict: [String: [Filament]] = [:]
        for f in filaments {
            let key = "\(f.brand.trimmingCharacters(in: .whitespaces))|\(f.material.trimmingCharacters(in: .whitespaces))|\(f.color.trimmingCharacters(in: .whitespaces))"
            dict[key, default: []].append(f)
        }

        var csv = "品牌,材质,颜色,当前剩余(g),总预警线(g),建议采购量(卷),参考均价(¥),预计花费(¥)\n"
        var totalCost: Double = 0

        for (_, group) in dict {
            let first = group.first!
            let totalRemaining = group.reduce(0) { $0 + $1.remainingWeight }
            let totalThreshold = group.reduce(0) { $0 + $1.alertThreshold }
            let monthlyRate = group.reduce(0.0) { $0 + $1.monthlyConsumptionRate }

            // 只需要补货的组
            guard totalRemaining <= totalThreshold else { continue }

            let avgPrice = group.map(\.price).reduce(0, +) / Double(group.count)
            let suggestedQty: Int
            if monthlyRate > 0 {
                suggestedQty = max(1, Int(ceil(monthlyRate / Double(first.weight) * 2.5)))
            } else {
                suggestedQty = 1
            }
            let estimatedCost = Double(suggestedQty) * avgPrice
            totalCost += estimatedCost

            let line = [
                csvEscape(first.brand),
                csvEscape(first.material),
                csvEscape(first.color),
                "\(totalRemaining)",
                "\(totalThreshold)",
                "\(min(suggestedQty, 10))",
                String(format: "%.0f", avgPrice),
                String(format: "%.0f", estimatedCost)
            ].joined(separator: ",")
            csv += line + "\n"
        }

        csv += "\n预计总花费,¥\(String(format: "%.0f", totalCost))\n"

        guard let data = csv.data(using: .utf8) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("采购建议_\(formattedDate()).csv")
        try? data.write(to: tempURL)
        return tempURL
    }

    // MARK: - 辅助

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: .now)
    }

    /// 弹出保存对话框
    static func saveFilePanel(url: URL) {
        let panel = NSSavePanel()
        panel.title = "导出报表"
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            if response == .OK, let targetURL = panel.url {
                try? FileManager.default.copyItem(at: url, to: targetURL)
                NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            }
        }
    }
}
