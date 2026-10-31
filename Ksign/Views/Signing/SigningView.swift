//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@Namespace var _namespace

	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isLogsPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
	var signAndInstall: Bool = false
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	private func _getCertAppID() -> String? {
		guard
			let cert = _selectedCert(),
			let decoded = Storage.shared.getProvisionFileDecoded(for: cert),
			let entitlements = decoded.Entitlements,
			let appID = entitlements["application-identifier"]?.value as? String
		else {
			return nil
		}
		return appID.split(separator: ".").dropFirst().joined(separator: ".")
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable, signAndInstall: Bool = false) {
		self.app = app
		self.signAndInstall = signAndInstall
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
    var body: some View {
		NBNavigationView(app.name ?? .localized("Unknown"), displayMode: .inline) {
			Form {
				_customizationOptions(for: app)
				_cert()
				_customizationProperties(for: app)
			}
			.disabled(_isSigning)
			.safeAreaInset(edge: .bottom) {
				if _isSigning {
					Button() {
						_isLogsPresenting = true
					} label: {
						NBSheetButton(title: .localized("Show Logs"))
					}
					.tint(.secondary)
					.compatMatchedTransitionSource(id: "showLogs", ns: _namespace)
				} else {
					Button() {
						_start()
					} label: {
						NBSheetButton(title: .localized("Start Signing"))
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.fullScreenCover(isPresented: $_isLogsPresenting ) {
				LogsView(manager: LogsManager.shared)
					.compatNavigationTransition(id: "showLogs", ns: _namespace)
			}
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
			
			if _optionsManager.options.prefix != nil || _optionsManager.options.suffix != nil {
				var name = app.name ?? ""
				
				if
					let dictName = _temporaryOptions.displayNames[name]
				{
					name = dictName
				}
				
				if let prefix = _optionsManager.options.prefix {
					name = prefix + name
				}
				
				if let suffix = _optionsManager.options.suffix {
					name = name + suffix
				}
				
				_temporaryOptions.appName = name
			}
		}
    }
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Customization")) {
			Menu {
				Button(.localized("Select Alternative Icon")) { _isAltPickerPresenting = true }
				Button(.localized("Choose from Files")) { _isFilePickerPresenting = true }
				Button(.localized("Choose from Photos")) { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle(size: 55)
				} else {
					FRAppIconView(app: app, size: 55)
				}
			}
			
			_infoCell(.localized("Name"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("Name"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("Identifier"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("Identifier"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					certAppId: _getCertAppID(),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("Version"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("Signing")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Advanced")) {
			DisclosureGroup(.localized("Modify")) {
				NavigationLink(.localized("Existing Dylibs")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(String.localized("Frameworks & PlugIns")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink(String.localized("Entitlements")) {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				#endif
				NavigationLink(String.localized("Tweaks")) {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink(String.localized("Properties")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle(.localized("Properties"))
			}
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("Unknown"))
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard _selectedCert() != nil || _temporaryOptions.doAdhocSigning || _temporaryOptions.onlyModify else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isLogsPresenting = _optionsManager.options.signingLogs
		_isSigning = true
#if DEBUG
		LogsManager.shared.startCapture()
#endif
		
		// xSign v7.3: mở hộp thoại tiến trình ký. Màn hình ký tự hạ xuống (LibraryView lắng nghe SigningProgressCenter).
		// Việc ký chạy trong Task riêng (FR.signPackageFile) nên không bị huỷ khi màn hình này đóng;
		// phần xử lý kết quả bên dưới không dùng `self` để không phụ thuộc vòng đời của view.
		let certificate = _selectedCert()
		let certName: String = {
			if _temporaryOptions.doAdhocSigning { return "Ad-hoc" }
			if _temporaryOptions.onlyModify { return "" }
			guard let certificate else { return "" }
			return certificate.nickname ?? Storage.shared.getProvisionFileDecoded(for: certificate)?.Name ?? ""
		}()
		let app = self.app
		let removeApp = _temporaryOptions.removeApp
		let install = signAndInstall
		
		SigningProgressCenter.shared.begin(app: app, certificateName: certName)
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: certificate,
			progress: { stage, fraction in
				SigningProgressCenter.shared.update(stage: stage, fraction: fraction)
			}
		) { error in
			if let error {
				SigningProgressCenter.shared.fail()
				let ok = UIAlertAction(title: .localized("Dismiss"), style: .cancel) { _ in
					SigningProgressCenter.shared.dismiss()
				}
				
				UIAlertController.showAlert(
					title: .localized("Signing"),
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				// Xoá app gốc SAU khi hộp thoại đóng (hộp thoại còn đọc tên/icon app đó)
				if removeApp && !app.isSigned {
					SigningProgressCenter.shared.runAfterDismiss {
						Storage.shared.deleteApp(for: app)
					}
				}
				
				SigningProgressCenter.shared.complete()
				
				if install {
					// LibraryView chờ hộp thoại ký đóng rồi mới mở hộp thoại cài (tránh 2 sheet cùng lúc)
					NotificationCenter.default.post(
						name: NSNotification.Name("feather.installApp"),
						object: nil
					)
				}
			}
		}
	}
}
