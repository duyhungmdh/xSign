//
//  CertificatesInfoView.swift
//  xSign (personal customization)
//
//  Chi tiết chứng chỉ theo từng nhóm (giống zSign): chứng chỉ P12, provisioning profile,
//  quyền theo nhóm (tick xanh = có, x xám = không có) và UDID thiết bị.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesInfoView: View {
	@Environment(\.dismiss) var dismiss
	@State private var data: Certificate?
	@State private var x509: X509CertificateInfo?
	
	var cert: CertificatePair
	
	// MARK: Body
	var body: some View {
		NBNavigationView("Chi tiết chứng chỉ", displayMode: .inline) {
			List {
				if let data {
					_p12Section(data)
					_profileSection(data)
					_entitlementSections(data)
					_devicesSection(data)
				} else {
					Section {
						HStack {
							Spacer()
							ProgressView()
							Spacer()
						}
					}
				}
			}
			.listStyle(.insetGrouped)
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
			_loadX509()
			// Kiểm tra OCSP (thu hồi) để trạng thái hiển thị đúng
			Storage.shared.revokagedCertificate(for: cert)
		}
	}
	
	private func _loadX509() {
		let p12 = Storage.shared.getFile(.certificate, from: cert)
		let password = cert.password ?? ""
		let fallback = data?.DeveloperCertificates?.first
		
		DispatchQueue.global(qos: .userInitiated).async {
			let info = X509CertificateInfo.load(p12: p12, password: password, fallbackDER: fallback)
			DispatchQueue.main.async {
				x509 = info
			}
		}
	}
}

// MARK: - Extension: Sections
extension CertificatesInfoView {
	// MARK: Chứng chỉ (P12)
	@ViewBuilder
	private func _p12Section(_ data: Certificate) -> some View {
		Section {
			if let x509 {
				_kv("Common Name", x509.commonName)
				_kv("Tổ chức", x509.organization)
				_kv("OU", x509.organizationalUnit)
				_kv("UID / Team ID", x509.userID.isEmpty ? (data.TeamIdentifier.first ?? "") : x509.userID)
				_kv("Quốc gia", x509.country)
				_kv("Serial", x509.serialNumber, mono: true)
				_kv("SHA-1", x509.sha1, mono: true, copy: true)
				if let from = x509.notBefore {
					_kv("Hiệu lực từ", _dateTime(from))
				}
				if let to = x509.notAfter {
					_kv("Hiệu lực đến", _dateTime(to))
				}
				_kv("Bên cấp", x509.issuerCommonName)
			} else {
				_kv("Team", data.TeamName)
				_kv("Team ID", data.TeamIdentifier.first ?? "")
			}
			
			if cert.revoked {
				_kv("OCSP", "Đã bị thu hồi", color: Color.red)
			} else {
				_kv("OCSP", "Hợp lệ (OCSP đã xác minh)", color: Color.green)
			}
		} header: {
			_header("Chứng chỉ (P12)", icon: "doc.badge.gearshape")
		}
	}
	
	// MARK: Provisioning Profile
	@ViewBuilder
	private func _profileSection(_ data: Certificate) -> some View {
		Section {
			_kv("Tên", data.Name)
			_kv("App ID Name", data.AppIDName)
			if let bundleID = _bundleID(data) {
				_kv("Bundle ID", bundleID, mono: true, copy: true)
			}
			_kv("Đội ngũ", data.TeamName)
			_kv("Team ID", data.TeamIdentifier.first ?? "")
			_kv("Loại", _profileType(data))
			_kv("UUID", data.UUID, mono: true, copy: true)
			_kv("Phiên bản", "\(data.Version)")
			_kv("Ngày tạo", _dateTime(data.CreationDate))
			_kv("Hết hạn", _dateTime(data.ExpirationDate))
			_kv("Thiết bị", "\(data.ProvisionedDevices?.count ?? 0)")
			_kv("Nền tảng", data.Platform.joined(separator: ", "))
		} header: {
			_header("Provisioning Profile", icon: "doc.badge.ellipsis")
		}
	}
	
	// MARK: Quyền theo nhóm
	@ViewBuilder
	private func _entitlementSections(_ data: Certificate) -> some View {
		let entitlements = data.Entitlements ?? [:]
		
		ForEach(CertificateEntitlementCatalog.groups, id: \.title) { group in
			Section {
				ForEach(group.rows, id: \.key) { row in
					_entitlementRow(
						title: row.title,
						detail: row.detail,
						key: row.key,
						value: entitlements[row.key]?.value,
						present: entitlements[row.key] != nil
					)
				}
			} header: {
				_header(group.title, icon: group.icon)
			}
		}
		
		let others = entitlements.keys
			.filter { !CertificateEntitlementCatalog.knownKeys.contains($0) }
			.sorted()
		
		if !others.isEmpty {
			Section {
				ForEach(others, id: \.self) { key in
					_entitlementRow(
						title: String(key.split(separator: ".").last ?? Substring(key)),
						detail: nil,
						key: key,
						value: entitlements[key]?.value,
						present: true
					)
				}
				NavigationLink("Xem toàn bộ entitlements") {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				}
			} header: {
				_header("Khác", icon: "ellipsis.circle")
			}
		} else if !entitlements.isEmpty {
			Section {
				NavigationLink("Xem toàn bộ entitlements") {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				}
			}
		}
	}
	
	// MARK: UDID
	@ViewBuilder
	private func _devicesSection(_ data: Certificate) -> some View {
		if let devices = data.ProvisionedDevices, !devices.isEmpty {
			Section {
				ForEach(Array(devices.enumerated()), id: \.offset) { index, udid in
					HStack(spacing: 12) {
						Text("\(index + 1)")
							.font(.footnote)
							.foregroundStyle(.secondary)
							.frame(width: 24, alignment: .leading)
						Text(udid)
							.font(.system(.footnote, design: .monospaced))
							.lineLimit(1)
							.minimumScaleFactor(0.7)
						Spacer(minLength: 4)
						_copyButton(udid)
					}
				}
			} header: {
				_header("UDID thiết bị (\(devices.count))", icon: "iphone")
			}
		} else if data.ProvisionsAllDevices == true {
			Section {
				Text("Profile Enterprise: dùng được cho mọi thiết bị.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			} header: {
				_header("UDID thiết bị", icon: "iphone")
			}
		}
	}
}

// MARK: - Extension: Rows
extension CertificatesInfoView {
	@ViewBuilder
	private func _header(_ title: String, icon: String) -> some View {
		Label(title, systemImage: icon)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(Color.accentColor)
			.textCase(nil)
	}
	
	@ViewBuilder
	private func _kv(
		_ title: String,
		_ value: String,
		mono: Bool = false,
		copy: Bool = false,
		color: Color? = nil
	) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text(title)
				.foregroundStyle(.secondary)
				.frame(width: 104, alignment: .leading)
			
			Text(value.isEmpty ? "—" : value)
				.font(mono ? .system(.footnote, design: .monospaced) : .body)
				.foregroundStyle(color ?? Color.primary)
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)
			
			if copy {
				_copyButton(value)
			}
		}
	}
	
	@ViewBuilder
	private func _copyButton(_ text: String) -> some View {
		Button {
			UIPasteboard.general.string = text
			UINotificationFeedbackGenerator().notificationOccurred(.success)
		} label: {
			Image(systemName: "doc.on.doc")
				.foregroundStyle(.secondary)
		}
		.buttonStyle(.borderless)
	}
	
	@ViewBuilder
	private func _entitlementRow(
		title: String,
		detail: String?,
		key: String,
		value: Any?,
		present: Bool
	) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: present ? "checkmark.circle.fill" : "xmark.circle.fill")
				.font(.title3)
				.foregroundStyle(present ? Color.green : Color.gray)
			
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				
				if let detail {
					Text(detail)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				
				if present, let text = _format(value), !text.isEmpty {
					Text(text)
						.font(.system(.footnote, design: .monospaced))
						.textSelection(.enabled)
				}
				
				Text(key)
					.font(.system(.caption, design: .monospaced))
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}
		}
		.padding(.vertical, 2)
	}
}

// MARK: - Extension: Helpers
extension CertificatesInfoView {
	private func _bundleID(_ data: Certificate) -> String? {
		guard let full = data.Entitlements?["application-identifier"]?.value as? String else {
			return nil
		}
		// "TEAMID.com.example.app" -> "com.example.app"
		if let dot = full.firstIndex(of: ".") {
			return String(full[full.index(after: dot)...])
		}
		return full
	}
	
	private func _profileType(_ data: Certificate) -> String {
		if data.ProvisionsAllDevices == true {
			return "Enterprise"
		}
		if let devices = data.ProvisionedDevices, !devices.isEmpty {
			let debuggable = data.Entitlements?["get-task-allow"]?.value as? Bool ?? false
			return debuggable ? "Development" : "Ad Hoc"
		}
		return "App Store"
	}
	
	private func _dateTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "vi_VN")
		formatter.dateFormat = "HH:mm 'ngày' d 'thg' M, yyyy"
		return formatter.string(from: date)
	}
	
	private func _format(_ value: Any?) -> String? {
		guard let value else { return nil }
		switch value {
		case let bool as Bool:
			return bool ? "true" : "false"
		case let string as String:
			return string
		case let number as NSNumber:
			return number.stringValue
		case let array as [Any]:
			return array.compactMap { _format($0) }.joined(separator: ", ")
		case let dict as [String: Any]:
			return dict
				.sorted { $0.key < $1.key }
				.map { "\($0.key): \(_format($0.value) ?? "")" }
				.joined(separator: ", ")
		default:
			return String(describing: value)
		}
	}
}
