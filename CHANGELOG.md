# 更新日志

## [未发布]

### 修复
- **用完即删改为标记已用完**：耗材用完时不再删除记录及其所有消耗历史/价格历史，改为标记为"已用完"状态，保留完整数据回溯能力
- **修复双重通知监听**：删除 `onAppear` 中冗余的 `addObserver` 代码，仅保留 `.onReceive` 订阅，避免每次数据变更触发两次刷新
- **"这卷用完了"按钮统行为一**：耗材弹出层中的"这卷用完了"按钮原先直接操作 `modelContext`（伪造消耗记录 + 未设 status），改为调用 `FilamentStore.markAsUsedUp`，与主流程行为一致：设 `remainingWeight=0`、设 `status=usedUp`、不产生虚假消耗记录
- **消耗记录在归零时不再丢失**：`recordConsumption` 改为先创建消耗记录再判断归零，确保刚好用尽的最后一笔消耗数据不丢失；`saveConsumption` 补充归零时设置 `status=usedUp`，避免主入口消耗归零后仍显示"使用中"
- **"这卷用完了"按钮改为"剩余废料，标记已用完"**：文案与行为对齐 — 明确告知用户此操作不计入消耗统计，仅作废剩余料并标记已用完

### 优化
- **基础消耗逻辑收敛到 FilamentStore**：`saveConsumption` 改为委托 `recordConsumption` 处理扣减/归零/记录创建，自身只保留产品创建逻辑；`recordConsumption` 增加 `guard actualUsed > 0` 防御式校验，避免无效调用产生 0g 假记录
- **产品分类改为名称+规格聚合**：产品列表与销售统计按“名称 + 规格”归类，不同颜色会合并到同一产品组下展示
- **新增产品不再计入库存**：产品页新增只创建产品档案，默认库存为 0；耗材消耗入库时只能选择已经录入的产品，并按实际消耗更新库存

### 清理
- **删除死代码 `ImportView.swift`**：480 行未被引用的独立导入视图，其 OCR 解析逻辑已整合到 `AddFilamentView` 中
- **删除空占位文件**：移除 0 字节的 `AddProductView.swift` 和 `ProductDetailView.swift`（实际实现在 `ProductListView.swift` 中）
