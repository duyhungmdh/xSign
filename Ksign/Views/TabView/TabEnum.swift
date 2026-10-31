//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//
//  xSign v1.9.5: danh sách tab trên thanh, tab mặc định và icon đọc từ `XSignTabConfig.launch`
//  (cấu hình người dùng chỉnh trong Cài đặt → Điều chỉnh thanh điều hướng).
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case files
	case sources
	case library
	case settings
	case certificates
	case appstore
    case downloader
	var title: String {
		switch self {
        case .files:        return .localized("Files")
		case .sources:     	return .localized("Sources")
		case .library: 		return .localized("Library")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		case .appstore: 	return .localized("App Store")
        case .downloader:   return .localized("Downloads")
		}
	}
	
	/// Icon đang dùng trên thanh: icon người dùng chọn (nếu hợp lệ), không thì icon gốc
	var icon: String {
		if let custom = XSignTabConfig.launch.icons[rawValue],
		   !custom.isEmpty,
		   UIImage(systemName: custom) != nil {
			return custom
		}
		return defaultIcon
	}
	
	var defaultIcon: String {
		switch self {
        case .files:        return "folder.fill"
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .appstore: 	return "plus.app.fill"
        case .downloader:    return "square.and.arrow.down.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
        case .files: FilesView()
		case .sources: SourcesView()
		case .library: LibraryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		case .appstore: AppstoreView()
        case .downloader: DownloaderView()
		}
	}
	
	/// 5 tab gốc của Ksign / xSign trước v1.9.5
	static var factoryTabs: [TabEnum] {
		return [
            .files,
            .library,
            .appstore,
            .downloader,
			.settings,
		]
	}
	
	/// Tab hiện trên thanh (theo cấu hình lúc mở app)
	static var defaultTabs: [TabEnum] {
		return XSignTabConfig.launch.visibleTabs
	}
	
	/// Tab chỉ hiện ở thanh bên iPad / iOS 18 (Chứng chỉ). Đã lên thanh chính thì không lặp lại ở đây
	static var customizableTabs: [TabEnum] {
		return [TabEnum.certificates].filter { !XSignTabConfig.launch.visible.contains($0.rawValue) }
	}
	
	/// Tab mở đầu tiên sau khi khởi động
	static var launchDefaultTab: TabEnum {
		return XSignTabConfig.launch.defaultTabEnum
	}
}
