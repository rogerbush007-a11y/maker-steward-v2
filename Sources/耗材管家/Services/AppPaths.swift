import Foundation

/// 集中路径管理：确保所有用户数据存入 Application Support，且覆盖安装不影响数据
struct AppPaths {

    /// 迁移旧默认存储到新位置（仅首次运行）
    static func migrateIfNeeded() {
        let fm = FileManager.default
        let newStore = swiftDataStore
        // 新位置已有数据则不迁移
        guard !fm.fileExists(atPath: newStore.path) else { return }
        // 旧默认位置
        let oldStore = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("default.store")
        guard fm.fileExists(atPath: oldStore.path) else { return }
        // 确保目标目录存在
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        // 复制旧的 store 文件（.store, -shm, -wal）
        for ext in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: oldStore.path + ext)
            let dst = URL(fileURLWithPath: newStore.path + ext)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    // MARK: - 应用数据根目录

    /// 主数据目录：~/Library/Application Support/耗材管家V2/
    /// Sandbox 环境下自动映射到 Container 目录
    static let appSupport: URL = {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("无法获取 Application Support 目录")
        }
        let dir = base.appendingPathComponent("耗材管家V2", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// SwiftData 持久化存储文件路径
    static let swiftDataStore: URL = {
        appSupport.appendingPathComponent("Data.store")
    }()

    /// OCR 临时文件存放目录
    static let ocrTempDir: URL = {
        let dir = appSupport.appendingPathComponent("ocr_tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - 临时文件

    /// 生成 OCR 输入临时文件路径
    static func ocrTempFile(_ name: String = "ocr_input.png") -> URL {
        ocrTempDir.appendingPathComponent(name)
    }

    // MARK: - OCR 工具路径

    /// 查找 ocrtool 可执行文件路径
    /// 优先级：应用内资源 > 用户目录下的开发版本
    static var ocrToolPath: String? {
        // 1. 检查 Bundle Resources
        if let builtIn = Bundle.main.resourcePath?.appending("/ocrtool"),
           FileManager.default.isExecutableFile(atPath: builtIn) {
            return builtIn
        }
        // 2. 检查 Application Support 下已部署的版本
        let deployed = appSupport.appendingPathComponent("ocrtool").path
        if FileManager.default.isExecutableFile(atPath: deployed) {
            return deployed
        }
        return nil
    }
}
