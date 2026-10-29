//
//  StorageCleanupView.swift
//  xSign (personal customization)
//
//  Dung lượng & Dọn dẹp (bố cục theo mẫu Zsign):
//  Tổng quan -> Chi tiết -> Dọn dẹp theo từng loại.
//

import SwiftUI
import NimbleViews
import Nuke

// MARK: - Cleanup kind
private enum CleanupKind: String, CaseIterable, Identifiable {
	case unsigned, signed, other, temp, network, archives, all

	var id: String { rawValue }

	/// Màu riêng của từng loại (hiện ở chấm màu và ở số dung lượng khi chọn).
	var color: Color {
		switch self {
		case .unsigned: return .green
		case .signed: return .yellow
		case .other: return .blue
		case .temp: return .red
		case .network: return .purple
		case .archives: return .brown
		case .all: return .orange
		}
	}

	var title: LocalizedStringKey {
		switch self {
		case .unsigned: return "App chưa ký"
		case .signed: return "App đã ký"
		case .other: return "Tệp khác"
		case .temp: return "Tệp tạm"
		case .network: return "Bộ nhớ đệm mạng"
		case .archives: return "Archives"
		case .all: return "Toàn bộ danh sách"
		}
	}

	var actionTitle: LocalizedStringKey {
		switch self {
		case .unsigned: return "Xoá mọi app đã nhập"
		case .signed: return "Xoá mọi app đã ký"
		case .other: return "Xoá tệp khác"
		case .temp: return "Xoá tệp tạm"
		case .network: return "Xoá bộ nhớ đệm mạng"
		case .archives: return "Xoá thư mục Archives"
		case .all: return "Xoá toàn bộ danh sách"
		}
	}

	var alertTitle: String {
		switch self {
		case .unsigned: return .localized("Xoá mọi app đã nhập")
		case .signed: return .localized("Xoá mọi app đã ký")
		case .other: return .localized("Xoá tệp khác")
		case .temp: return .localized("Xoá tệp tạm")
		case .network: return .localized("Xoá bộ nhớ đệm mạng")
		case .archives: return .localized("Xoá thư mục Archives")
		case .all: return .localized("Xoá toàn bộ danh sách")
		}
	}
}

// MARK: - View
struct StorageCleanupView: View {
	@State private var _sizes: [CleanupKind: Int64] = [:]
	@State private var _totalCapacity: Int64 = 0
	@State private var _freeCapacity: Int64 = 0
	@State private var _kind: CleanupKind = .unsigned
	@State private var _isLoading = true

	/// Kích thước của một loại. Riêng "Toàn bộ danh sách" là tổng các loại còn lại.
	private func _size(_ kind: CleanupKind) -> Int64 {
		if kind == .all {
			return CleanupKind.allCases
				.filter { $0 != .all }
				.reduce(0) { $0 + (_sizes[$1] ?? 0) }
		}
		return _sizes[kind] ?? 0
	}

	private var _appUsed: Int64 { _size(.all) }

	var body: some View {
		NBList(.localized("Dung lượng & Dọn dẹp")) {
			_overviewSection()
			_detailSection()
			_cleanupSection()
		}
		.onAppear { _reload() }
	}
}

// MARK: - Sections
extension StorageCleanupView {
	@ViewBuilder
	private func _overviewSection() -> some View {
		Section {
			VStack(spacing: 10) {
				ProgressView(value: _totalCapacity > 0 ? min(Double(_appUsed) / Double(_totalCapacity), 1) : 0)
					.tint(Color.accentColor)
				HStack {
					_stat("Đã dùng", _format(_appUsed), .primary)
					Spacer()
					_stat("Total", _format(_totalCapacity), .primary)
					Spacer()
					_stat("Còn trống", _format(_freeCapacity), .green)
				}
			}
			.padding(.vertical, 4)
		} header: {
			Text("Tổng quan dung lượng")
		} footer: {
			Text("Tổng dung lượng dữ liệu xSign đang dùng (không tính chứng chỉ).")
		}
	}

	@ViewBuilder
	private func _stat(_ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
		VStack(spacing: 2) {
			Text(title).font(.footnote).foregroundStyle(.secondary)
			Text(verbatim: value).font(.headline).foregroundStyle(color)
		}
	}

	@ViewBuilder
	private func _detailSection() -> some View {
		Section {
			_detailRow(.unsigned)
			_detailRow(.signed)
			_detailRow(.other)
			_detailRow(.temp)
			_detailRow(.network)
			_detailRow(.archives)
			HStack {
				Text("Tổng đã dùng").fontWeight(.semibold)
				Spacer()
				if _isLoading { ProgressView() } else { Text(verbatim: _format(_appUsed)).fontWeight(.semibold) }
			}
		} header: {
			Text("Chi tiết dung lượng")
		}
	}

	@ViewBuilder
	private func _detailRow(_ kind: CleanupKind) -> some View {
		HStack(spacing: 8) {
			Circle().fill(kind.color).frame(width: 9, height: 9)
			Text(kind.title)
			Spacer()
			Text(verbatim: _format(_size(kind))).foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private func _cleanupSection() -> some View {
		let hasData = _size(_kind) > 0

		Section {
			Picker(selection: $_kind) {
				ForEach(CleanupKind.allCases) { kind in
					Text(kind.title).tag(kind)
				}
			} label: {
				Label("Kiểu dọn dẹp", systemImage: "trash")
			}

			VStack(alignment: .leading, spacing: 6) {
				Text(_kind.actionTitle)
				Text(verbatim: _format(_size(_kind)))
					.font(.title2.weight(.semibold))
					.foregroundStyle(_kind.color)
			}

			// Nút luôn nằm giữa ô; chỉ đỏ khi có dữ liệu để xoá.
			Button {
				let kind = _kind
				ResetView.resetAlert(title: kind.alertTitle) {
					_clean(kind)
				}
			} label: {
				HStack(spacing: 8) {
					Image(systemName: "trash")
					Text("Dọn ngay")
				}
				.fontWeight(.semibold)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 6)
			}
			.buttonStyle(.borderedProminent)
			.tint(hasData ? .red : .gray)
			.disabled(!hasData)
		} header: {
			Text("Dọn dẹp dung lượng")
		} footer: {
			Text("Chứng chỉ sẽ không bao giờ bị xoá. Chỉ xoá tệp app và dữ liệu tạm.")
		}
	}
}

// MARK: - Logic
extension StorageCleanupView {
	private func _format(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		formatter.allowedUnits = [.useKB, .useMB, .useGB]
		formatter.allowsNonnumericFormatting = false
		return formatter.string(fromByteCount: bytes)
	}

	private func _clean(_ kind: CleanupKind) {
		if kind == .all {
			for item in CleanupKind.allCases where item != .all {
				Self.perform(item)
			}
		} else {
			Self.perform(kind)
		}
		// Cập nhật lại số liệu sau khi dọn.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { _reload() }
	}

	private static func perform(_ kind: CleanupKind) {
		let fm = FileManager.default
		switch kind {
		case .unsigned: removeContents(fm.unsigned)
		case .signed: removeContents(fm.signed)
		case .other: removeOtherFiles()
		case .temp: ResetView.clearWorkCache()
		case .network: ResetView.clearNetworkCache()
		case .archives: removeContents(fm.archives)
		case .all: break
		}
	}

	private func _reload() {
		_isLoading = true
		DispatchQueue.global(qos: .userInitiated).async {
			let fm = FileManager.default
			var networkSize = Int64(URLCache.shared.currentDiskUsage)
			if let nuke = ImagePipeline.shared.configuration.dataCache as? DataCache {
				networkSize += Int64(nuke.totalSize)
			}

			let unsigned = Self.folderSize(fm.unsigned)
			let signed = Self.folderSize(fm.signed)
			let archives = Self.folderSize(fm.archives)
			let other = Self.otherFilesSize()

			let values = try? URL.documentsDirectory.resourceValues(forKeys: [
				.volumeTotalCapacityKey,
				.volumeAvailableCapacityForImportantUsageKey
			])

			DispatchQueue.main.async {
				_sizes = [
					.unsigned: unsigned,
					.signed: signed,
					.other: other,
					.archives: archives,
					.temp: Self.folderSize(fm.temporaryDirectory),
					.network: networkSize
				]
				_totalCapacity = Int64(values?.volumeTotalCapacity ?? 0)
				_freeCapacity = values?.volumeAvailableCapacityForImportantUsage ?? 0
				_isLoading = false
			}
		}
	}

	// MARK: Tệp khác

	/// Các mục trong Documents KHÔNG được tính là "Tệp khác" (đã có loại riêng hoặc là chứng chỉ).
	private static func protectedNames() -> Set<String> {
		let fm = FileManager.default
		return Set([
			fm.unsigned.lastPathComponent,
			fm.signed.lastPathComponent,
			fm.archives.lastPathComponent,
			"Certificates",
			"certificates"
		])
	}

	private static func otherItems() -> [URL] {
		let protected = protectedNames()
		let items = (try? FileManager.default.contentsOfDirectory(
			at: URL.documentsDirectory,
			includingPropertiesForKeys: nil
		)) ?? []
		return items.filter { !protected.contains($0.lastPathComponent) }
	}

	private static func otherFilesSize() -> Int64 {
		otherItems().reduce(0) { $0 + folderSize($1) }
	}

	private static func removeOtherFiles() {
		for item in otherItems() { try? FileManager.default.removeItem(at: item) }
	}

	// MARK: Helpers

	private static func removeContents(_ url: URL) {
		let fm = FileManager.default
		guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
		for item in items { try? fm.removeItem(at: item) }
	}

	/// Kích thước của một file hoặc cả thư mục.
	private static func folderSize(_ url: URL) -> Int64 {
		let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]

		if let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
			return Int64(values.totalFileAllocatedSize ?? 0)
		}

		guard let enumerator = FileManager.default.enumerator(
			at: url,
			includingPropertiesForKeys: keys,
			options: [],
			errorHandler: nil
		) else { return 0 }

		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
				  values.isRegularFile == true else { continue }
			total += Int64(values.totalFileAllocatedSize ?? 0)
		}
		return total
	}
}
