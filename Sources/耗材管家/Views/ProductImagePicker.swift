import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// 产品图片选择器（正方形、支持拖拽、拍照）
struct ProductImagePicker: View {
    @Binding var imageData: Data?
    @State private var isTargeted = false
    @State private var imageSize: CGFloat = 120
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 8) {
            // 图片区域
            ZStack {
                if let data = imageData, let nsImage = NSImage(data: data) {
                    // 显示图片
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Button(action: { imageData = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                } else {
                    // 空状态
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                                      style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: imageSize, height: imageSize)
                        .background(RoundedRectangle(cornerRadius: 8).fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear))

                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary)
                        Text("拖入图片，或从下方选择来源").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .onDrop(of: [.image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers in
                loadImage(from: providers)
                return true
            }
            .onTapGesture {
                selectImageFile()
            }

            // 大小调节滑块
            HStack(spacing: 6) {
                Image(systemName: "minus").font(.caption).foregroundStyle(.secondary)
                Slider(value: $imageSize, in: 60...200, step: 10)
                    .frame(width: 100)
                Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
                Text("\(Int(imageSize))×\(Int(imageSize))")
                    .font(.caption2).foregroundStyle(.secondary).frame(width: 50)
            }

            // 操作按钮（三种方式并列选择）
            HStack(spacing: 12) {
                Button(action: selectImageFile) {
                    Label("选择文件", systemImage: "folder")
                }
                .buttonStyle(.borderless).font(.caption)
                Button(action: pasteImage) {
                    Label("从剪贴板", systemImage: "clipboard")
                }
                .buttonStyle(.borderless).font(.caption)
                Button(action: openCameraCapture) {
                    Label("拍照", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderless).font(.caption)
            }
        }
        .sheet(isPresented: $showCamera) {
            SimpleCameraCapture { image in
                processImage(image)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
    }

    // MARK: - 图片处理

    private func processImage(_ nsImage: NSImage) {
        // 获取 CGImage（像素尺寸）
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let w = cgImage.width, h = cgImage.height
        let size = min(w, h)
        let rect = CGRect(x: (w - size) / 2, y: (h - size) / 2, width: size, height: size)
        guard let cropped = cgImage.cropping(to: rect) else { return }

        // 缩小到 400×400
        let thumb = NSImage(cgImage: cropped, size: NSSize(width: size, height: size))
        let resizeRatio = min(400.0 / CGFloat(size), 1.0)
        let finalSize = NSSize(width: CGFloat(size) * resizeRatio, height: CGFloat(size) * resizeRatio)

        let resized = NSImage(size: finalSize)
        resized.lockFocus()
        thumb.draw(in: NSRect(origin: .zero, size: finalSize),
                   from: NSRect(origin: .zero, size: NSSize(width: size, height: size)),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        // 压缩为 JPEG
        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else { return }
        imageData = jpegData
    }

    private func loadImage(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                DispatchQueue.main.async {
                    guard let nsImage = image as? NSImage else { return }
                    self.processImage(nsImage)
                }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                var nsImage: NSImage?
                if let url = item as? URL { nsImage = NSImage(contentsOf: url) }
                else if let data = item as? Data { nsImage = NSImage(data: data) }
                else if let img = item as? NSImage { nsImage = img }
                guard let image = nsImage else { return }
                self.processImage(image)
            }
        }
    }

    private func pasteImage() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return }
        processImage(image)
    }

    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
            processImage(image)
        }
    }

    private func openCameraCapture() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video, position: .unspecified
        )
        if discovery.devices.isEmpty {
            let alert = NSAlert()
            alert.messageText = "未检测到摄像头"
            alert.informativeText = "请确保 Mac 有内置摄像头，或 iPhone 已连接并开启了连续互通相机"
            alert.runModal()
        } else {
            showCamera = true
        }
    }
}


// MARK: - 简易相机拍摄

struct SimpleCameraCapture: View {
    let onCapture: (NSImage) -> Void
    let onCancel: () -> Void
    @State private var session = AVCaptureSession()
    @State private var cameraReady = false
    @State private var capturedImage: NSImage?
    @StateObject private var grabber = FrameGrabber()

    var body: some View {
        VStack(spacing: 12) {
            Text("拍照").font(.headline)
            if let img = capturedImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 250).clipShape(RoundedRectangle(cornerRadius: 8))
            } else if cameraReady {
                CameraPreviewLayer(session: session)
                    .frame(width: 320, height: 240).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView("正在启动摄像头...").frame(width: 320, height: 240)
            }
            HStack(spacing: 12) {
                Button("取消") { stopCamera(); onCancel() }.keyboardShortcut(.cancelAction)
                if let img = capturedImage {
                    Button("确认使用") { stopCamera(); onCapture(img) }.buttonStyle(.borderedProminent)
                } else {
                    Button("📷 拍摄") { grabPhoto() }.buttonStyle(.borderedProminent).disabled(!cameraReady)
                }
            }
        }.padding(20).frame(width: 380, height: 360)
        .onAppear { startCamera() }.onDisappear { stopCamera() }
    }

    private func startCamera() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video, position: .unspecified
        ).devices.first else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(grabber, queue: DispatchQueue(label: "camera"))
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
            cameraReady = true
        } catch { print("Camera error: \(error)") }
    }

    private func grabPhoto() {
        if let img = grabber.currentImage() { capturedImage = img }
    }

    private func stopCamera() {
        if session.isRunning { session.stopRunning() }
    }
}

class FrameGrabber: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var lastBuffer: CMSampleBuffer?
    private let queue = DispatchQueue(label: "frame")

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lastBuffer = sampleBuffer
    }

    func currentImage() -> NSImage? {
        guard let buffer = lastBuffer, let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ci)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}

struct CameraPreviewLayer: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.wantsLayer = true
        view.layer?.addSublayer(layer)
        DispatchQueue.main.async { layer.frame = view.bounds }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = nsView.bounds
        }
    }
}
