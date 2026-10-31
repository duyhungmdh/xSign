//
//  XSignShare.swift
//  xSign v1.9.4 (v1.9.6: sửa await cho ArchiveHandler / InstallerStatusViewModel)
//
//  Chia sẻ tệp .ipa của app đã ký (vuốt dòng app ở tab Đã ký, và nút Chia sẻ trong hộp thoại ký xong).
//  Dùng lại ArchiveHandler giống nút Xuất / Cài đặt: move() + archive() tạo ra tệp .ipa,
//  rồi mở bảng chia sẻ của iOS.
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import IDeviceSwift

enum XSignShare {
	/// Tên tệp .ipa hiển thị / chia sẻ.
	/// - `source`: app gốc (chưa ký) vừa ký xong, nếu biết thì lấy tên tệp .ipa gốc + "-signed".
	/// - Không có thì ghép `Tên_phiênbản-signed.ipa`.
	static func signedFileName(source: AppInfoPresentable?, signed: AppInfoPresentable) -> String {
		if let source,
		   let original = ImportedFileNames.shared.name(for: source.uuid),
		   !original.isEmpty {
			var base = original
			if base.lowercased().hasSuffix(".ipa") { base = String(base.dropLast(4)) }
			if base.lowercased().hasSuffix("-signed") { return base + ".ipa" }
			return _sanitized(base) + "-signed.ipa"
		}
		let name = signed.name ?? "app"
		let base = signed.version.map { "\(name)_\($0)" } ?? name
		return _sanitized(base) + "-signed.ipa"
	}
	
	/// Đóng gói app đã ký thành .ipa rồi mở bảng chia sẻ.
	/// `ArchiveHandler.move()` chép app vào thư mục tạm, `archive()` nén thành `Archive.ipa` (chạy nền).
	@MainActor
	static func shareSignedIPA(_ app: AppInfoPresentable, fileName: String?) {
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		Task.detached {
			do {
				let viewModel = await InstallerStatusViewModel(isIdevice: false)
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				let packageUrl = try await handler.archive()
				
				var shareURL = packageUrl
				if let fileName, !fileName.isEmpty, packageUrl.lastPathComponent != fileName {
					// đổi tên tệp cho khớp tên đang hiển thị (sao chép vào thư mục tạm riêng)
					let dir = FileManager.default.temporaryDirectory
						.appendingPathComponent("xsign-share-\(UUID().uuidString)", isDirectory: true)
					try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
					let target = dir.appendingPathComponent(fileName)
					try FileManager.default.copyItem(at: packageUrl, to: target)
					shareURL = target
				}
				
				await MainActor.run {
					UIActivityViewController.show(activityItems: [shareURL])
				}
			} catch {
				await MainActor.run {
					UIAlertController.showAlertWithOk(
						title: .localized("Share"),
						message: error.localizedDescription
					)
				}
			}
		}
	}
	
	private static func _sanitized(_ s: String) -> String {
		s.replacingOccurrences(of: "/", with: "-")
			.replacingOccurrences(of: ":", with: "-")
	}
}
