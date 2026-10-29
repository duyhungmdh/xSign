//
//  DeviceInfo.swift
//  xSign (personal customization)
//
//  Thông tin thiết bị: dòng máy, UDID (từ pairing file), màu máy do người dùng chọn.
//

import SwiftUI
import UIKit

// MARK: - Device color option
struct DeviceColorOption: Identifiable, Hashable {
	let name: String
	let hex: String
	var id: String { name }
	var color: Color { Color(xsignHex: hex) }
}

// MARK: - DeviceInfo
enum DeviceInfo {
	static let colorNameKey = "xsign.deviceColorName"
	
	static let colorOptions: [DeviceColorOption] = [
		.init(name: "Desert Titanium", hex: "#C4A77D"),
		.init(name: "Natural Titanium", hex: "#B9B3A8"),
		.init(name: "Black Titanium", hex: "#3B3B3D"),
		.init(name: "White Titanium", hex: "#E3E1DC"),
		.init(name: "Blue Titanium", hex: "#5B6B7F"),
		.init(name: "Cosmic Orange", hex: "#E8742E"),
		.init(name: "Deep Blue", hex: "#2F4F7F"),
		.init(name: "Đen", hex: "#2C2C2E"),
		.init(name: "Trắng", hex: "#E5E5EA"),
		.init(name: "Xanh dương", hex: "#337AE0"),
		.init(name: "Xanh lá", hex: "#43B86F"),
		.init(name: "Hồng", hex: "#EE5C8E"),
		.init(name: "Vàng", hex: "#EEC23A"),
		.init(name: "Tím", hex: "#8B5CE6"),
		.init(name: "Đỏ", hex: "#E24B4F")
	]
	
	static var selectedColor: DeviceColorOption? {
		guard let name = UserDefaults.standard.string(forKey: colorNameKey) else { return nil }
		return colorOptions.first { $0.name == name }
	}
	
	// MARK: Model
	static var modelIdentifier: String {
		if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
			return sim
		}
		var systemInfo = utsname()
		uname(&systemInfo)
		return withUnsafePointer(to: &systemInfo.machine) {
			$0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
		}
	}
	
	static var modelName: String {
		let id = modelIdentifier
		return modelNames[id] ?? UIDevice.current.model
	}
	
	private static let modelNames: [String: String] = [
		"iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
		"iPhone12,8": "iPhone SE (2nd gen)",
		"iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
		"iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
		"iPhone14,6": "iPhone SE (3rd gen)",
		"iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
		"iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
		"iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
		"iPhone17,5": "iPhone 16e",
		"iPhone18,3": "iPhone 17", "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,4": "iPhone Air"
	]
	
	// MARK: UDID (from pairing file)
	static var pairingFileURL: URL {
		URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
	}
	
	static let manualUDIDKey = "xsign.manualUDID"
	
	/// UDID người dùng dán tay (dùng khi chưa có pairing file)
	static var manualUDID: String? {
		get { UserDefaults.standard.string(forKey: manualUDIDKey) }
		set { UserDefaults.standard.set(newValue, forKey: manualUDIDKey) }
	}
	
	/// UDID hợp lệ: 25 ký tự dạng 00008140-001A2C3D0E4B801C, hoặc 40 ký tự hex (máy cũ)
	static func isValidUDID(_ text: String) -> Bool {
		let pattern = "^([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"
		return text.range(of: pattern, options: .regularExpression) != nil
	}
	
	static var udid: String? {
		if
			let data = try? Data(contentsOf: pairingFileURL),
			let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		{
			for key in ["UDID", "udid", "UniqueDeviceID"] {
				if let value = plist[key] as? String, !value.isEmpty { return value }
			}
		}
		return manualUDID
	}
	
	static var hasPairingFile: Bool {
		FileManager.default.fileExists(atPath: pairingFileURL.path)
	}
}

// MARK: - Color(xsignHex:) / hex string helpers
extension Color {
	init(xsignHex hex: String) {
		var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		if s.hasPrefix("#") { s.removeFirst() }
		var v: UInt64 = 0
		Scanner(string: s).scanHexInt64(&v)
		self.init(
			red: Double((v >> 16) & 0xFF) / 255,
			green: Double((v >> 8) & 0xFF) / 255,
			blue: Double(v & 0xFF) / 255
		)
	}
	
	var hexString: String {
		let ui = UIColor(self)
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		ui.getRed(&r, green: &g, blue: &b, alpha: &a)
		return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
	}
}

// MARK: - Pick device color (one-time)
struct DeviceColorPickerView: View {
	@AppStorage(DeviceInfo.colorNameKey) private var _name: String = ""
	@StateObject private var _accent = AccentColorManager.shared
	
	var body: some View {
		List {
			Section {
				ForEach(DeviceInfo.colorOptions) { option in
					Button {
						_name = option.name
						_accent.refresh()
					} label: {
						HStack(spacing: 12) {
							Circle().fill(option.color).frame(width: 24, height: 24)
							Text(LocalizedStringKey(option.name)).foregroundStyle(.primary)
							Spacer()
							if _name == option.name {
								Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
							}
						}
					}
				}
			} footer: {
				Text("iOS không cho app đọc màu máy, nên bạn chọn một lần. Màu này dùng cho chế độ \"Theo máy\" trong Giao diện.")
			}
		}
		.navigationTitle(Text("Màu thiết bị"))
		.navigationBarTitleDisplayMode(.inline)
	}
}
