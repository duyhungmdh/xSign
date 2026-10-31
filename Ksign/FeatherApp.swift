//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import OSLog
import IDeviceSwift

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	let heartbeat = HeartbeatManager.shared
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var accentColorManager = AccentColorManager.shared
    @StateObject var extractManager = ExtractManager.shared
	@StateObject var logsManager = LogsManager.shared
	@StateObject var libraryState = XSignLibraryState.shared
	@AppStorage(AppLanguage.key) private var _appLanguage: String = AppLanguage.vi.rawValue
	let storage = Storage.shared

	var body: some Scene {
		WindowGroup {
			VStack {
                ExtractHeaderView(extractManager: extractManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
				// xSign v7: ở tab Thư viện đã có thanh riêng, ẩn thanh gốc để khỏi hiện 2 chỗ
				if !libraryState.isLibraryVisible {
					DownloadHeaderView(downloadManager: downloadManager)
						.transition(.move(edge: .top).combined(with: .opacity))
				}
				VariedTabbarView()
					.environment(\.managedObjectContext, storage.context)
					.onOpenURL(perform: _handleURL)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
			.environment(\.locale, Locale(identifier: _appLanguage))
			.animation(.smooth, value: downloadManager.manualDownloads.description)
            .animation(.smooth, value: extractManager.extractItems.description)
			.animation(.smooth, value: libraryState.isLibraryVisible)
			.onReceive(accentColorManager.objectWillChange) { _ in
				accentColorManager.updateGlobalTintColor()
			}
			.onAppear {
				accentColorManager.updateGlobalTintColor()
				// xSign v7: khởi động sớm để không bỏ lỡ tên tệp của lượt nhập đầu tiên
				_ = ImportProgressModel.shared
				_ = ImportedFileNames.shared
				if logsManager.isCapturing { logsManager.startCapture() }
			}
		}
	}
	
	private func _handleURL(_ url: URL) {
		if url.scheme == "ksign" {
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				_ = DownloadManager.shared.startDownload(from: downloadURL, id: "FeatherManualDownload_\(UUID().uuidString)")
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
				}
				
				// xSign v1.9.0: đi cùng đường với nút "+" → Nhập từ Tệp.
				// Tạo lượt tải trong DownloadManager để thanh tiến trình (tab Ứng dụng tải về)
				// và việc ghi nhớ tên tệp gốc hoạt động với file mở từ Telegram, Zalo, WhatsApp…
				let id = "FeatherManualDownload_\(UUID().uuidString)"
				let dl = DownloadManager.shared.startArchive(from: url, id: id)
				DownloadManager.shared.handlePachageFile(url: url, dl: dl) { err in
					if err != nil {
						UIAlertController.showAlertWithOk(
							title: "Error",
							message: .localized("Whoops!, something went wrong when extracting the file. \nMaybe try switching the extraction library in the settings?")
						)
					}
				}
				
				return
			}
			
            if url.pathExtension == "ksign" {
                UIAlertController.showAlertWithOk(title: .localized("Error"), message: .localized("xSign certificate file (.ksign) is now unsupported from v1.5.1, please refer to use .p12 and .mobileprovision instead."))
            }
		}
	}
	
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // xSign v1.9.2: chốt mặc định "Bán cục bộ" trước khi có bất kỳ lượt cài nào
        ServerInstaller.ensureDefaultServerMethod()
        
        AppLanguage.bootstrap()
        _createPipeline()
        _createSourcesDirectory()
        if !UserDefaults.standard.bool(forKey: "hasInitializedBuiltInSources") {
            _initializeBuiltInSources()
            UserDefaults.standard.set(true, forKey: "hasInitializedBuiltInSources")
            // xSign v1.9.3: cài mới đã dùng sẵn kho MDH, không cần chuyển kho
            UserDefaults.standard.set(true, forKey: "xsign.replacedKsignRepo.v1")
        } else {
            // xSign v1.9.3: bản cài từ trước → thêm kho MDH, bỏ "Ksign Repository" (một lần)
            Storage.shared.replaceKsignRepositoryWithMDH()
        }
        
        _clean()
        
        _copyServerCertificates()
        _addDefaultCertificates()

#if SERVER
        // fallback just in case xd
        _downloadSSLCertificates()
#endif
        return true
    }
    
    private func _initializeBuiltInSources() { 
        Storage.shared.addBuiltInSources()
    }
    
    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = {
                let config = URLSessionConfiguration.default
                config.urlCache = nil
                return DataLoader(configuration: config)
            }()
            let dataCache = try? DataCache(name: "thewonderofyou.Feather.datacache") // disk cache
            let imageCache = Nuke.ImageCache() // memory cache
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataLoader = dataLoader
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }
        
        ImagePipeline.shared = pipeline
    }
    
    private func _createSourcesDirectory() {
        let fileManager = FileManager.default
        
        let appDirectory = URL.documentsDirectory.appendingPathComponent("App")
        try? fileManager.createDirectoryIfNeeded(at: appDirectory)
        
        let directories = ["Signed", "Unsigned", "Archives", "Server", "Tweaks"].map {
            appDirectory.appendingPathComponent($0)
        }
        
        for url in directories {
            try? fileManager.createDirectoryIfNeeded(at: url)
        }
    }
    
    private func _clean() {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        
        if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory.path()) {
            for file in files {
                try? fileManager.removeItem(atPath: tmpDirectory.appendingPathComponent(file).path())
            }
        }
    }
    
    private func _copyServerCertificates() {
        let fileManager = FileManager.default
        let serverDirectory = URL.documentsDirectory.appendingPathComponent("App/Server")
        
        try? fileManager.createDirectoryIfNeeded(at: serverDirectory)
        
        let filesToCopy = ["server.crt", "server.pem", "commonName.txt"]
        
        for fileName in filesToCopy {
            guard let bundleURL = Bundle.main.url(forResource: fileName.components(separatedBy: ".").first!, withExtension: fileName.components(separatedBy: ".").last!) else {
                print("File \(fileName) not found in app bundle")
                continue
            }
            
            let destinationURL = serverDirectory.appendingPathComponent(fileName)
            
            try? fileManager.removeItem(at: destinationURL)
            
            do {
                try fileManager.copyItem(at: bundleURL, to: destinationURL)
            } catch {
                print("Error copying \(fileName): \(error)")
            }
        }
    }
    
    private func _addDefaultCertificates() {
            guard
                UserDefaults.standard.bool(forKey: "feather.didImportDefaultCertificates") == false,
                let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
            else {
                return
            }
            
            do {
                let folderContents = try FileManager.default.contentsOfDirectory(
                    at: signingAssetsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for folderURL in folderContents {
                    guard folderURL.hasDirectoryPath else { continue }
                    
                    let certName = folderURL.lastPathComponent
                    
                    let p12Url = folderURL.appendingPathComponent("cert.p12")
                    let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
                    let passwordUrl = folderURL.appendingPathComponent("cert.txt")
                    
                    guard
                        FileManager.default.fileExists(atPath: p12Url.path),
                        FileManager.default.fileExists(atPath: provisionUrl.path),
                        FileManager.default.fileExists(atPath: passwordUrl.path)
                    else {
                        Logger.misc.warning("Skipping \(certName): missing required files")
                        continue
                    }
                    
                    let password = try String(contentsOf: passwordUrl, encoding: .utf8)
                    
                    FR.handleCertificateFiles(
                        p12URL: p12Url,
                        provisionURL: provisionUrl,
                        p12Password: password,
                        certificateName: certName,
                    ) { _ in
                        
                    }
                }
                UserDefaults.standard.set(true, forKey: "feather.didImportDefaultCertificates")
            } catch {
                Logger.misc.error("Failed to list signing-assets: \(error)")
            }
        }

#if SERVER
    private func _downloadSSLCertificates() {
        let serverURL = "https://backloop.dev/pack.json"
        
        FR.downloadSSLCertificates(from: serverURL) { success in
            if success {
                print("SSL certificates downloaded successfully")
            } else {
                print("Failed to download SSL certificates")
            }
        }
    }
#endif
}
