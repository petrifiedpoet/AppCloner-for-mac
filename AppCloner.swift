import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CloneItem: Identifiable, Codable {
    let id: String
    let name: String
    let cloneIndex: Int
    let clonePath: String
    let dataPath: String
    let originalPath: String
}

struct CloneCard: View {
    let clone: CloneItem
    @Binding var isRunning: Bool
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            if isRunning {
                focusApp()
            } else {
                launchApp()
            }
        }) {
            VStack(spacing: 12) {
                // Icon with Badge
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: loadIcon())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                    
                    // Clone Index Badge
                    Text("\(clone.cloneIndex)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(getBadgeColor())
                        )
                        .offset(x: 2, y: 2)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                
                // Name
                VStack(spacing: 4) {
                    Text(clone.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        
                        Text(isRunning ? "运行中" : "点击启动")
                            .font(.system(size: 10))
                            .foregroundColor(isRunning ? .green : .secondary)
                    }
                }
            }
            .frame(width: 110, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? getBadgeColor().opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.03), radius: 6, x: 0, y: 3)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .contextMenu {
            Button("在 Finder 中显示程序") {
                showInFinder(path: clone.clonePath)
            }
            Button("打开沙盒数据文件夹") {
                showInFinder(path: clone.dataPath)
            }
            Divider()
            Button(role: .destructive, action: {
                onDelete()
            }) {
                Text("删除分身")
                Image(systemName: "trash")
            }
        }
    }
    
    private func getBadgeColor() -> Color {
        let colors: [Color] = [.orange, .green, .purple, .blue, .teal, .pink, .indigo]
        let idx = (clone.cloneIndex - 1) % colors.count
        return colors[idx]
    }
    
    private func loadIcon() -> NSImage {
        let plistPath = "\(clone.clonePath)/Contents/Info.plist"
        var iconName = "Icon.icns"
        
        if let dict = NSDictionary(contentsOfFile: plistPath),
           let name = dict["CFBundleIconFile"] as? String {
            iconName = name.hasSuffix(".icns") ? name : "\(name).icns"
        }
        
        let iconPath = "\(clone.clonePath)/Contents/Resources/\(iconName)"
        if FileManager.default.fileExists(atPath: iconPath),
           let img = NSImage(contentsOfFile: iconPath) {
            return img
        }
        
        let origIconPath = "\(clone.originalPath)/Contents/Resources/\(iconName)"
        if FileManager.default.fileExists(atPath: origIconPath),
           let img = NSImage(contentsOfFile: origIconPath) {
            return img
        }
        
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }
    
    private func showInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
    
    private func focusApp() {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == clone.clonePath }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    private func launchApp() {
        let plistPath = "\(clone.clonePath)/Contents/Info.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath),
              let execName = dict["CFBundleExecutable"] as? String else {
            return
        }
        
        let binaryPath = "\(clone.clonePath)/Contents/MacOS/\(execName)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let dylibPath = "\(homePath)/Library/Application Support/BambuStudio_Launcher/libredirect.dylib"
        
        var env = ProcessInfo.processInfo.environment
        env["DYLD_INSERT_LIBRARIES"] = dylibPath
        env["DYLD_FORCE_FLAT_NAMESPACE"] = "1"
        env["HOME"] = clone.dataPath
        env["CUSTOM_HOME"] = clone.dataPath
        process.environment = env
        
        try? FileManager.default.createDirectory(atPath: clone.dataPath, withIntermediateDirectories: true, attributes: nil)
        
        do {
            try process.run()
        } catch {
            let alert = NSAlert()
            alert.messageText = "启动分身失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

struct MainView: View {
    @State private var clones: [CloneItem] = []
    @State private var runningStatus: [String: Bool] = [:]
    @State private var isTargeted = false
    @State private var isCloning = false
    @State private var cloningAppName = ""
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Drop & Cloner Area
            VStack(spacing: 16) {
                if isCloning {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("正在为 \(cloningAppName) 创建独立分身...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("这包括复制文件、重新签名和沙盒隔离配置")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(isTargeted ? .accentColor : .secondary)
                        
                        Text("将任何 macOS 应用程序 (.app) 拖入此区域")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isTargeted ? .accentColor : .primary)
                        
                        Text("将自动生成完全独立的、数据隔离的双开分身程序")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [8, 6], dashPhase: 0))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                    )
                    .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                            if let url = url, url.pathExtension == "app" {
                                DispatchQueue.main.async {
                                    self.cloneApp(url: url)
                                }
                            }
                        }
                        return true
                    }
                }
            }
            .padding(20)
            
            // Header for Clones Grid
            HStack {
                Text("已创建的分身程序 (\(clones.count))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                
                if !clones.isEmpty {
                    Text("右键分身可查看沙盒目录或删除")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            
            // Grid List Area
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                    if clones.isEmpty {
                        VStack {
                            Text("暂无分身，请在上方拖入程序开始创建")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(minWidth: 540, minHeight: 130)
                    } else {
                        ForEach(clones) { clone in
                            let isRunning = Binding<Bool>(
                                get: { runningStatus[clone.id] ?? false },
                                set: { runningStatus[clone.id] = $0 }
                            )
                            CloneCard(clone: clone, isRunning: isRunning, onDelete: {
                                deleteClone(clone)
                            })
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(height: 160)
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onReceive(timer) { _ in
            updateRunningStatus()
        }
        .onAppear {
            ensureDylibExists()
            loadClonesList()
            updateRunningStatus()
        }
    }
    
    private func getConfigFileURL() -> URL {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent("AppClones/clones.json")
    }
    
    private func loadClonesList() {
        let fileURL = getConfigFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([CloneItem].self, from: data) {
            self.clones = list
        }
    }
    
    private func saveClonesList() {
        let fileURL = getConfigFileURL()
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if let data = try? JSONEncoder().encode(clones) {
            try? data.write(to: fileURL)
        }
    }
    
    private func cloneApp(url: URL) {
        let fileManager = FileManager.default
        let appName = url.deletingPathExtension().lastPathComponent
        
        isCloning = true
        cloningAppName = appName
        
        DispatchQueue.global(qos: .userInitiated).async {
            let home = fileManager.homeDirectoryForCurrentUser.path
            let baseDir = "\(home)/AppClones"
            let appsDir = "\(baseDir)/Apps"
            let dataDir = "\(baseDir)/Data"
            
            try? fileManager.createDirectory(atPath: appsDir, withIntermediateDirectories: true, attributes: nil)
            try? fileManager.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
            
            // Count existing clones
            let count = self.clones.filter { $0.name == appName }.count
            let cloneIndex = count + 1
            
            let cloneName = "\(appName)_Clone\(cloneIndex)"
            let destAppPath = "\(appsDir)/\(cloneName).app"
            let destDataPath = "\(dataDir)/\(cloneName)"
            
            do {
                if fileManager.fileExists(atPath: destAppPath) {
                    try fileManager.removeItem(atPath: destAppPath)
                }
                
                // Copy bundle (APFS clones instantly)
                try fileManager.copyItem(atPath: url.path, toPath: destAppPath)
                
                // Ad-hoc codesign to disable hardened runtime
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                process.arguments = ["--force", "--deep", "--sign", "-", destAppPath]
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let newItem = CloneItem(
                        id: UUID().uuidString,
                        name: appName,
                        cloneIndex: cloneIndex,
                        clonePath: destAppPath,
                        dataPath: destDataPath,
                        originalPath: url.path
                    )
                    
                    DispatchQueue.main.async {
                        self.clones.append(newItem)
                        self.saveClonesList()
                        self.isCloning = false
                        self.updateRunningStatus()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isCloning = false
                        self.showAlert(title: "签名失败", message: "分身已复制，但在对其进行 Ad-hoc 签名时失败。")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.showAlert(title: "创建失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func deleteClone(_ clone: CloneItem) {
        let fileManager = FileManager.default
        
        // Clean up folders
        try? fileManager.removeItem(atPath: clone.clonePath)
        try? fileManager.removeItem(atPath: clone.dataPath)
        
        // Remove from list
        if let idx = clones.firstIndex(where: { $0.id == clone.id }) {
            clones.remove(at: idx)
            saveClonesList()
        }
        updateRunningStatus()
    }
    
    private func updateRunningStatus() {
        var status: [String: Bool] = [:]
        let runningApps = NSWorkspace.shared.runningApplications
        for clone in clones {
            status[clone.id] = runningApps.contains { app in
                app.bundleURL?.path == clone.clonePath
            }
        }
        self.runningStatus = status
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    private func ensureDylibExists() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let destDir = "\(home)/Library/Application Support/BambuStudio_Launcher"
        let destPath = "\(destDir)/libredirect.dylib"
        
        if let srcPath = Bundle.main.path(forResource: "libredirect", ofType: "dylib") {
            try? fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true, attributes: nil)
            try? fileManager.removeItem(atPath: destPath)
            do {
                try fileManager.copyItem(atPath: srcPath, toPath: destPath)
            } catch {
                print("Failed to extract dylib: \(error)")
            }
        }
    }
}

// Background Visual Effect (blur) View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@main
struct AppClonerLauncher: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(width: 600, height: 410)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
