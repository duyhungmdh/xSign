//
//  CertificateEntitlementCatalog.swift
//  xSign (personal customization)
//
//  Danh mục quyền (entitlement) của provisioning profile, chia nhóm giống zSign.
//

import Foundation

struct EntitlementRowSpec {
	let title: String
	let detail: String
	let key: String
}

struct EntitlementGroupSpec {
	let title: String
	let icon: String
	let rows: [EntitlementRowSpec]
}

enum CertificateEntitlementCatalog {
	static let groups: [EntitlementGroupSpec] = [
		EntitlementGroupSpec(title: "Nhóm ứng dụng & lưu trữ", icon: "square.stack.3d.up", rows: [
			.init(title: "App ID", detail: "Định danh đầy đủ của ứng dụng (Team ID + bundle).", key: "application-identifier"),
			.init(title: "Team ID", detail: "Mã đội ngũ phát triển cấp chứng chỉ.", key: "com.apple.developer.team-identifier"),
			.init(title: "Chia sẻ Keychain", detail: "Dùng chung mục Keychain giữa các app cùng đội.", key: "keychain-access-groups"),
			.init(title: "Nhóm ứng dụng", detail: "Chia sẻ tệp và UserDefaults giữa app và extension.", key: "com.apple.security.application-groups"),
			.init(title: "Bảo vệ dữ liệu", detail: "Mức mã hoá tệp khi thiết bị khoá.", key: "com.apple.developer.default-data-protection"),
			.init(title: "Hoạt động nhóm", detail: "SharePlay qua FaceTime.", key: "com.apple.developer.group-session"),
		]),
		EntitlementGroupSpec(title: "iCloud", icon: "icloud", rows: [
			.init(title: "Container iCloud", detail: "Kho iCloud riêng của ứng dụng.", key: "com.apple.developer.icloud-container-identifiers"),
			.init(title: "Dịch vụ iCloud", detail: "CloudKit / CloudDocuments.", key: "com.apple.developer.icloud-services"),
			.init(title: "Kho khoá-giá trị iCloud", detail: "Đồng bộ thiết lập nhỏ qua iCloud.", key: "com.apple.developer.ubiquity-kvstore-identifier"),
			.init(title: "Tài liệu iCloud", detail: "Thư mục tài liệu đồng bộ iCloud.", key: "com.apple.developer.ubiquity-container-identifiers"),
		]),
		EntitlementGroupSpec(title: "Thông báo", icon: "bell.badge", rows: [
			.init(title: "Thông báo đẩy", detail: "Môi trường APNs: development hoặc production.", key: "aps-environment"),
			.init(title: "Lọc thông báo", detail: "Sửa nội dung thông báo trước khi hiện.", key: "com.apple.developer.usernotifications.filtering"),
			.init(title: "Thông báo khẩn", detail: "Vượt qua chế độ Không làm phiền.", key: "com.apple.developer.usernotifications.time-sensitive"),
			.init(title: "Thông báo liên lạc", detail: "Thông báo kiểu tin nhắn có ảnh người gửi.", key: "com.apple.developer.usernotifications.communication"),
		]),
		EntitlementGroupSpec(title: "Thanh toán & mua hàng", icon: "creditcard", rows: [
			.init(title: "Apple Pay", detail: "Nhận thanh toán qua Apple Pay.", key: "com.apple.developer.in-app-payments"),
			.init(title: "Thẻ thanh toán", detail: "Thêm thẻ vào Wallet.", key: "com.apple.developer.payment-pass-provisioning"),
			.init(title: "Thẻ Wallet", detail: "Quản lý vé / thẻ trong Wallet.", key: "com.apple.developer.pass-type-identifiers"),
			.init(title: "Mua ngoài App Store", detail: "Thanh toán ngoài hệ thống Apple.", key: "com.apple.developer.storekit.external-purchase"),
			.init(title: "Liên kết mua bên ngoài", detail: "Hiện liên kết thanh toán bên ngoài.", key: "com.apple.developer.storekit.external-purchase-link"),
		]),
		EntitlementGroupSpec(title: "Mạng & VPN", icon: "globe", rows: [
			.init(title: "Phần mở rộng mạng", detail: "VPN, lọc nội dung, DNS proxy, Hotspot Helper.", key: "com.apple.developer.networking.networkextension"),
			.init(title: "VPN cá nhân", detail: "Tạo và điều khiển cấu hình VPN cá nhân.", key: "com.apple.developer.networking.vpn.api"),
			.init(title: "Cấu hình điểm truy cập", detail: "Thêm hoặc gỡ cấu hình WiFi.", key: "com.apple.developer.networking.HotspotConfiguration"),
			.init(title: "Thông tin WiFi", detail: "Đọc SSID / BSSID của kết nối hiện tại.", key: "com.apple.developer.networking.wifi-info"),
			.init(title: "TCP đa đường", detail: "Dùng đồng thời di động và WiFi.", key: "com.apple.developer.networking.multipath"),
			.init(title: "Giao thức mạng tuỳ chỉnh", detail: "Giao thức mạng riêng qua DriverKit.", key: "com.apple.developer.networking.custom-protocol"),
			.init(title: "Phân loại network slicing", detail: "Xếp loại lưu lượng cho 5G Network Slicing.", key: "com.apple.developer.networking.slicing.appcategory"),
			.init(title: "Liên kết ứng dụng", detail: "Universal Links và tự điền mật khẩu theo tên miền.", key: "com.apple.developer.associated-domains"),
			.init(title: "Cài phụ kiện không dây", detail: "Đưa phụ kiện MFi vào mạng WiFi.", key: "com.apple.external-accessory.wireless-configuration"),
		]),
		EntitlementGroupSpec(title: "Media & phát lại", icon: "play.rectangle", rows: [
			.init(title: "Camera đa nhiệm", detail: "Dùng camera khi đang chia đôi màn hình.", key: "com.apple.developer.avfoundation.multitasking-camera-access"),
			.init(title: "HLS độ trễ thấp", detail: "Phát trực tiếp HLS độ trễ thấp.", key: "com.apple.developer.coremedia.hls.low-latency"),
			.init(title: "Hội nghị truyền hình", detail: "Ưu tiên camera và micro cho cuộc gọi.", key: "com.apple.developer.avfoundation.video-conferencing"),
			.init(title: "Nhận AirPlay", detail: "Nhận luồng phát từ thiết bị khác.", key: "com.apple.developer.airplay.receiver"),
		]),
		EntitlementGroupSpec(title: "Thiết bị & phần cứng", icon: "cpu", rows: [
			.init(title: "Đọc NFC", detail: "Đọc thẻ NFC và NDEF.", key: "com.apple.developer.nfc.readersession.formats"),
			.init(title: "HealthKit", detail: "Đọc và ghi dữ liệu sức khoẻ.", key: "com.apple.developer.healthkit"),
			.init(title: "HomeKit", detail: "Điều khiển thiết bị nhà thông minh.", key: "com.apple.developer.homekit"),
			.init(title: "Siri", detail: "Nhận lệnh thoại qua SiriKit.", key: "com.apple.developer.siri"),
			.init(title: "CarPlay âm thanh", detail: "Ứng dụng âm thanh trên CarPlay.", key: "com.apple.developer.carplay-audio"),
			.init(title: "App Attest", detail: "Xác thực tính toàn vẹn của ứng dụng.", key: "com.apple.developer.devicecheck.appattest-environment"),
			.init(title: "DriverKit", detail: "Driver chạy ở user-space.", key: "com.apple.developer.driverkit"),
			.init(title: "DriverKit USB", detail: "Driver thiết bị USB.", key: "com.apple.developer.driverkit.transport.usb"),
			.init(title: "DriverKit HID", detail: "Driver thiết bị nhập HID.", key: "com.apple.developer.driverkit.transport.hid"),
			.init(title: "Phụ kiện ngoài", detail: "Giao tiếp với phụ kiện MFi.", key: "com.apple.external-accessory.protocols"),
		]),
		EntitlementGroupSpec(title: "Bảo mật & Sandbox", icon: "lock.shield", rows: [
			.init(title: "Bảo mật điểm cuối", detail: "Giám sát sự kiện hệ thống (macOS).", key: "com.apple.developer.endpoint-security.client"),
			.init(title: "Hộp cát ứng dụng", detail: "Chạy trong hộp cát (macOS).", key: "com.apple.security.app-sandbox"),
			.init(title: "Client mạng Sandbox", detail: "Cho phép kết nối ra ngoài trong hộp cát.", key: "com.apple.security.network.client"),
			.init(title: "Server mạng Sandbox", detail: "Cho phép mở cổng lắng nghe trong hộp cát.", key: "com.apple.security.network.server"),
			.init(title: "Cài extension hệ thống", detail: "Cài extension hệ thống ở user-space (macOS).", key: "com.apple.developer.system-extension.install"),
			.init(title: "Tăng giới hạn bộ nhớ", detail: "Dùng RAM vượt mức mặc định.", key: "com.apple.developer.kernel.increased-memory-limit"),
			.init(title: "Địa chỉ ảo mở rộng", detail: "Không gian địa chỉ ảo lớn hơn.", key: "com.apple.developer.kernel.extended-virtual-addressing"),
			.init(title: "Trình duyệt mặc định", detail: "Đăng ký làm trình duyệt mặc định.", key: "com.apple.developer.web-browser"),
			.init(title: "Đăng nhập bằng Apple", detail: "Dùng tài khoản Apple để đăng nhập.", key: "com.apple.developer.applesignin"),
		]),
		EntitlementGroupSpec(title: "Phát triển & gỡ lỗi", icon: "hammer", rows: [
			.init(title: "Có thể debug", detail: "Chỉ có ở profile Development: cho phép lldb / Xcode gắn vào.", key: "get-task-allow"),
			.init(title: "Không dùng container", detail: "Thoát khỏi thư mục sandbox riêng.", key: "com.apple.private.security.no-container"),
			.init(title: "App Clip", detail: "Ứng dụng cài theo yêu cầu.", key: "com.apple.developer.on-demand-install-capable"),
			.init(title: "TestFlight", detail: "Gửi báo cáo bản beta.", key: "beta-reports-active"),
		]),
	]
	
	/// Tất cả key đã được xếp vào nhóm; key còn lại sẽ vào nhóm "Khác".
	static let knownKeys: Set<String> = Set(groups.flatMap { $0.rows.map { $0.key } })
}
