//
//  LibraryAppIconView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//
//  xSign v5: tab Đã tải về có nút "Ký" + tên tệp; tab Đã ký có chip ngày còn lại, dung lượng, nút "Cài đặt".
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
	@AppStorage("Feather.libraryCellAppearance") private var _libraryCellAppearance: Int = 0
    @Environment(\.editMode) private var editMode
	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppDylibsPresenting: AnyApp?
	@Binding var selectedApps: Set<String>
	@State private var _showActionSheet = false
	@State private var _sizeText: String?
	@ObservedObject private var _fileNames = ImportedFileNames.shared
	
	private var _isSelected: Bool {
		selectedApps.contains(app.uuid ?? "")
	}
	// MARK: Body
	var body: some View {
        let isEditing = editMode?.wrappedValue == .active
        HStack(spacing: 9) {
			if isEditing {
				Button {
					_toggleSelection()
				} label: {
					Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
						.foregroundColor(_isSelected ? .accentColor : .secondary)
						.font(.title2)
				}
				.buttonStyle(.borderless)
			}
			
			FRAppIconView(app: app, size: 57)
			
			VStack(alignment: .leading, spacing: 3) {
				Text(app.name ?? .localized("Unknown"))
					.font(.headline)
					.lineLimit(1)
				Text(_desc)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(1)
				_extraLine
			}
			
			Spacer(minLength: 4)
			
			if !isEditing {
				if app.isSigned {
					// v7: nút Cài đặt thu thành icon tròn gọn, nhường chỗ cho dòng bundle ID
					Button {
						selectedInstallAppPresenting = AnyApp(base: app)
					} label: {
						XSignInstallButtonLabel()
					}
					.buttonStyle(.borderless)
					.accessibilityLabel(Text(.localized("Install")))
				} else {
					Button {
						selectedSigningAppPresenting = AnyApp(base: app)
					} label: {
						VStack(spacing: 2) {
							Image(systemName: "signature")
								.font(.title3)
							Text(.localized("Sign"))
								.font(.caption.weight(.semibold))
						}
						.foregroundStyle(Color.xsignAction)
						.frame(minWidth: 40)
					}
					.buttonStyle(.borderless)
				}
				
				Image(systemName: "chevron.right")
					.foregroundColor(.secondary)
					.font(.footnote)
			}
		}
		.scaleEffect(_isSelected ? 0.98 : 1.0)
		.contentShape(Rectangle())
		.onAppear { _loadSizeIfNeeded() }
		.onTapGesture {
			if isEditing {
				_toggleSelection()
			} else {
				_showActionSheet = true
			}
		}
		.confirmationDialog(
			app.name ?? .localized("Unknown"),
			isPresented: $_showActionSheet,
			titleVisibility: .visible
		) {
			if !isEditing {
				_actionSheetButtons(for: app)
			}
		}
		.swipeActions(edge: .trailing) {
			if !isEditing {
				// Xóa nằm sát mép phải; Chia sẻ .ipa chỉ có ở tab Ứng dụng đã ký (v1.9.4)
				_actions(for: app)
				if app.isSigned {
					Button {
						XSignShare.shareSignedIPA(app, fileName: XSignShare.signedFileName(source: nil, signed: app))
					} label: {
						Label(.localized("Share"), systemImage: "square.and.arrow.up")
					}
					.tint(.blue)
				}
			}
		}
		.contextMenu {
			if !isEditing {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				_actions(for: app)
			}
		}
	}
	
	private var _desc: String {
		if
			let version = app.version,
			let id = app.identifier
		{
			return "\(version) • \(id)"
		} else {
			return .localized("Unknown")
		}
	}
	
	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		
		let impactFeedback = UIImpactFeedbackGenerator(style: .light)
		impactFeedback.impactOccurred()
		
		withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
			if _isSelected {
				selectedApps.remove(uuid)
			} else {
				selectedApps.insert(uuid)
			}
		}
	}
}


// MARK: - xSign v5 helpers
extension LibraryCellView {
	/// Dòng thứ 3: tab Đã tải về = tên tệp; tab Đã ký = chip ngày còn lại + dung lượng
	@ViewBuilder
	private var _extraLine: some View {
		if app.isSigned {
			HStack(spacing: 8) {
				if let cert = Storage.shared.getCertificate(from: app), let expiration = cert.xsignExpirationDate {
					let info = CertificateExpiry(expiration)
					ExpiryChip(text: info.badgeText, color: info.color)
				}
				if let _sizeText {
					HStack(spacing: 4) {
						Image(systemName: "internaldrive")
						Text(_sizeText)
					}
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
				}
			}
		} else {
			HStack(spacing: 4) {
				Image(systemName: "doc")
				Text(_fileName)
					.truncationMode(.middle)
			}
			.font(.caption)
			.foregroundStyle(.secondary)
			.lineLimit(1)
		}
	}
	
	/// Tên tệp .ipa gốc (nếu biết), không thì ghép từ tên + phiên bản
	private var _fileName: String {
		// v7: ưu tiên tên tệp đã lưu lúc nhập, hiển thị nguyên văn
		if let saved = _fileNames.name(for: app.uuid) {
			return saved
		}
		if let name = (app as? Imported)?.source?.lastPathComponent, !name.isEmpty {
			return name
		}
		let n = app.name ?? "app"
		return app.version.map { "\(n)_\($0).ipa" } ?? "\(n).ipa"
	}
	
	/// Tính dung lượng thư mục app đã ký (nền, không chặn giao diện)
	private func _loadSizeIfNeeded() {
		guard app.isSigned, _sizeText == nil,
			  let dir = Storage.shared.getUuidDirectory(for: app) else { return }
		DispatchQueue.global(qos: .utility).async {
			var total: Int64 = 0
			if let en = FileManager.default.enumerator(
				at: dir,
				includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
				options: []
			) {
				for case let url as URL in en {
					let v = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
					if v?.isRegularFile == true { total += Int64(v?.totalFileAllocatedSize ?? 0) }
				}
			}
			let f = ByteCountFormatter()
			f.countStyle = .file
			let text = f.string(fromByteCount: total)
			DispatchQueue.main.async { _sizeText = text }
		}
	}
}

// MARK: - Extension: View
extension LibraryCellView {
	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}
	
	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if app.isSigned {
			if let id = app.identifier {
				Button(.localized("Open"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Re-sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Export"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
		}
	}
	
	@ViewBuilder
	private func _actionSheetButtons(for app: AppInfoPresentable) -> some View {
		if app.isSigned {
			Button(.localized("Install")) {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			
			if let id = app.identifier {
				Button(.localized("Open")) {
					UIApplication.openApp(with: id)
				}
			}
			
			Button(.localized("Re-sign")) {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			
			Button(.localized("Export")) {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("Sign & Install")) {
				selectedSigningAppPresenting = AnyApp(base: app, signAndInstall: true)
			}
			
			Button(.localized("Sign")) {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			
			Button(.localized("Export")) {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		}
		
		Button(.localized("Show Dylibs")) {
			selectedAppDylibsPresenting = AnyApp(base: app)
		}
		
		Button(.localized("Get Info")) {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
		
		Button(.localized("Delete"), role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
}


// MARK: - Nút Cài đặt (v7.2, theo hình mẫu)
/// Hình tròn xanh phẳng, biểu tượng khay + mũi tên tải xuống màu trắng, chữ "Cài đặt" đậm bên dưới.
/// Cột nút chỉ rộng bằng chữ → dòng bundle ID không bị cắt.
struct XSignInstallButtonLabel: View {
	static let size: CGFloat = 32
	static let blue = Color(red: 0.11, green: 0.37, blue: 0.85)
	
	var body: some View {
		VStack(spacing: 3) {
			ZStack {
				Circle().fill(Self.blue)
				XSignInstallGlyph()
					.stroke(Color.white, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
					.frame(width: Self.size * 0.52, height: Self.size * 0.52)
			}
			.frame(width: Self.size, height: Self.size)
			
			Text(.localized("Install"))
				.font(.system(size: 10, weight: .bold))
				.foregroundStyle(Self.blue)
				.lineLimit(1)
				.fixedSize()
		}
	}
}

/// Khay bo góc (hở giữa cạnh trên) + mũi tên đi xuống, vẽ trong khung vuông 0...1
struct XSignInstallGlyph: Shape {
	func path(in rect: CGRect) -> Path {
		func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
			CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
		}
		var p = Path()
		let l: CGFloat = 0.04, r: CGFloat = 0.96, t: CGFloat = 0.34, b: CGFloat = 0.96, k: CGFloat = 0.16
		// khay
		p.move(to: pt(0.36, t))
		p.addLine(to: pt(l + k, t))
		p.addQuadCurve(to: pt(l, t + k), control: pt(l, t))
		p.addLine(to: pt(l, b - k))
		p.addQuadCurve(to: pt(l + k, b), control: pt(l, b))
		p.addLine(to: pt(r - k, b))
		p.addQuadCurve(to: pt(r, b - k), control: pt(r, b))
		p.addLine(to: pt(r, t + k))
		p.addQuadCurve(to: pt(r - k, t), control: pt(r, t))
		p.addLine(to: pt(0.64, t))
		// mũi tên
		p.move(to: pt(0.5, 0.0))
		p.addLine(to: pt(0.5, 0.70))
		p.move(to: pt(0.31, 0.51))
		p.addLine(to: pt(0.5, 0.70))
		p.addLine(to: pt(0.69, 0.51))
		return p
	}
}
