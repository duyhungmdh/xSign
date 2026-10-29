//
//  CertificateCellView.swift
//  xSign (personal customization)
//
//  Thẻ chứng chỉ: tên, MẶC ĐỊNH, App ID, tên profile, nhóm, ngày hết hạn + số ngày còn lại.
//  Dùng chung ở tab Cài đặt (.compact), danh sách chứng chỉ (.card), màn hình ký và thông tin app (.full).
//  v5: thêm kiểu .compact / .card, dòng UDID có nút sao chép, menu thẻ.
//  v8.5: UDID lấy từ chứng chỉ (profile), không phụ thuộc UDID máy dán/pairing file.
//

import SwiftUI
import NimbleViews

// MARK: - Expiry helper (NGUỒN DUY NHẤT tính "số ngày còn lại")
// Quy tắc thống nhất toàn app (Cài đặt, Chứng chỉ, Thư viện, màn hình ký, thông tin app):
//  • Số ngày = chênh lệch NGÀY LỊCH (0h hôm nay → 0h ngày hết hạn), theo múi giờ máy.
//    Ví dụ hôm nay 27/10/2026, hết hạn 22/1/2027 → 87 ngày (không phụ thuộc giờ trong ngày).
//  • Màu: xanh > 30 ngày · cam 8–30 · đỏ ≤ 7 hoặc đã hết hạn.
//  • Chữ chip: "N ngày" · "Hôm nay" (còn dưới 1 ngày lịch) · "Hết hạn".
struct CertificateExpiry {
	let date: Date
	let daysLeft: Int
	let isExpired: Bool
	let color: Color
	
	init(_ date: Date, now: Date = .now) {
		self.date = date
		let calendar = Calendar.current
		let days = calendar.dateComponents(
			[.day],
			from: calendar.startOfDay(for: now),
			to: calendar.startOfDay(for: date)
		).day ?? 0
		
		self.daysLeft = max(days, 0)
		self.isExpired = date <= now
		
		if isExpired || days <= 7 {
			self.color = .red
		} else if days <= 30 {
			self.color = .orange
		} else {
			self.color = .green
		}
	}
	
	/// "ngày 22 tháng 1, 2027"
	var dateText: String {
		let c = Calendar.current.dateComponents([.day, .month, .year], from: date)
		return "ngày \(c.day ?? 0) tháng \(c.month ?? 0), \(c.year ?? 0)"
	}
	
	var badgeText: String {
		if isExpired { return "Hết hạn" }
		if daysLeft == 0 { return "Hôm nay" }
		return "\(daysLeft) ngày"
	}
}

extension CertificatePair {
	/// Ngày hết hạn dùng chung cho mọi nơi hiển thị (ưu tiên giá trị đã lưu, không có thì đọc từ profile)
	var xsignExpirationDate: Date? {
		expiration ?? Storage.shared.getProvisionFileDecoded(for: self)?.ExpirationDate
	}
}

// MARK: - Style & colors
enum CertificateCellStyle {
	/// Đầy đủ (màn hình ký, thông tin app)
	case full
	/// Gọn (thẻ "Chứng chỉ đang dùng" ở Cài đặt)
	case compact
	/// Thẻ lớn (danh sách Chứng chỉ): có UDID + menu
	case card
}

extension Color {
	/// Xanh dương cố định cho thao tác / tên chứng chỉ (không đổi theo màu chủ đạo)
	static let xsignAction = Color(UIColor { trait in
		trait.userInterfaceStyle == .dark
		? UIColor(red: 0.36, green: 0.55, blue: 0.95, alpha: 1)
		: UIColor(red: 0.12, green: 0.37, blue: 0.80, alpha: 1)
	})
}

// MARK: - View
struct CertificatesCellView: View {
	@State var data: Certificate?
	
	@ObservedObject var cert: CertificatePair
	
	/// Hiện nhãn MẶC ĐỊNH
	var isDefault: Bool = false
	var style: CertificateCellStyle = .full
	/// Nội dung menu (chevron) - chỉ dùng cho kiểu .card
	var menu: AnyView? = nil
	
	@State private var _copied = false
	
	private var _name: String {
		cert.nickname ?? data?.Name ?? "Không rõ"
	}
	
	// MARK: Body
	var body: some View {
		Group {
			switch style {
			case .full: _fullBody
			case .compact: _compactBody
			case .card: _cardBody
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentTransition(.opacity)
		.onAppear {
			withAnimation {
				data = Storage.shared.getProvisionFileDecoded(for: cert)
			}
		}
	}
}

// MARK: - Bodies
extension CertificatesCellView {
	/// Kiểu cũ (v4)
	@ViewBuilder
	private var _fullBody: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .top, spacing: 12) {
				Image(systemName: "key.fill")
					.font(.title3)
					.foregroundStyle(.secondary)
					.frame(width: 26)
				
				VStack(alignment: .leading, spacing: 4) {
					Text(_name)
						.font(.subheadline.weight(.semibold))
						.lineLimit(1)
					
					if isDefault { _defaultBadge }
					
					if let data {
						_detailLine("App ID: \(data.AppIDName)")
						_detailLine(data.Name)
						_detailLine("Nhóm: \(data.TeamName)")
					}
					
					_statusLines
				}
				
				Spacer(minLength: 0)
			}
			
			_expirySection
		}
	}
	
	/// Thẻ gọn ở Cài đặt: tên (xanh) + key + MẶC ĐỊNH, vạch ngăn, hết hạn + chip
	@ViewBuilder
	private var _compactBody: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 8) {
				Text(_name)
					.font(.headline)
					.foregroundStyle(Color.xsignAction)
					.lineLimit(1)
				Spacer(minLength: 4)
				Image(systemName: "key")
					.foregroundStyle(Color.accentColor)
				if isDefault { _defaultBadge }
			}
			_statusLines
			_expirySection
		}
	}
	
	/// Thẻ lớn ở danh sách Chứng chỉ
	@ViewBuilder
	private var _cardBody: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 8) {
				Text(_name)
					.font(.title3.weight(.semibold))
					.lineLimit(1)
				Spacer(minLength: 4)
				Image(systemName: "key")
					.foregroundStyle(Color.accentColor)
				if isDefault { _defaultBadge }
				if let menu {
					Menu {
						menu
					} label: {
						Image(systemName: "chevron.down")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(.secondary)
							.frame(width: 32, height: 32)
							.contentShape(Rectangle())
					}
				}
			}
			
			if let data {
				_detailLine("App ID: \(data.AppIDName)", font: .subheadline)
				_detailLine("Nhóm: \(data.TeamName)", font: .subheadline)
			}
			_statusLines
			
			_expirySection
			_udidRow
		}
	}
}

// MARK: - Pieces
extension CertificatesCellView {
	@ViewBuilder
	private var _defaultBadge: some View {
		Text("MẶC ĐỊNH")
			.font(.system(size: 10, weight: .bold))
			.foregroundStyle(Color.accentColor)
			.padding(.horizontal, 8)
			.padding(.vertical, 3)
			.background(Capsule().fill(Color.accentColor.opacity(0.18)))
	}
	
	@ViewBuilder
	private var _statusLines: some View {
		if cert.revoked {
			Label("Chứng chỉ đã bị thu hồi", systemImage: "xmark.octagon.fill")
				.font(.caption)
				.foregroundStyle(.red)
		}
		if cert.ppQCheck == true {
			Label("PPQCheck", systemImage: "checkmark.shield")
				.font(.caption)
				.foregroundStyle(.red)
		}
	}
	
	@ViewBuilder
	private var _expirySection: some View {
		if let expiration = cert.expiration ?? data?.ExpirationDate {
			Divider()
			_expiryRow(CertificateExpiry(expiration))
		}
	}
	
	@ViewBuilder
	private func _detailLine(_ text: String, font: Font = .caption) -> some View {
		Text(text)
			.font(font)
			.foregroundStyle(.secondary)
			.lineLimit(1)
			.truncationMode(.middle)
	}
	
	@ViewBuilder
	private func _expiryRow(_ expiry: CertificateExpiry) -> some View {
		HStack(spacing: 6) {
			Image(systemName: expiry.isExpired ? "xmark.circle" : "checkmark.circle")
				.foregroundStyle(expiry.color)
			
			Text(expiry.isExpired ? "Đã hết hạn: \(expiry.dateText)" : "Hết hạn: \(expiry.dateText)")
				.font(.footnote)
				.foregroundStyle(expiry.color)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
			
			Spacer(minLength: 4)
			
			ExpiryChip(text: expiry.badgeText, color: expiry.color)
		}
	}
	
	/// UDID LẤY TỪ CHỨNG CHỈ (ProvisionedDevices trong profile .mobileprovision), không phải UDID máy.
	/// - Profile có nhiều thiết bị: ưu tiên UDID trùng với máy này (nếu biết), không thì thiết bị đầu tiên;
	///   thêm "+N" cho số thiết bị còn lại (xem đủ ở Xem chi tiết).
	/// - Profile Enterprise (mọi thiết bị): hiện chú thích, không có UDID để chép.
	/// - Nếu biết UDID máy này mà nó không có trong chứng chỉ: cảnh báo cam.
	@ViewBuilder
	private var _udidRow: some View {
		if let data {
			let devices = data.ProvisionedDevices ?? []
			if !devices.isEmpty {
				let mine = DeviceInfo.udid.map { _normalizeUDID($0) }
				let matched = devices.first { _normalizeUDID($0) == mine }
				let shown = matched ?? devices[0]
				let extra = devices.count - 1
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 6) {
						Image(systemName: "iphone")
							.foregroundStyle(Color.xsignAction)
						Text(verbatim: "UDID: \(shown)")
							.font(.system(.footnote, design: .monospaced))
							.foregroundStyle(Color.xsignAction)
							.lineLimit(1)
							.truncationMode(.middle)
						if extra > 0 {
							Text(verbatim: "+\(extra)")
								.font(.caption2.weight(.bold))
								.foregroundStyle(Color.xsignAction)
						}
						Spacer(minLength: 4)
						Button {
							UIPasteboard.general.string = shown
							UINotificationFeedbackGenerator().notificationOccurred(.success)
							_copied = true
							DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { _copied = false }
						} label: {
							Image(systemName: _copied ? "checkmark" : "doc.on.doc")
								.font(.footnote.weight(.semibold))
								.foregroundStyle(Color.xsignAction)
								.frame(width: 34, height: 24)
								.background(Capsule().fill(Color.xsignAction.opacity(0.14)))
						}
						.buttonStyle(.borderless)
						.accessibilityLabel(Text("Sao chép UDID"))
					}
					if mine != nil, matched == nil {
						Label("UDID máy này không có trong chứng chỉ", systemImage: "exclamationmark.triangle.fill")
							.font(.caption)
							.foregroundStyle(.orange)
					}
				}
			} else if data.ProvisionsAllDevices == true {
				Label("Chứng chỉ Enterprise: dùng cho mọi thiết bị", systemImage: "iphone")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
	}
	
	/// So sánh UDID bỏ dấu "-" và không phân biệt hoa/thường (profile có thể ghi có hoặc không có dấu)
	private func _normalizeUDID(_ text: String) -> String {
		text.replacingOccurrences(of: "-", with: "").uppercased()
	}
}

// MARK: - Chip "N ngày" (dùng cả ở Thư viện)
struct ExpiryChip: View {
	let text: String
	let color: Color
	
	var body: some View {
		HStack(spacing: 4) {
			Image(systemName: "clock")
				.font(.caption2)
			Text(text)
				.font(.caption.weight(.semibold))
				.lineLimit(1)
				.fixedSize()
		}
		.foregroundStyle(color)
		.padding(.horizontal, 10)
		.padding(.vertical, 4)
		.background(Capsule().fill(color.opacity(0.18)))
	}
}
