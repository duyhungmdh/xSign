//
//  CertificatesAddView.swift
//  xSign (personal customization)
//
//  Thêm chứng chỉ với 3 tab: Thủ công / xSign Cert (.xsigncert) / Tệp ZIP.
//

import SwiftUI
import CoreData
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
	enum Tab: Int, CaseIterable {
		case manual, xsign, zip
		
		var title: String {
			switch self {
			case .manual: return "Thủ công"
			case .xsign: return "xSign Cert"
			case .zip: return "Tệp ZIP"
			}
		}
	}
	
	@Environment(\.dismiss) private var dismiss
	@AppStorage("feather.selectedCert") private var _selectedCertIndex: Int = 0
	
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: []
	) private var _existing: FetchedResults<CertificatePair>
	
	@State private var _tab: Tab = .manual
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _packName: String? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	@State private var _setDefault: Bool = false
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isImportingXSignPresenting = false
	@State private var _isImportingZipPresenting = false
	@State private var _isPasswordAlertPresenting = false
	@State private var _errorMessage: String = ""
	@State private var _isErrorPresenting = false
	
	private var _canSave: Bool {
		_p12URL != nil && _provisionURL != nil
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView("Thêm chứng chỉ", displayMode: .inline) {
			Form {
				Section {
					Picker("", selection: $_tab) {
						ForEach(Tab.allCases, id: \.self) { tab in
							Text(tab.title).tag(tab)
						}
					}
					.pickerStyle(.segmented)
					.labelsHidden()
				}
				.listRowBackground(Color.clear)
				.listRowInsets(EdgeInsets())
				
				switch _tab {
				case .manual: _manualFiles()
				case .xsign: _xsignFile()
				case .zip: _zipFile()
				}
				
				if _tab != .xsign {
					_passwordSection()
				}
				
				_optionsSection()
				_saveSection()
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
			}
			.onChange(of: _tab) { _ in
				_p12URL = nil
				_provisionURL = nil
				_packName = nil
				_p12Password = ""
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.p12],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_p12URL = url
					}
				)
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.mobileProvision],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_provisionURL = url
					}
				)
			}
			.sheet(isPresented: $_isImportingXSignPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.xsignCert, UTType.zip],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_handlePack(url)
					}
				)
			}
			.sheet(isPresented: $_isImportingZipPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.zip],
					onDocumentsPicked: { urls in
						guard let url = urls.first else { return }
						_handlePack(url)
					}
				)
			}
			.alert(isPresented: $_isPasswordAlertPresenting) {
				Alert(
					title: Text("Sai mật khẩu"),
					message: Text("Hãy kiểm tra lại mật khẩu của chứng chỉ rồi thử lại."),
					dismissButton: .default(Text("OK"))
				)
			}
			.alert(isPresented: $_isErrorPresenting) {
				Alert(
					title: Text("Lỗi nhập chứng chỉ"),
					message: Text(_errorMessage),
					dismissButton: .default(Text("OK"))
				)
			}
		}
	}
}

// MARK: - Extension: Sections
extension CertificatesAddView {
	@ViewBuilder
	private func _manualFiles() -> some View {
		Section {
			_fileRow("Chứng chỉ (.p12)", picked: _p12URL?.lastPathComponent) {
				_isImportingP12Presenting = true
			}
			_fileRow("Provisioning Profile", picked: _provisionURL?.lastPathComponent) {
				_isImportingMobileProvisionPresenting = true
			}
		} header: {
			Text("Tệp")
		}
	}
	
	@ViewBuilder
	private func _xsignFile() -> some View {
		Section {
			_fileRow(
				_packName == nil ? "Chọn tệp .xsigncert" : "Tệp đã chọn",
				picked: _packName
			) {
				_isImportingXSignPresenting = true
			}
		} header: {
			Text("Tệp chứng chỉ xSign")
		} footer: {
			Text("Nhập gói chứng chỉ được chia sẻ từ máy khác. Gói đã kèm sẵn mật khẩu.")
		}
	}
	
	@ViewBuilder
	private func _zipFile() -> some View {
		Section {
			_fileRow(
				_packName == nil ? "Chọn tệp ZIP" : "Tệp đã chọn",
				picked: _packName
			) {
				_isImportingZipPresenting = true
			}
		} header: {
			Text("Tệp ZIP")
		} footer: {
			Text("Chọn tệp ZIP có chứa tệp .p12 và .mobileprovision")
		}
	}
	
	@ViewBuilder
	private func _passwordSection() -> some View {
		Section {
			HStack(spacing: 12) {
				Image(systemName: "lock.fill")
					.foregroundStyle(Color.accentColor)
					.frame(width: 26)
				SecureField("Mật khẩu", text: $_p12Password)
			}
		} header: {
			if _tab == .zip { Text("Mật khẩu chứng chỉ") }
		} footer: {
			Text(_tab == .zip
				 ? "Nhập mật khẩu của tệp chứng chỉ .p12"
				 : "Để trống nếu không yêu cầu mật khẩu")
		}
	}
	
	@ViewBuilder
	private func _optionsSection() -> some View {
		Section {
			HStack(spacing: 12) {
				Image(systemName: "tag.fill")
					.foregroundStyle(Color.accentColor)
					.frame(width: 26)
				TextField("Biệt danh (Tùy chọn)", text: $_certificateName)
			}
			Toggle(isOn: $_setDefault) {
				Label("Đặt làm mặc định", systemImage: "star.fill")
			}
		} footer: {
			Text("Chứng chỉ mặc định sẽ được chọn tự động khi ký ứng dụng")
		}
	}
	
	@ViewBuilder
	private func _saveSection() -> some View {
		Section {
			Button {
				_save()
			} label: {
				Label(
					_tab == .manual ? "Lưu chứng chỉ" : "Nhập chứng chỉ",
					systemImage: _tab == .manual ? "checkmark.circle.fill" : "square.and.arrow.down.fill"
				)
				.font(.headline)
				.foregroundStyle(_canSave ? Color.white : Color.secondary)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 6)
			}
			.buttonStyle(.plain)
			.disabled(!_canSave)
			.listRowBackground(
				_canSave ? Color.accentColor : Color(uiColor: .tertiarySystemFill)
			)
		}
	}
	
	@ViewBuilder
	private func _fileRow(_ title: String, picked: String?, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(systemName: picked == nil ? "doc.badge.plus" : "checkmark.circle.fill")
					.foregroundStyle(picked == nil ? Color.accentColor : Color.green)
					.frame(width: 26)
				
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
					if let picked {
						Text(picked)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
							.truncationMode(.middle)
					}
				}
				
				Spacer()
				
				Image(systemName: "chevron.right")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
		}
		.foregroundStyle(.primary)
	}
}

// MARK: - Extension: Actions
extension CertificatesAddView {
	/// Đọc gói .xsigncert hoặc .zip (p12 + mobileprovision, có thể kèm info.json).
	private func _handlePack(_ url: URL) {
		do {
			let pack = try CertificateSharing.importPack(from: url)
			_p12URL = pack.p12
			_provisionURL = pack.provision
			_packName = url.lastPathComponent
			
			if let password = pack.password, !password.isEmpty {
				_p12Password = password
			}
			if _certificateName.isEmpty {
				_certificateName = pack.nickname ?? url.deletingPathExtension().lastPathComponent
			}
		} catch {
			_errorMessage = error.localizedDescription
			_isErrorPresenting = true
		}
	}
	
	private func _save() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			_isPasswordAlertPresenting = true
			return
		}
		
		let previousCount = _existing.count
		let previousSelected = _selectedCertIndex
		let makeDefault = _setDefault
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { error in
			if let error {
				_errorMessage = error.localizedDescription
				_isErrorPresenting = true
				return
			}
			
			// Danh sách sắp theo ngày mới nhất trước -> chứng chỉ vừa thêm nằm ở vị trí 0.
			if makeDefault || previousCount == 0 {
				_selectedCertIndex = 0
			} else {
				_selectedCertIndex = previousSelected + 1
			}
			dismiss()
		}
	}
}
