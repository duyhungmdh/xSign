//
//  TabBarCustomizationView.swift
//  xSign v1.9.5
//
//  Cài đặt → Tính năng → Điều chỉnh thanh điều hướng.
//  Sắp xếp thứ tự, ẩn/hiện tab, chọn tab mở mặc định, đổi icon SF Symbol của từng tab.
//  Cấu hình lưu bằng `XSignTabConfig`, thanh tab đọc lúc mở app nên có hiệu lực ở lần khởi động sau.
//

import SwiftUI
import NimbleViews
import NimbleExtensions

extension TabEnum: Identifiable {
	var id: String { rawValue }
}

// MARK: - View
struct TabBarCustomizationView: View {
	@State private var _config: XSignTabConfig = XSignTabConfig.load()
	@State private var _iconTab: TabEnum?
	@State private var _showReset = false
	
	private var _hasPendingChanges: Bool { _config != XSignTabConfig.launch }
	
	var body: some View {
		NBList(.localized("Điều chỉnh thanh điều hướng")) {
			_infoSection()
			_defaultSection()
			_currentSection()
			_hiddenSection()
			_resetSection()
		}
		.sheet(item: $_iconTab) { tab in
			TabIconPickerView(
				tab: tab,
				current: _config.icons[tab.rawValue]
			) { newIcon in
				var next = _config
				if let newIcon, !newIcon.isEmpty {
					next.icons[tab.rawValue] = newIcon
				} else {
					next.icons.removeValue(forKey: tab.rawValue)
				}
				_apply(next)
			}
			.presentationDetents([.medium, .large])
		}
		.alert("Khôi phục thanh điều hướng mặc định", isPresented: $_showReset) {
			Button("Hủy", role: .cancel) {}
			Button("Khôi phục", role: .destructive) {
				XSignTabConfig.reset()
				_config = XSignTabConfig.factory
			}
		} message: {
			Text("Thứ tự, tab mặc định và icon sẽ về như ban đầu ở lần khởi động sau.")
		}
	}
	
	/// Lưu cấu hình (đã làm sạch) và cập nhật giao diện
	private func _apply(_ next: XSignTabConfig) {
		let clean = next.sanitized()
		clean.save()
		withAnimation(.snappy) { _config = clean }
	}
}

// MARK: - Sections
extension TabBarCustomizationView {
	@ViewBuilder
	private func _infoSection() -> some View {
		Section {
			HStack(alignment: .top, spacing: 12) {
				Image(systemName: _hasPendingChanges ? "exclamationmark.circle.fill" : "info.circle.fill")
					.font(.title3)
					.foregroundStyle(_hasPendingChanges ? Color.orange : Color.accentColor)
				VStack(alignment: .leading, spacing: 4) {
					Text("Cấu hình thanh điều hướng sẽ có hiệu lực ở lần khởi động sau.")
						.font(.subheadline.weight(.semibold))
					Text("Tại đây có thể chỉnh thứ tự, trạng thái hiển thị, trang mở mặc định và biểu tượng SF Symbol của từng tab.")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			.padding(.vertical, 4)
			
			if _hasPendingChanges {
				Button {
					UIApplication.shared.suspendAndReopen()
				} label: {
					Label("Khởi động lại để áp dụng", systemImage: "arrow.clockwise")
				}
			}
		}
	}
	
	@ViewBuilder
	private func _defaultSection() -> some View {
		Section {
			HStack(spacing: 12) {
				Image(systemName: "star.fill")
					.font(.title3)
					.foregroundStyle(Color.accentColor)
					.frame(width: 26)
				VStack(alignment: .leading, spacing: 2) {
					Text("Mở mặc định")
					Text("Trang mở mặc định sau khi khởi động")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Picker("", selection: Binding(
					get: { _config.defaultTab },
					set: { value in
						var next = _config
						next.defaultTab = value
						_apply(next)
					}
				)) {
					ForEach(_config.visibleTabs) { tab in
						Text(verbatim: tab.title).tag(tab.rawValue)
					}
				}
				.labelsHidden()
				.pickerStyle(.menu)
			}
		}
	}
	
	@ViewBuilder
	private func _currentSection() -> some View {
		let tabs = _config.visibleTabs
		Section {
			ForEach(Array(tabs.enumerated()), id: \.element.rawValue) { index, tab in
				HStack(spacing: 12) {
					_tabIcon(tab)
					VStack(alignment: .leading, spacing: 2) {
						HStack(spacing: 6) {
							Text(verbatim: tab.title)
							if tab.rawValue == _config.defaultTab {
								Text("Mặc định")
									.font(.caption2.weight(.semibold))
									.foregroundStyle(Color.accentColor)
									.padding(.horizontal, 6)
									.padding(.vertical, 2)
									.background(Capsule().fill(Color.accentColor.opacity(0.15)))
							}
						}
						Text(_subtitle(tab))
							.font(.footnote)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					Spacer()
					Menu {
						Button {
							var next = _config
							next.defaultTab = tab.rawValue
							_apply(next)
						} label: {
							Label("Đặt làm mặc định", systemImage: "star")
						}
						.disabled(tab.rawValue == _config.defaultTab)
						
						Button {
							_iconTab = tab
						} label: {
							Label("Tùy chỉnh biểu tượng", systemImage: "sparkles")
						}
						
						Divider()
						
						Button {
							_move(tab, by: -1)
						} label: {
							Label("Di chuyển lên", systemImage: "chevron.up")
						}
						.disabled(index == 0)
						
						Button {
							_move(tab, by: 1)
						} label: {
							Label("Di chuyển xuống", systemImage: "chevron.down")
						}
						.disabled(index == tabs.count - 1)
						
						Divider()
						
						// Tab Cài đặt luôn ở trên thanh để không mất lối vào màn hình này
						Button(role: .destructive) {
							_hide(tab)
						} label: {
							Label("Chuyển sang chưa thêm", systemImage: "minus.circle")
						}
						.disabled(tab == .settings)
					} label: {
						Image(systemName: "ellipsis.circle")
							.font(.title3)
							.foregroundStyle(Color.accentColor)
							.frame(width: 32, height: 32)
							.contentShape(Rectangle())
					}
				}
			}
		} header: {
			Text("Tab hiện tại")
		} footer: {
			if tabs.count > 5 {
				Text("iPhone chỉ hiện 5 tab trên thanh, các tab còn lại nằm trong mục Thêm.")
			}
		}
	}
	
	@ViewBuilder
	private func _hiddenSection() -> some View {
		let hidden = _config.hiddenTabs
		Section {
			if hidden.isEmpty {
				HStack(spacing: 12) {
					Image(systemName: "checkmark.circle.fill")
						.font(.title3)
						.foregroundStyle(.green)
						.frame(width: 26)
					Text("Không có tab chưa thêm")
						.foregroundStyle(.secondary)
				}
			} else {
				ForEach(hidden) { tab in
					HStack(spacing: 12) {
						_tabIcon(tab)
						VStack(alignment: .leading, spacing: 2) {
							Text(verbatim: tab.title)
							Text(_subtitle(tab))
								.font(.footnote)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
						Spacer()
						Menu {
							Button {
								_show(tab)
							} label: {
								Label("Thêm vào thanh điều hướng", systemImage: "plus.circle")
							}
							Button {
								_iconTab = tab
							} label: {
								Label("Tùy chỉnh biểu tượng", systemImage: "sparkles")
							}
						} label: {
							Image(systemName: "ellipsis.circle")
								.font(.title3)
								.foregroundStyle(Color.accentColor)
								.frame(width: 32, height: 32)
								.contentShape(Rectangle())
						}
					}
				}
			}
		} header: {
			Text("Chưa thêm")
		}
	}
	
	@ViewBuilder
	private func _resetSection() -> some View {
		Section {
			Button(role: .destructive) {
				_showReset = true
			} label: {
				Label("Khôi phục thanh điều hướng mặc định", systemImage: "arrow.uturn.backward")
			}
		}
	}
}

// MARK: - Actions & helpers
extension TabBarCustomizationView {
	private func _move(_ tab: TabEnum, by offset: Int) {
		var next = _config
		guard
			let from = next.visible.firstIndex(of: tab.rawValue),
			next.visible.indices.contains(from + offset)
		else { return }
		next.visible.swapAt(from, from + offset)
		_apply(next)
	}
	
	private func _hide(_ tab: TabEnum) {
		guard tab != .settings else { return }
		var next = _config
		next.visible.removeAll { $0 == tab.rawValue }
		_apply(next)   // sanitized() tự đổi tab mặc định nếu tab vừa ẩn là tab mặc định
	}
	
	private func _show(_ tab: TabEnum) {
		var next = _config
		guard !next.visible.contains(tab.rawValue) else { return }
		next.visible.append(tab.rawValue)
		_apply(next)
	}
	
	private func _icon(for tab: TabEnum) -> String {
		if let custom = _config.icons[tab.rawValue], UIImage(systemName: custom) != nil {
			return custom
		}
		return tab.defaultIcon
	}
	
	@ViewBuilder
	private func _tabIcon(_ tab: TabEnum) -> some View {
		Image(systemName: _icon(for: tab))
			.font(.title3)
			.foregroundStyle(Color.accentColor)
			.frame(width: 40, height: 40)
			.background(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(Color.accentColor.opacity(0.12))
			)
	}
	
	private func _subtitle(_ tab: TabEnum) -> LocalizedStringKey {
		switch tab {
		case .files:        return "Trình quản lý tệp"
		case .sources:      return "Nguồn và kho ứng dụng"
		case .library:      return "Ứng dụng đã nhập và đã ký"
		case .settings:     return "Cài đặt ứng dụng"
		case .certificates: return "Quản lý chứng chỉ"
		case .appstore:     return "Tìm và tải ứng dụng"
		case .downloader:   return "Danh sách tải xuống"
		}
	}
}

// MARK: - Chọn icon SF Symbol
struct TabIconPickerView: View {
	@Environment(\.dismiss) private var dismiss
	
	let tab: TabEnum
	let onSave: (String?) -> Void
	
	@State private var iconName: String
	
	private static let suggestions: [String] = [
		"folder.fill", "square.grid.2x2", "plus.app.fill", "square.and.arrow.down.fill", "gearshape.2",
		"gearshape.fill", "globe.desk", "person.text.rectangle", "star.fill", "heart.fill",
		"house.fill", "tray.full.fill", "shippingbox.fill", "bolt.fill", "arrow.down.circle.fill",
		"signature", "key.fill", "doc.fill", "archivebox.fill", "wrench.and.screwdriver.fill"
	]
	
	init(tab: TabEnum, current: String?, onSave: @escaping (String?) -> Void) {
		self.tab = tab
		self.onSave = onSave
		self._iconName = State(initialValue: current ?? tab.defaultIcon)
	}
	
	private var _trimmed: String { iconName.trimmingCharacters(in: .whitespacesAndNewlines) }
	private var _isValid: Bool { !_trimmed.isEmpty && UIImage(systemName: _trimmed) != nil }
	
	var body: some View {
		NavigationView {
			Form {
				Section {
					HStack(spacing: 14) {
						Image(systemName: _isValid ? _trimmed : "questionmark.square.dashed")
							.font(.system(size: 30))
							.foregroundStyle(_isValid ? Color.accentColor : Color.secondary)
							.frame(width: 56, height: 56)
							.background(
								RoundedRectangle(cornerRadius: 14, style: .continuous)
									.fill(Color.accentColor.opacity(0.12))
							)
						VStack(alignment: .leading, spacing: 2) {
							Text(verbatim: tab.title)
								.font(.headline)
							Text(verbatim: tab.defaultIcon)
								.font(.system(.footnote, design: .monospaced))
								.foregroundStyle(.secondary)
						}
					}
					TextField("Tên SF Symbol", text: $iconName)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
					if !_trimmed.isEmpty, !_isValid {
						Text("Không tìm thấy SF Symbol này.")
							.font(.footnote)
							.foregroundStyle(.red)
					}
				}
				
				Section {
					LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
						ForEach(Self.suggestions, id: \.self) { symbol in
							Button {
								iconName = symbol
							} label: {
								Image(systemName: symbol)
									.font(.title3)
									.frame(maxWidth: .infinity, minHeight: 44)
									.foregroundStyle(_trimmed == symbol ? Color.white : Color.accentColor)
									.background(
										RoundedRectangle(cornerRadius: 10, style: .continuous)
											.fill(_trimmed == symbol ? Color.accentColor : Color.accentColor.opacity(0.12))
									)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.vertical, 4)
				} header: {
					Text("Gợi ý")
				}
				
				Section {
					Button {
						onSave(nil)
						dismiss()
					} label: {
						Label("Dùng biểu tượng mặc định", systemImage: "arrow.uturn.backward")
					}
				}
			}
			.navigationTitle(Text("Tùy chỉnh biểu tượng"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Hủy") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Lưu") {
						onSave(_trimmed == tab.defaultIcon ? nil : _trimmed)
						dismiss()
					}
					.disabled(!_isValid)
				}
			}
		}
		.navigationViewStyle(.stack)
	}
}
