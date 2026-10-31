//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	
	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _selectedAppDylibsPresenting: AnyApp?
	@State private var _isBulkSigningPresenting = false
    @State private var _isBulkInstallingPresenting = false
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _isSigningSheetPresenting = false
	@State private var _pendingInstallAfterSigning = false
	@ObservedObject private var _signingProgress = SigningProgressCenter.shared

	@State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
	@State private var _searchText = ""
	@State private var _selectedTab: Int = 0 // 0 for Downloaded, 1 for Signed
	
	// MARK: Edit Mode
    @State private var _isEditMode: EditMode = .inactive
	@State private var _selectedApps: Set<String> = []
	
	@Namespace private var _namespace
	
	// horror
	private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
		apps.filter {
			_searchText.isEmpty ||
			(($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}
	
	private var _filteredSignedApps: [Signed] {
		filteredAndSortedApps(from: _signedApps)
	}
	
	private var _filteredImportedApps: [Imported] {
		filteredAndSortedApps(from: _importedApps)
	}
	
	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>
	
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("Library")) {
			VStack(spacing: 0) {
				Picker("", selection: $_selectedTab) {
					Text(.localized("Downloaded Apps")).tag(0)
					Text(.localized("Signed Apps")).tag(1)
				}
				.pickerStyle(SegmentedPickerStyle())
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// xSign v6: thanh tiến trình dẹt nằm ngay trên tiêu đề danh sách
				Group {
					if _selectedTab == 0 {
						ImportProgressBar()
					} else {
						InstallProgressBar()
					}
				}
				
				NBListAdaptable {
					if _selectedTab == 0 {
						NBSection(
							.localized("Downloaded Apps"),
							secondary: _filteredImportedApps.count.description
						) {
							ForEach(_filteredImportedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting,
									selectedAppDylibsPresenting: $_selectedAppDylibsPresenting,
									selectedApps: $_selectedApps
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					} else {
						NBSection(
							.localized("Signed Apps"),
							secondary: _filteredSignedApps.count.description
						) {
							ForEach(_filteredSignedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting,
									selectedAppDylibsPresenting: $_selectedAppDylibsPresenting,
									selectedApps: $_selectedApps
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform())
            .overlay {
                if
                    _filteredSignedApps.isEmpty,
                    _filteredImportedApps.isEmpty
                {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
                        } description: {
                            Text(.localized("Get started by importing your first IPA file."))
                        } actions: {
                            Menu {
                                _importActions()
                            } label: {
                                Text("Import").bg()
                            }
                        }
                    }
                }
            }
			.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                if _isEditMode.isEditing {
					ToolbarItemGroup(placement: .topBarTrailing) {
                        if _selectedTab == 0 {
                            Button {
                                _isBulkSigningPresenting = true
                            } label: {
                                NBButton(.localized("Sign"), systemImage: "signature", style: .icon)
                            }
                            .disabled(_selectedApps.isEmpty)
                        } else {
                            Button {
                                _isBulkInstallingPresenting = true
                            } label: {
                                NBButton(.localized("Install"), systemImage: "square.and.arrow.down")
                            }
                            .disabled(_selectedApps.isEmpty)
                        }
						Button {
							_bulkDeleteSelectedApps()
						} label: {
							NBButton(.localized("Delete"), systemImage: "trash", style: .icon)
						}
						.disabled(_selectedApps.isEmpty)
					}
				} else {
					NBToolbarMenu(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
                        _importActions()
                    }
				}
			}
            .environment(\.editMode, $_isEditMode)
			// xSign v7: báo cho app biết đang ở tab Thư viện (để ẩn thanh tiến trình gốc ở đầu app)
			.onAppear { XSignLibraryState.shared.isLibraryVisible = true }
			.onDisappear { XSignLibraryState.shared.isLibraryVisible = false }
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(210)])
					.presentationDragIndicator(.visible)
					.xsignSheetBackground()
			}
			// xSign v7.3: bấm "Bắt đầu ký" → màn hình ký hạ xuống → hiện hộp thoại tiến trình ký.
			// Hộp thoại chỉ mở SAU khi màn hình ký đã đóng hẳn (onDismiss của fullScreenCover), nên không bị bỏ qua.
			.sheet(isPresented: $_isSigningSheetPresenting, onDismiss: {
				if _signingProgress.phase != .running { _signingProgress.dismiss() }
				// Ký & cài: hộp thoại ký đóng xong mới mở hộp thoại cài đặt
				if _pendingInstallAfterSigning {
					_pendingInstallAfterSigning = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
						if let app = _signedApps.first {
							_selectedInstallAppPresenting = AnyApp(base: app)
						}
					}
				}
			}) {
				SigningSheetContent()
					.presentationDetents([.height(210)])
					.presentationDragIndicator(.visible)
					.interactiveDismissDisabled(_signingProgress.phase == .running)
					.xsignSheetBackground()
			}
			.onReceive(SigningProgressCenter.shared.$phase) { phase in
				if phase == .running, !_isSigningSheetPresenting {
					if _selectedSigningAppPresenting != nil {
						// hạ màn hình ký xuống; hộp thoại sẽ mở ở onDismiss bên dưới
						_selectedSigningAppPresenting = nil
					} else {
						_isSigningSheetPresenting = true
					}
					// dự phòng: nếu onDismiss không chạy thì vẫn mở hộp thoại sau 1 giây
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
						if SigningProgressCenter.shared.phase != .idle, !_isSigningSheetPresenting {
							_isSigningSheetPresenting = true
						}
					}
				} else if phase == .idle {
					_isSigningSheetPresenting = false
				}
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting, onDismiss: {
				if SigningProgressCenter.shared.phase != .idle, !_isSigningSheetPresenting {
					_isSigningSheetPresenting = true
				}
			}) { app in
				SigningView(app: app.base, signAndInstall: app.signAndInstall)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.fullScreenCover(item: $_selectedAppDylibsPresenting) { app in
                DylibsView(app: app.base)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.fullScreenCover(isPresented: $_isBulkSigningPresenting) {
				BulkSigningView(apps: _selectedApps.compactMap { id in
					(_importedApps.first(where: { $0.uuid == id }) as AppInfoPresentable?)
					?? (_signedApps.first(where: { $0.uuid == id }) as AppInfoPresentable?)
				})
				.compatNavigationTransition(id: _selectedApps.joined(separator: ","), ns: _namespace)
				.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ksign.bulkSigningFinished"))) { notification in
					_selectedTab = 1
				}
			}
            .sheet(isPresented: $_isBulkInstallingPresenting) {
                BulkInstallPreviewView(apps: _selectedApps.compactMap { id in
                    (_importedApps.first(where: { $0.uuid == id }) as AppInfoPresentable?)
                    ?? (_signedApps.first(where: { $0.uuid == id }) as AppInfoPresentable?)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						
						for ipas in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: ipas, id: id)
							downloadManager.handlePachageFile(url: ipas, dl: dl) { err in
								if let error = err {
									UIAlertController.showAlertWithOk(title: "Error", message: .localized("Whoops!, something went wrong when extracting the file. \nMaybe try switching the extraction library in the settings?"))
								}
							}
						}
					}
				)
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("feather.installApp"))) { notification in
				// đang ký (hộp thoại ký còn mở) → chờ nó đóng rồi mới mở hộp thoại cài
				if SigningProgressCenter.shared.phase != .idle || _isSigningSheetPresenting {
					_pendingInstallAfterSigning = true
				} else if let app = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: app)
				}
			}
        }
        .onChange(of: _isEditMode) { state in
            if !state.isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    withAnimation{
                        _selectedApps.removeAll()
                    }
                }
            }
        }
    }
}

extension LibraryView {
    @ViewBuilder
    private func _importActions() -> some View {
        Button(.localized("Import from Files"), systemImage: "folder") {
            _isImportingPresenting = true
        }
        Button(.localized("Import from URL"), systemImage: "globe") {
            _isDownloadingPresenting = true
        }
    }
}


// MARK: - Extension: View (Edit Mode Functions)
extension LibraryView {
	private func _bulkDeleteSelectedApps() {
		let appsToDelete = _selectedApps
		
		withAnimation(.easeInOut(duration: 0.5)) {
			for appUUID in appsToDelete {
				if let signedApp = _signedApps.first(where: { $0.uuid == appUUID }) {
					Storage.shared.deleteApp(for: signedApp)
				} else if let importedApp = _importedApps.first(where: { $0.uuid == appUUID }) {
					Storage.shared.deleteApp(for: importedApp)
				}
			}
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
			_selectedApps.removeAll()
		}
	}
}
