import SwiftUI
import SwiftData

@main
struct 耗材管家App: App {
    let container: ModelContainer

    init() {
        // 迁移旧数据到 Application Support（仅首次执行）
        AppPaths.migrateIfNeeded()

        do {
            let schema = Schema([
                Filament.self,
                ConsumptionRecord.self,
                PriceRecord.self,
                OrderImport.self,
                Product.self,
                SaleRecord.self,
                Device.self
            ])
            // 数据库统一存入 Application Support，覆盖安装不影响数据
            let storeURL = AppPaths.swiftDataStore
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("数据库初始化失败: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
                .background(WindowAccessor())
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 680)

        Settings {
            SettingsView()
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for w in NSApp.windows {
                w.titlebarAppearsTransparent = true
            }
        }
        return NSView()
    }
    func updateNSView(_: NSView, context: Context) {}
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material; v.blendingMode = blendingMode; v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("language") private var language = "zh"

    var body: some View {
        TabView {
            Form {
                Picker(Localized.str("外观模式"), selection: $appearance) {
                    Label(Localized.str("跟随系统"), systemImage: "gearshape").tag("system")
                    Label(Localized.str("深色"), systemImage: "moon.fill").tag("dark")
                    Label(Localized.str("亮色"), systemImage: "sun.max").tag("light")
                }
                .pickerStyle(.radioGroup)
            }
            .padding(20)
            .tabItem { Label(Localized.str("外观"), systemImage: "paintbrush") }
            .frame(width: 300, height: 160)

            Form {
                Picker(Localized.str("语言"), selection: $language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(.radioGroup)
            }
            .padding(20)
            .tabItem { Label(Localized.str("语言"), systemImage: "globe") }
            .frame(width: 300, height: 120)
        }
    }
}
