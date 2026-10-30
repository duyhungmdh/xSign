//
//  StorageCleanupView.swift
//  xSign (personal customization)
//
//  Dung lượng & Dọn dẹp (bố cục theo mẫu Zsign):
//  Tổng quan -> Chi tiết -> Dọn dẹp theo từng loại.
//
//  Bản sửa so với v1.9.0:
//  1. Bấm "Dọn ngay" KHÔNG còn thoát / mở lại app (trước đây gọi ResetView.resetAlert
//     -> UIApplication.suspendAndReopen() -> exit(0)).
//  2. "Tệp khác" không còn tính / xoá nhầm cả thư mục App (Unsigned, Signed, Archives, Server...).
//     Tổng "Đã dùng" không còn bị cộng đôi.
//  3. Dọn "App chưa ký" / "App đã ký" xoá luôn bản ghi Core Data -> không còn app "ma" trong Thư viện.
//  4. Đo dung lượng và xoá file chạy ở luồng nền (song song khi đo), giao diện không bị đơ.
//  5. Chặn dọn khi đang tải / giải nén; tạo lại thư mục App/* sau khi dọn.
//  6. Dùng cảnh báo SwiftUI thay cho UIAlertController(topViewController()!), có thông báo kết quả.
//

import SwiftUI
import CoreData
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

	/// Ghi chú thêm trong hộp thoại xác nhận.
	var note: String? {
		switch self {
		case .unsigned: return "Gồm cả danh sách app đã nhập trong Thư viện."
		case .signed: return "Gồm cả danh sách app đã ký trong Thư viện."
		case .other: return "Gồm thư mục Downloads, Tweaks và các tệp lẻ. Không đụng tới app, chứng chỉ, pairingFile và chứng chỉ máy chủ."
		case .network: return "Chỉ xoá ảnh và dữ liệu đệm đã tải về."
		case .all: return "Chứng chỉ và cài đặt được giữ nguyên."
		default: return nil
		}
	}
}

// MARK: - Alert content
private enum CleanupAlert {
	case confirm(CleanupKind)
	case info(title: String, message: String)
}

// MARK: - View
struct StorageCleanupView: View {
	@State private var _sizes: [CleanupKind: Int64] = [:]
	@State private var _totalCapacity: Int64 = 0
	@State private var _freeCapacity: Int64 = 0
	@State private var _kind: CleanupKind = .unsigned
	@State private var _isLoading = true
	@State private var _isCleaning = false

	// Giữ nội dung cảnh báo lại sau khi đóng để chữ không bị trống trong lúc hiệu ứng tắt.
	@State private var _showAlert = false
	@State private var _alertContent: CleanupAlert = .info(title: "", message: "")

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

	/// Đang tải IPA hoặc giải nén -> thư mục app và tệp tạm đang được dùng.
	private var _hasActiveJobs: Bool {
		!DownloadManager.shared.downloads.isEmpty || !ExtractManager.shared.extractItems.isEmpty
	}

	var body: some View {
		NBList(.localized("Dung lượng & Dọn dẹp")) {
			_overviewSection()
			_detailSection()
			_cleanupSection()
		}
		.onAppear { _reload() }
		.alert(_alertTitle, isPresented: $_showAlert) {
			_alertActions()
		} message: {
			Text(verbatim: _alertMessage)
		}
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
			.disabled(_isCleaning)

			VStack(alignment: .leading, spacing: 6) {
				Text(_kind.actionTitle)
				Text(verbatim: _format(_size(_kind)))
					.font(.title2.weight(.semibold))
					.foregroundStyle(_kind.color)
			}

			// Nút luôn nằm giữa ô; chỉ đỏ khi có dữ liệu để xoá.
			Button {
				_alertContent = .confirm(_kind)
				_showAlert = true
			} label: {
				HStack(spacing: 8) {
					if _isCleaning {
						ProgressView().tint(.white)
						Text("Đang dọn…")
					} else {
						Image(systemName: "trash")
						Text("Dọn ngay")
					}
				}
				.fontWeight(.semibold)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 6)
			}
			.buttonStyle(.borderedProminent)
			.tint(hasData ? .red : .gray)
			.disabled(!hasData || _isCleaning)
		} header: {
			Text("Dọn dẹp dung lượng")
		} footer: {
			Text("Chứng chỉ sẽ không bao giờ bị xoá. Chỉ xoá tệp app và dữ liệu tạm.")
		}
	}
}

// MARK: - Alert
extension StorageCleanupView {
	private var _alertTitle: String {
		switch _alertContent {
		case .confirm(let kind): return kind.alertTitle
		case .info(let title, _): return title
		}
	}

	private var _alertMessage: String {
		switch _alertContent {
		case .confirm(let kind): return _confirmMessage(kind)
		case .info(_, let message): return message
		}
	}

	@ViewBuilder
	private func _alertActions() -> some View {
		switch _alertContent {
		case .confirm(let kind):
			Button("Dọn ngay", role: .destructive) { _runCleanup(kind) }
			Button("Cancel", role: .cancel) { }
		case .info:
			Button("OK", role: .cancel) { }
		}
	}

	private func _confirmMessage(_ kind: CleanupKind) -> String {
		var text = "Sẽ giải phóng khoảng \(_format(_size(kind))). Thao tác này không thể hoàn tác."
		if let note = kind.note { text += "\n" + note }
		return text
	}

	/// Hiện thông báo sau một nhịp ngắn để hộp thoại trước kịp đóng (iOS bỏ qua alert mở chồng lúc đang đóng).
	private func _presentInfo(title: String, message: String) {
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 350_000_000)
			_alertContent = .info(title: title, message: message)
			_showAlert = true
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

	private func _apply(_ snapshot: StorageSnapshot) {
		_sizes = snapshot.sizes
		_totalCapacity = snapshot.total
		_freeCapacity = snapshot.free
		_isLoading = false
	}

	/// Đo lại toàn bộ ở luồng nền (các loại đo song song), rồi cập nhật giao diện một lần.
	private func _reload() {
		_isLoading = true
		Task { @MainActor in
			let snapshot = await Task.detached(priority: .userInitiated) {
				await StorageCleaner.measureAll()
			}.value
			_apply(snapshot)
		}
	}

	private func _runCleanup(_ kind: CleanupKind) {
		guard !_isCleaning else { return }

		// Đang tải / giải nén thì không dọn (tệp tạm và thư mục app đang được dùng).
		if kind != .network, _hasActiveJobs {
			_presentInfo(
				title: "Đang có tác vụ chạy",
				message: "Xoá ngay lúc này có thể làm hỏng lượt tải hoặc giải nén đang chạy. Hãy chờ xong rồi dọn lại."
			)
			return
		}

		let kinds: [CleanupKind] = kind == .all
			? CleanupKind.allCases.filter { $0 != .all }
			: [kind]
		let usedBefore = _appUsed

		_isCleaning = true
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()

		Task { @MainActor in
			// 1) Xoá bản ghi Core Data trước: danh sách Thư viện cập nhật ngay, không còn app "ma".
			if kinds.contains(.unsigned) { StorageCleaner.deleteRecords(Imported.fetchRequest()) }
			if kinds.contains(.signed) { StorageCleaner.deleteRecords(Signed.fetchRequest()) }

			// 2) Xoá file ở luồng nền để giao diện không bị đơ.
			await Task.detached(priority: .utility) {
				StorageCleaner.removeFiles(for: kinds)
			}.value

			// 3) Đo lại và báo kết quả.
			let snapshot = await Task.detached(priority: .userInitiated) {
				await StorageCleaner.measureAll()
			}.value
			_apply(snapshot)
			_isCleaning = false

			UINotificationFeedbackGenerator().notificationOccurred(.success)
			let freed = max(usedBefore - snapshot.used, 0)
			_presentInfo(
				title: "Đã dọn xong",
				message: "Đã giải phóng \(_format(freed))."
			)
		}
	}
}

// MARK: - Storage worker (không phụ thuộc giao diện, chạy được ở luồng nền)
private struct StorageSnapshot {
	var sizes: [CleanupKind: Int64]
	var total: Int64
	var free: Int64

	var used: Int64 { sizes.values.reduce(0, +) }
}

private enum StorageCleaner {
	/// Mục ở gốc Documents KHÔNG được tính / xoá là "Tệp khác".
	/// "App" chứa Unsigned/Signed/Archives/Server/Tweaks nên được xử lý riêng bên dưới.
	private static let documentsKeep: Set<String> = ["App", "Certificates", "Server", "pairingFile.plist"]

	/// Mục trong Documents/App KHÔNG được tính / xoá là "Tệp khác" (đã có loại riêng hoặc cần cho máy chủ cài đặt).
	private static let appFolderKeep: Set<String> = ["Unsigned", "Signed", "Archives", "Server"]

	/// Giống `_createSourcesDirectory()` trong FeatherApp.swift.
	private static let appFolders = ["Signed", "Unsigned", "Archives", "Server", "Tweaks"]

	// MARK: Đo

	static func measure(_ kind: CleanupKind) -> Int64 {
		let fm = FileManager.default
		switch kind {
		case .unsigned: return folderSize(fm.unsigned)
		case .signed: return folderSize(fm.signed)
		case .archives: return folderSize(fm.archives)
		case .other: return otherItems().reduce(0) { $0 + folderSize($1) }
		case .temp: return folderSize(fm.temporaryDirectory)
		case .network: return networkCacheSize()
		case .all: return 0
		}
	}

	static func measureAll() async -> StorageSnapshot {
		let kinds = CleanupKind.allCases.filter { $0 != .all }

		let sizes = await withTaskGroup(of: (CleanupKind, Int64).self) { group -> [CleanupKind: Int64] in
			for kind in kinds {
				group.addTask(priority: .userInitiated) {
					(kind, StorageCleaner.measure(kind))
				}
			}
			var result: [CleanupKind: Int64] = [:]
			for await (kind, size) in group { result[kind] = size }
			return result
		}

		let values = try? URL.documentsDirectory.resourceValues(forKeys: [
			.volumeTotalCapacityKey,
			.volumeAvailableCapacityForImportantUsageKey
		])

		return StorageSnapshot(
			sizes: sizes,
			total: Int64(values?.volumeTotalCapacity ?? 0),
			free: values?.volumeAvailableCapacityForImportantUsage ?? 0
		)
	}

	private static func networkCacheSize() -> Int64 {
		var total = Int64(URLCache.shared.currentDiskUsage)
		if let nuke = ImagePipeline.shared.configuration.dataCache as? DataCache {
			total += Int64(nuke.totalSize)
		}
		return total
	}

	// MARK: Xoá

	/// Xoá bản ghi Core Data (phải gọi ở luồng chính vì dùng viewContext).
	@MainActor
	static func deleteRecords<T: NSManagedObject>(_ request: NSFetchRequest<T>) {
		let context = Storage.shared.context
		guard let objects = try? context.fetch(request) else { return }
		for object in objects { context.delete(object) }
		if context.hasChanges { try? context.save() }
	}

	/// Xoá file theo từng loại. KHÔNG đụng tới chứng chỉ, và không bao giờ thoát app.
	static func removeFiles(for kinds: [CleanupKind]) {
		let fm = FileManager.default

		for kind in kinds {
			switch kind {
			case .unsigned: removeContents(of: fm.unsigned)
			case .signed: removeContents(of: fm.signed)
			case .archives: removeContents(of: fm.archives)
			case .other: for item in otherItems() { try? fm.removeItem(at: item) }
			case .temp: removeContents(of: fm.temporaryDirectory)
			case .network: clearNetworkCaches()
			case .all: break
			}
		}

		// Trước đây app tự khởi động lại nên thư mục được tạo lại ở lần mở sau.
		// Giờ app không thoát nữa, nên đảm bảo cấu trúc thư mục còn nguyên ngay lập tức.
		ensureAppFolders()
	}

	private static func clearNetworkCaches() {
		URLCache.shared.removeAllCachedResponses()

		if let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			dataCache.removeAll()
		}
		if let imageCache = ImagePipeline.shared.configuration.imageCache as? Nuke.ImageCache {
			imageCache.removeAll()
		}
	}

	private static func ensureAppFolders() {
		let fm = FileManager.default
		let appDirectory = URL.documentsDirectory.appendingPathComponent("App")
		for name in appFolders {
			try? fm.createDirectoryIfNeeded(at: appDirectory.appendingPathComponent(name))
		}
	}

	// MARK: Tệp khác

	/// Tệp khác = các mục lẻ ở gốc Documents (vd. Downloads, Inbox) + các mục trong App/ không thuộc loại riêng (vd. Tweaks).
	private static func otherItems() -> [URL] {
		let fm = FileManager.default
		let documents = URL.documentsDirectory
		var items: [URL] = []

		let rootItems = (try? fm.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
		items += rootItems.filter { !documentsKeep.contains($0.lastPathComponent) }

		let appItems = (try? fm.contentsOfDirectory(
			at: documents.appendingPathComponent("App"),
			includingPropertiesForKeys: nil
		)) ?? []
		items += appItems.filter { !appFolderKeep.contains($0.lastPathComponent) }

		return items
	}

	// MARK: Helpers

	private static func removeContents(of url: URL) {
		let fm = FileManager.default
		guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
		for item in items { try? fm.removeItem(at: item) }
	}

	/// Kích thước (theo dung lượng thực chiếm trên đĩa) của một file hoặc cả thư mục.
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
