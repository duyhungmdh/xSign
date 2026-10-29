//
//  Server+TLS.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import NIOSSL
import NIOTLS
import Vapor
import SystemConfiguration.CaptiveNetwork

// MARK: - Class extension: TLS/Setup
extension ServerInstaller {
	// MARK: Setup
	private static let env: Environment = {
		var env = try! Environment.detect()
		try! LoggingSystem.bootstrap(from: &env)
		return env
	}()
	
	static func setupApp(port: Int, host: String) throws -> Application {
		let app = Application(env)
		app.threadPool = .init(numberOfThreads: 1)
		
		if ServerInstaller.getServerMethod() != 1 {
			if let tls = try Self.tls() {
				app.http.server.configuration.tlsConfiguration = tls
			}
		}
		
		app.http.server.configuration.hostname = host
		app.http.server.configuration.tcpNoDelay = true
		app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
		app.http.server.configuration.port = port
		app.routes.defaultMaxBodySize = "128mb"
		app.routes.caseInsensitive = false
		
		return app
	}
	
	// MARK: Files/IP
	/// xSign v7.3: địa chỉ máy chủ được tính LẠI mỗi lần cài (trước đây là `static let` nên bị "đóng băng"
	/// theo mạng lúc mở app → đổi từ Wi-Fi sang 5G là sai địa chỉ, iOS không tải được .ipa và treo ở "Gửi dữ liệu").
	static var sni: String { resolveHost() }
	
	static func resolveHost() -> String {
		let localhost = "127.0.0.1"
		
		if getServerMethod() == 1 {
			// Bán cục bộ (HTTP): có Wi-Fi thì dùng IP Wi-Fi; KHÔNG có Wi-Fi (5G / 4G) thì dùng 127.0.0.1.
			// Không dùng IP của sóng di động vì thường là IP CGNAT / IPv6 (464XLAT), chính iPhone cũng không kết nối tới được.
			if getIPFix() { return localhost }
			return getWiFiAddress() ?? localhost
		} else {
			return readCommonName() ?? localhost
		}
	}
	
	static func tls() throws -> TLSConfiguration? {
		guard
			let crt = getUrl("server", ext: "crt"),
			let pem = getUrl("server", ext: "pem")
		else {
			return nil
		}
		
		return try TLSConfiguration.makeServerConfiguration(
			certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
				NIOSSLCertificateSource.certificate($0)
			},
			privateKey: .privateKey(
				try NIOSSLPrivateKey(file: pem.path, format: .pem)
			)
		)
	}
	
	static func readCommonName() -> String? {
		guard let url = getUrl("commonName", ext: "txt") else {
			return nil
		}
		
		return try? String(contentsOf: url, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

extension ServerInstaller {
	static func getUrl(_ name: String, ext: String) -> URL? {
		let fileManager = FileManager.default
		
		let serverURL = URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Server").appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: serverURL.path) {
			return serverURL
		}
		
		let documentsURL = URL.documentsDirectory.appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: documentsURL.path) {
			return documentsURL
		}
		
		let oldServerURL = URL.documentsDirectory.appendingPathComponent("Server").appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: oldServerURL.path) {
			return oldServerURL
		}
		
		return Bundle.main.url(forResource: name, withExtension: ext)
	}
	
	/// IPv4 của Wi-Fi (en0). Bỏ qua 169.254.x.x (link-local) và 0.0.0.0. Không có Wi-Fi → nil.
	static func getWiFiAddress() -> String? {
		var address: String?
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		
		guard getifaddrs(&ifaddr) == 0 else { return nil }
		defer { freeifaddrs(ifaddr) }
		
		var ptr = ifaddr
		while let current = ptr {
			let interface = current.pointee
			ptr = interface.ifa_next
			
			guard
				let addr = interface.ifa_addr,
				addr.pointee.sa_family == UInt8(AF_INET),
				String(cString: interface.ifa_name) == "en0"
			else { continue }
			
			var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
			if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
						   &hostname, socklen_t(hostname.count),
						   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
				let ip = String(cString: hostname)
				if !ip.hasPrefix("169.254.") && ip != "0.0.0.0" {
					address = ip
				}
			}
		}
		
		return address
	}
}
