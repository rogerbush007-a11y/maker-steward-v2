import SwiftUI
import SwiftData

struct DeviceListView: View {
    @Binding var selectedDevice: Device?
    @Binding var showEditSheet: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var devices: [Device] = []
    @State private var showAddSheet = false
    @State private var searchText = ""

    private var filteredDevices: [Device] {
        if searchText.isEmpty { return devices }
        return devices.filter {
            $0.brand.localizedCaseInsensitiveContains(searchText) ||
            $0.model.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showAddSheet = true }) {
                Label("新增", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.small)
            .padding(.horizontal, 12).padding(.vertical, 6)
            toolbar
            Divider()
            searchBar
            Divider()
            deviceList
        }
        .background(.clear)
        .onAppear { refresh() }
        .sheet(isPresented: $showAddSheet) { AddDeviceView() }
    }

    private func refresh() {
        let fd = FetchDescriptor<Device>()
        devices = (try? modelContext.fetch(fd)) ?? []
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(Localized.str("设备列表")).font(.body).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField("搜索...", text: $searchText).textFieldStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var deviceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredDevices) { device in
                    DeviceRow(device: device, isSelected: selectedDevice?.id == device.id)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedDevice = device }
                        .contextMenu {
                            Button("编辑") { selectedDevice = device; showEditSheet = true }
                        }
                    Divider().padding(.leading, 24)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if let data = device.imageData, let img = NSImage(data: data) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: device.status == DeviceStatus.inUse.rawValue ? "printer.fill" : "printer")
                    .foregroundStyle(device.status == DeviceStatus.inUse.rawValue ? .blue : .secondary)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(device.model)").font(.body).fontWeight(.medium).lineLimit(1)
                Text(device.brand).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if device.status == DeviceStatus.sold.rawValue { Text("已售").font(.caption2).foregroundStyle(.secondary) }
            else if device.status == DeviceStatus.scrapped.rawValue { Text("报废").font(.caption2).foregroundStyle(.red) }
            Text("¥\(String(format: "%.0f", device.purchasePrice))").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
