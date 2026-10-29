//
//  CertificateSharing.swift
//  xSign (personal customization)
//
//  Chia sẻ / nhập chứng chỉ dạng gói .xsigncert (thực chất là file zip gồm
//  certificate.p12 + profile.mobileprovision + info.json chứa biệt danh và mật khẩu).
//

import UIKit
import UniformTypeIdentifiers
import ZIPFoundation
import NimbleExtensions

extension UTType {
	/// Định dạng gói chứng chỉ của xSign (.xsigncert)
	static var xsignCert: UTType {
		UTType(filenameExtension: "xsigncert", conformingTo: .data) ?? .data
	}
}

enum CertificatePackError: LocalizedError {
	case missingFiles
	case noCertificateFiles
	
	var errorDescription: String? {
		switch self {
		case .missingFiles:
			return "Không tìm thấy file .p12 hoặc .mobileprovision của chứng chỉ này."
		case .noCertificateFiles:
			return "Không tìm thấy đủ file .p12 và .mobileprovision trong gói."
		}
	}
}

enum CertificateSharing {
	static let fileExtension = "xsigncert"
	
	struct Meta: Codable {
		var version: Int = 1
		var nickname: String?
		var password: String?
	}
	
	struct Pack {
		let p12: URL
		let provision: URL
		let nickname: String?
		let password: String?
	}
	
	// MARK: Export
	static func export(_ cert: CertificatePair) throws -> URL {
		let fm = FileManager.default
		
		guard
			let p12 = Storage.shared.getFile(.certificate, from: cert),
			let provision = Storage.shared.getFile(.provision, from: cert)
		else {
			throw CertificatePackError.missingFiles
		}
		
		let work = fm.temporaryDirectory.appendingPathComponent("xsign_share_\(UUID().uuidString)")
		let pack = work.appendingPathComponent("pack")
		try fm.createDirectory(at: pack, withIntermediateDirectories: true)
		
		try fm.copyItem(at: p12, to: pack.appendingPathComponent("certificate.p12"))
		try fm.copyItem(at: provision, to: pack.appendingPathComponent("profile.mobileprovision"))
		
		let meta = Meta(nickname: cert.nickname, password: cert.password)
		try JSONEncoder().encode(meta).write(to: pack.appendingPathComponent("info.json"))
		
		let rawName = cert.nickname
			?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name
			?? "chungchi"
		let output = work.appendingPathComponent("\(_sanitized(rawName)).\(fileExtension)")
		try fm.zipItem(at: pack, to: output, shouldKeepParent: false)
		
		return output
	}
	
	static func share(_ cert: CertificatePair) {
		do {
			let url = try export(cert)
			UIActivityViewController.show(activityItems: [url])
		} catch {
			UIAlertController.showAlertWithOk(
				title: "Không thể chia sẻ",
				message: error.localizedDescription
			)
		}
	}
	
	// MARK: Import (dùng chung cho .xsigncert và .zip)
	static func importPack(from url: URL) throws -> Pack {
		let fm = FileManager.default
		let work = fm.temporaryDirectory.appendingPathComponent("xsign_cert_pack_\(UUID().uuidString)")
		
		try fm.createDirectory(at: work, withIntermediateDirectories: true)
		try fm.unzipItem(at: url, to: work)
		
		var p12: URL?
		var provision: URL?
		var info: URL?
		
		if let enumerator = fm.enumerator(at: work, includingPropertiesForKeys: [.isRegularFileKey]) {
			for case let file as URL in enumerator {
				// Bỏ qua thư mục rác của macOS
				if file.path.contains("__MACOSX") || file.lastPathComponent.hasPrefix("._") { continue }
				switch file.pathExtension.lowercased() {
				case "p12": if p12 == nil { p12 = file }
				case "mobileprovision": if provision == nil { provision = file }
				case "json": if file.lastPathComponent.lowercased() == "info.json" { info = file }
				default: break
				}
			}
		}
		
		guard let p12, let provision else {
			try? fm.removeItem(at: work)
			throw CertificatePackError.noCertificateFiles
		}
		
		var meta: Meta?
		if let info, let data = try? Data(contentsOf: info) {
			meta = try? JSONDecoder().decode(Meta.self, from: data)
		}
		
		return Pack(p12: p12, provision: provision, nickname: meta?.nickname, password: meta?.password)
	}
	
	private static func _sanitized(_ name: String) -> String {
		let invalid = CharacterSet(charactersIn: "/\\:?*\"<>|")
		let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return cleaned.isEmpty ? "chungchi" : cleaned
	}
}
