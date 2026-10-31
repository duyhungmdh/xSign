//
//  Server.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import Vapor
import NIOSSL
import NIOTLS
import SwiftUI
import IDeviceSwift

// MARK: - Class
class ServerInstaller: Identifiable, ObservableObject {
	let id = UUID()
	let port = Int.random(in: 4000...8000)
	/// Chốt địa chỉ một lần cho cả lần cài này, để plist và .ipa luôn cùng một địa chỉ
	let host: String = ServerInstaller.resolveHost()
	private var _needsShutdown = false
	
	var packageUrl: URL?
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	private let _server: Application

	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) throws {
		self.app = app
		self.viewModel = viewModel
		self._server = try Self.setupApp(port: port, host: host)
		
		try _configureRoutes()
		try _server.server.start()
		_needsShutdown = true
	}
	
	deinit {
		_shutdownServer()
	}
		
	private func _configureRoutes() throws {
		_server.get("*") { [weak self] req in
			guard let self else { return Response(status: .badGateway) }
			switch req.url.path {
			case plistEndpoint.path:
				self._updateStatus(.sendingManifest)
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "text/xml",
				], body: .init(data: installManifestData))
			case displayImageSmallEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageSmallData))
			case displayImageLargeEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageLargeData))
			case payloadEndpoint.path:
				guard let packageUrl = packageUrl else {
					return Response(status: .notFound)
				}
				
				self._updateStatus(.sendingPayload)
				
				return req.fileio.streamFile(
					at: packageUrl.path
				) { result in
                    switch result {
                    case .success:
                        self._updateStatus(.installing)
                    case .failure(let error):
                        self._updateStatus(.broken(error))
                    }
				}
			case "/install":
				var headers = HTTPHeaders()
				headers.add(name: .contentType, value: "text/html")
				return Response(status: .ok, headers: headers, body: .init(string: self.html))
			default:
				return Response(status: .notFound)
			}
		}
	}
	
	private func _shutdownServer() {
		guard _needsShutdown else { return }
		
		_needsShutdown = false
		_server.server.shutdown()
		_server.shutdown()
	}
	
    private func _updateStatus(_ newStatus: InstallerStatusViewModel.InstallerStatus) {
		DispatchQueue.main.async {
			self.viewModel.status = newStatus
		}
	}
		
	/// xSign v1.9.2: giá trị mặc định của "Phương thức máy chủ" = 1 (Bán cục bộ).
	/// Các màn hình (`@AppStorage("Feather.serverMethod") = 1`) coi mặc định là Bán cục bộ,
	/// nhưng `UserDefaults.integer(forKey:)` trả 0 (Cục bộ hoàn toàn) khi chưa từng lưu →
	/// cài mới hoàn toàn thì giao diện nói "Bán cục bộ" còn máy chủ chạy HTTPS "Cục bộ hoàn toàn",
	/// iOS không tải được .ipa và treo ở "Gửi dữ liệu". Hai nơi phải dùng chung một mặc định.
	static let defaultServerMethod = 1
	
	static func getServerMethod() -> Int {
		let defaults = UserDefaults.standard
		guard defaults.object(forKey: "Feather.serverMethod") != nil else {
			return defaultServerMethod
		}
		return defaults.integer(forKey: "Feather.serverMethod")
	}
	
	/// Ghi mặc định xuống UserDefaults ngay lần mở app đầu tiên (gọi từ `AppDelegate`),
	/// để mọi nơi đọc trực tiếp từ UserDefaults đều thấy cùng giá trị với giao diện.
	static func ensureDefaultServerMethod() {
		let defaults = UserDefaults.standard
		if defaults.object(forKey: "Feather.serverMethod") == nil {
			defaults.set(defaultServerMethod, forKey: "Feather.serverMethod")
		}
	}
	
	static func getIPFix() -> Bool {
		UserDefaults.standard.bool(forKey: "Feather.ipFix")
	}
	
	static func setServerMethod(_ method: Int) {
		UserDefaults.standard.set(method, forKey: "Feather.serverMethod")
	}
	
	static func setIPFix(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: "Feather.ipFix")
	}
}
