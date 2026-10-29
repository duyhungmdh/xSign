//
//  X509CertificateInfo.swift
//  xSign (personal customization)
//
//  Đọc thông tin chứng chỉ Apple (Common Name, Tổ chức, OU, Serial, SHA-1, hiệu lực, bên cấp)
//  từ file .p12 (hoặc từ DeveloperCertificates trong .mobileprovision nếu không mở được p12).
//

import Foundation
import Security
import CryptoKit

struct X509CertificateInfo {
	var commonName: String = ""
	var organization: String = ""
	var organizationalUnit: String = ""
	var userID: String = ""
	var country: String = ""
	var serialNumber: String = ""
	var sha1: String = ""
	var notBefore: Date?
	var notAfter: Date?
	var issuerCommonName: String = ""
}

// MARK: - Loading
extension X509CertificateInfo {
	/// Đọc thông tin chứng chỉ. Thử mở .p12 trước, nếu không được thì dùng chứng chỉ đầu tiên trong provisioning profile.
	static func load(p12: URL?, password: String, fallbackDER: Data?) -> X509CertificateInfo? {
		if let p12, let der = _derFromP12(p12, password: password), let info = parse(der: der) {
			return info
		}
		if let fallbackDER, let info = parse(der: fallbackDER) {
			return info
		}
		return nil
	}
	
	private static func _derFromP12(_ url: URL, password: String) -> Data? {
		guard let data = try? Data(contentsOf: url) else { return nil }
		
		var items: CFArray?
		let options: [String: Any] = [kSecImportExportPassphrase as String: password]
		let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
		guard status == errSecSuccess,
			  let array = items as? [[String: Any]],
			  let first = array.first,
			  let identityRef = first[kSecImportItemIdentity as String]
		else { return nil }
		
		let identity = identityRef as! SecIdentity
		var certificate: SecCertificate?
		let copyStatus = SecIdentityCopyCertificate(identity, &certificate)
		
		// iOS lưu identity vào keychain khi import p12 -> xoá đi cho sạch.
		let deleteQuery: [String: Any] = [
			kSecClass as String: kSecClassIdentity,
			kSecValueRef as String: identity
		]
		_ = SecItemDelete(deleteQuery as CFDictionary)
		
		guard copyStatus == errSecSuccess, let certificate else { return nil }
		return SecCertificateCopyData(certificate) as Data
	}
}

// MARK: - DER parsing
extension X509CertificateInfo {
	private struct Node {
		let tag: UInt8
		let start: Int
		let end: Int
	}
	
	static func parse(der: Data) -> X509CertificateInfo? {
		let bytes = [UInt8](der)
		
		guard
			let (root, _) = _read(bytes, at: 0),
			let tbs = _children(bytes, of: root).first
		else { return nil }
		
		var fields = _children(bytes, of: tbs)
		// [0] version (EXPLICIT)
		if let first = fields.first, first.tag == 0xA0 {
			fields.removeFirst()
		}
		// serial, signatureAlgorithm, issuer, validity, subject
		guard fields.count >= 5 else { return nil }
		
		var info = X509CertificateInfo()
		
		info.serialNumber = _hex(Array(bytes[fields[0].start..<fields[0].end]), trimLeadingZero: true)
		info.sha1 = Insecure.SHA1.hash(data: der).map { String(format: "%02X", $0) }.joined()
		
		let issuer = _readName(bytes, node: fields[2])
		info.issuerCommonName = issuer["2.5.4.3"] ?? ""
		
		let validity = _children(bytes, of: fields[3])
		if validity.count >= 2 {
			info.notBefore = _readTime(bytes, node: validity[0])
			info.notAfter = _readTime(bytes, node: validity[1])
		}
		
		let subject = _readName(bytes, node: fields[4])
		info.commonName = subject["2.5.4.3"] ?? ""
		info.organization = subject["2.5.4.10"] ?? ""
		info.organizationalUnit = subject["2.5.4.11"] ?? ""
		info.country = subject["2.5.4.6"] ?? ""
		info.userID = subject["0.9.2342.19200300.100.1.1"] ?? ""
		
		return info
	}
	
	private static func _read(_ bytes: [UInt8], at offset: Int) -> (Node, Int)? {
		guard offset + 2 <= bytes.count else { return nil }
		let tag = bytes[offset]
		var index = offset + 1
		var length = Int(bytes[index])
		index += 1
		
		if length & 0x80 != 0 {
			let count = length & 0x7F
			guard count > 0, count <= 4, index + count <= bytes.count else { return nil }
			length = 0
			for _ in 0..<count {
				length = (length << 8) | Int(bytes[index])
				index += 1
			}
		}
		
		guard index + length <= bytes.count else { return nil }
		return (Node(tag: tag, start: index, end: index + length), index + length)
	}
	
	private static func _children(_ bytes: [UInt8], of node: Node) -> [Node] {
		var result: [Node] = []
		var offset = node.start
		while offset < node.end {
			guard let (child, next) = _read(bytes, at: offset) else { break }
			result.append(child)
			offset = next
		}
		return result
	}
	
	/// Name ::= SEQUENCE OF SET OF SEQUENCE { OID, value }
	private static func _readName(_ bytes: [UInt8], node: Node) -> [String: String] {
		var result: [String: String] = [:]
		for rdn in _children(bytes, of: node) {
			for pair in _children(bytes, of: rdn) {
				let parts = _children(bytes, of: pair)
				guard parts.count >= 2, parts[0].tag == 0x06 else { continue }
				let oid = _oid(Array(bytes[parts[0].start..<parts[0].end]))
				let value = String(decoding: bytes[parts[1].start..<parts[1].end], as: UTF8.self)
				if result[oid] == nil {
					result[oid] = value
				}
			}
		}
		return result
	}
	
	private static func _oid(_ raw: [UInt8]) -> String {
		guard let first = raw.first else { return "" }
		var parts: [String] = ["\(Int(first) / 40)", "\(Int(first) % 40)"]
		var value = 0
		for byte in raw.dropFirst() {
			value = (value << 7) | Int(byte & 0x7F)
			if byte & 0x80 == 0 {
				parts.append("\(value)")
				value = 0
			}
		}
		return parts.joined(separator: ".")
	}
	
	private static func _readTime(_ bytes: [UInt8], node: Node) -> Date? {
		let text = String(decoding: bytes[node.start..<node.end], as: UTF8.self)
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = node.tag == 0x18 ? "yyyyMMddHHmmss'Z'" : "yyMMddHHmmss'Z'"
		return formatter.date(from: text)
	}
	
	private static func _hex(_ raw: [UInt8], trimLeadingZero: Bool) -> String {
		var data = raw
		if trimLeadingZero, data.count > 1, data.first == 0 {
			data.removeFirst()
		}
		return data.map { String(format: "%02X", $0) }.joined()
	}
}
