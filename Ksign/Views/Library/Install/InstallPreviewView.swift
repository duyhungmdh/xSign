//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift
import OSLog

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss
	
	// Sharing
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	
	// Methods
    @AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	@State private var _isWebviewPresenting = false
    @State private var progressTask: Task<Void, Never>?
	@State private var _stuckTask: Task<Void, Never>?
	
	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller
	@State var isSharing: Bool

	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
        let method = UserDefaults.standard.integer(forKey: "Feather.installationMethod")
		let viewModel = InstallerStatusViewModel(isIdevice: method == 1)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: try! ServerInstaller(app: app, viewModel: viewModel))
	}
	
	// MARK: Body
	var body: some View {
		ZStack {
			if isSharing {
				// Xuất .ipa: giữ giao diện gốc
				InstallProgressView(app: app, viewModel: viewModel)
				_status()
			} else {
				// xSign v7: hộp thoại gọn, thanh 4 chặng 4 màu nằm trong hộp thoại
				InstallSheetContent(app: app)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isSharing ? .center : .top)
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			// xSign v7.3: iOS đã gọi tới máy chủ cục bộ (hoặc đã xong/lỗi) thì tắt bộ canh "treo ở Gửi dữ liệu"
			switch newStatus {
			case .ready, .sendingManifest: break
			default: _stuckTask?.cancel(); _stuckTask = nil
			}
			
			if case .ready = newStatus {
				_startStuckWatchdog()
				if _serverMethod == 0 {
					UIApplication.shared.open(URL(string: installer.iTunesLink)!)
				} else if _serverMethod == 1 {
					// xSign: mở thẳng itms-services, bỏ trang Safari trung gian
					// (tránh hộp thoại "Mở trang này trong iTunes?")
					if let url = URL(string: installer.iTunesLinkExternal) {
						UIApplication.shared.open(url)
					}
				}
			}
            
            if case .installing = newStatus {
                if progressTask == nil {
                    progressTask = startInstallProgressPolling(
                        bundleID: app.identifier!,
                        viewModel: viewModel
                    )
                }
            }
			
			if case .sendingPayload = newStatus, _serverMethod == 1 {
				_isWebviewPresenting = false
			}
            
			// xSign v7.2: cài xong thì tự đóng hộp thoại sau 1,5 giây (kịp thấy "Hoàn tất 100%")
			if !isSharing, case .completed(.success) = newStatus {
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
			}
            
            switch newStatus {
            case .completed, .broken(_):
                progressTask?.cancel()
                progressTask = nil
                BackgroundAudioManager.shared.stop()
            default:
                break
            }
		}
		.onAppear(perform: _install)
		.onAppear {
			BackgroundAudioManager.shared.start()
			// xSign v6/v7: bật thanh tiến trình 4 chặng ở tab Ứng dụng đã ký
			if !isSharing {
				InstallProgressCenter.shared.begin(appName: app.name ?? "")
			}
		}
		// xSign v6: mỗi khi trạng thái/tiến độ đổi, cập nhật thanh (đọc sau khi giá trị đã đổi)
		.onReceive(viewModel.objectWillChange) { _ in
			DispatchQueue.main.async {
				InstallProgressCenter.shared.sync(viewModel)
			}
		}
		.onDisappear {
			_stuckTask?.cancel()
            progressTask?.cancel()
            progressTask = nil
			BackgroundAudioManager.shared.stop()
			InstallProgressCenter.shared.sheetClosed()
		}
	}
	
	/// 60 giây mà iOS vẫn chưa tải .ipa từ máy chủ cục bộ → báo nguyên nhân thường gặp (không tự huỷ cài đặt)
	private func _startStuckWatchdog() {
		guard !isSharing, _installationMethod == 0 else { return }
		_stuckTask?.cancel()
		_stuckTask = Task {
			try? await Task.sleep(nanoseconds: 60_000_000_000)
			guard !Task.isCancelled else { return }
			await MainActor.run {
				guard case .ready = viewModel.status else { return }
				
				let useLocalhost = UIAlertAction(title: "Dùng localhost", style: .default) { _ in
					ServerInstaller.setIPFix(true)
				}
				let close = UIAlertAction(title: .localized("Dismiss"), style: .cancel)
				UIAlertController.showAlert(
					title: .localized("Install"),
					message: "iOS chưa tải được ứng dụng từ máy chủ cài đặt trên máy.\n\nNếu bạn bấm \"Hủy\" ở hộp thoại hệ thống của iOS thì cứ đóng. Nếu không, hãy bật \"Chỉ sử dụng địa chỉ localhost\" (Cài đặt → Máy chủ) rồi cài lại. Bấm \"Dùng localhost\" để bật ngay.",
					actions: [useLocalhost, close]
				)
			}
		}
	}
	
	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.padding()
			.labelStyle(.titleAndIcon)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	private func _install() {
        guard isSharing || app.identifier != Bundle.main.bundleIdentifier! || _installationMethod == 1 else {
            UIAlertController.showAlertWithOk(
                title: .localized("Install"),
                message: .localized("You cannot update ‘%@‘ with itself, please use an alternative tool to update it.", arguments: Bundle.main.name)
            )
            return
        }

		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				if await !isSharing {
                    if await _installationMethod == 0 {
                        await MainActor.run {
                            installer.packageUrl = packageUrl
                            viewModel.status = .ready
                        }
                        
                        if case .installing = await viewModel.status {
                            let task = await startInstallProgressPolling(
                                bundleID: app.identifier!,
                                viewModel: viewModel
                            )

                            await MainActor.run {
                                progressTask = task
                            }
                        }
                    }
                    else if await _installationMethod == 1 {
                        let handler = await InstallationProxy(viewModel: viewModel)
                        try await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
                    }
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					
					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch {
                await progressTask?.cancel()
				await MainActor.run {
					InstallProgressCenter.shared.fail()
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: error.localizedDescription,
						action: {
							HeartbeatManager.shared.start(true)
							dismiss()
						}
					)
				}
			}
		}
	}
    private func startInstallProgressPolling(
            bundleID: String,
            viewModel: InstallerStatusViewModel
        ) -> Task<Void, Never> {

            Task.detached(priority: .background) {
                var hasStarted = false

                while !Task.isCancelled {
                    let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

                    if rawProgress > 0 {
                        hasStarted = true
                    }

                    let progress = await hasStarted
                        ? _normalizeInstallProgress(rawProgress)
                        : 0.0

                    Logger.misc.info("Install progress for \(bundleID): \(progress) - \(rawProgress) - \(viewModel.installProgress)")

                    await MainActor.run {
                        viewModel.installProgress = progress
                    }

                    if hasStarted && rawProgress == 0 {
                        await MainActor.run {
                            viewModel.installProgress = 1.0
                            viewModel.status = .completed(.success(()))
                            print(viewModel.installProgress)
                        }
                        break
                    }

                    try? await Task.sleep(nanoseconds: 1_000_000) // 1 ms
                }
            }
        }

        private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
            min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
        }
}
