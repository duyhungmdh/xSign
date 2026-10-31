//
//  XSignTabConfig.swift
//  xSign v1.9.5
//
//  Cấu hình thanh điều hướng do người dùng chỉnh (Cài đặt → Tính năng → Điều chỉnh thanh điều hướng).
//  Lưu trong UserDefaults, đọc MỘT LẦN lúc mở app (`launch`), nên thay đổi có hiệu lực ở lần khởi động sau.
//

import SwiftUI

struct XSignTabConfig: Codable, Equatable {
	/// rawValue của `TabEnum`, theo thứ tự hiện trên thanh
	var visible: [String]
	/// rawValue của tab mở đầu tiên sau khi khởi động
	var defaultTab: String
	/// rawValue của tab → tên SF Symbol do người dùng chọn
	var icons: [String: String]
	
	static let storageKey = "xsign.tabBarConfig.v1"
	
	/// Cấu hình gốc (đúng 5 tab như trước v1.9.5)
	static var factory: XSignTabConfig {
		let tabs = TabEnum.factoryTabs
		return XSignTabConfig(
			visible: tabs.map(\.rawValue),
			defaultTab: tabs.first?.rawValue ?? TabEnum.settings.rawValue,
			icons: [:]
		)
	}
	
	/// Ảnh chụp cấu hình tại lúc mở app. Thanh tab thật chỉ đọc giá trị này.
	static let launch: XSignTabConfig = load()
	
	static func load() -> XSignTabConfig {
		guard
			let data = UserDefaults.standard.data(forKey: storageKey),
			let config = try? JSONDecoder().decode(XSignTabConfig.self, from: data)
		else {
			return factory
		}
		return config.sanitized()
	}
	
	func save() {
		if let data = try? JSONEncoder().encode(self) {
			UserDefaults.standard.set(data, forKey: Self.storageKey)
		}
	}
	
	static func reset() {
		UserDefaults.standard.removeObject(forKey: storageKey)
	}
	
	/// Bỏ tab lạ / trùng, luôn giữ tab Cài đặt (để không mất lối vào màn hình này), sửa tab mặc định
	func sanitized() -> XSignTabConfig {
		var seen = Set<String>()
		var list: [String] = []
		for raw in visible where TabEnum(rawValue: raw) != nil && !seen.contains(raw) {
			seen.insert(raw)
			list.append(raw)
		}
		if !seen.contains(TabEnum.settings.rawValue) {
			list.append(TabEnum.settings.rawValue)
		}
		var config = self
		config.visible = list
		if !list.contains(defaultTab) {
			config.defaultTab = list.first ?? TabEnum.settings.rawValue
		}
		config.icons = icons.filter { TabEnum(rawValue: $0.key) != nil && !$0.value.isEmpty }
		return config
	}
	
	var visibleTabs: [TabEnum] {
		visible.compactMap { TabEnum(rawValue: $0) }
	}
	
	var hiddenTabs: [TabEnum] {
		TabEnum.allCases.filter { !visible.contains($0.rawValue) }
	}
	
	var defaultTabEnum: TabEnum {
		TabEnum(rawValue: defaultTab) ?? visibleTabs.first ?? .settings
	}
}
