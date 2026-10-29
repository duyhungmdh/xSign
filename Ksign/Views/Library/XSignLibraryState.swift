//
//  XSignLibraryState.swift
//  xSign v7
//
//  1) XSignLibraryState: cho biết tab Thư viện có đang hiện không, để ẩn thanh
//     tiến trình gốc của Ksign (DownloadHeaderView) khi đang ở Thư viện.
//  2) ImportedFileNames: nhớ tên tệp .ipa gốc của từng app đã nhập.
//

import SwiftUI
import CoreData

// MARK: - Trạng thái hiển thị tab Thư viện
final class XSignLibraryState: ObservableObject {
	static let shared = XSignLibraryState()
	
	/// true khi tab Thư viện đang hiện → ẩn thanh tiến trình gốc ở đầu app
	@Published var isLibraryVisible = false
	
	private init() {}
}

// MARK: - Tên tệp gốc của app đã nhập
/// Core Data của app gốc không có chỗ lưu tên tệp, nên xSign tự nhớ trong UserDefaults:
/// `uuid của app đã nhập` → `tên tệp .ipa`.
///
/// Cách ghép: khi một lượt nhập xong, `ImportProgressModel` báo tên tệp (lấy từ
/// `Download.fileName`); khi Core Data thêm một bản ghi `Imported` mới, ta ghi nhận uuid.
/// Hai danh sách chờ này được ghép theo thứ tự (FIFO), quá 60 giây thì bỏ.
final class ImportedFileNames: ObservableObject {
	static let shared = ImportedFileNames()
	
	@Published private(set) var names: [String: String]
	
	private let _key = "xsign.importedFileNames"
	private let _ttl: TimeInterval = 60
	private var _finishedFiles: [(name: String, date: Date)] = []
	private var _newApps: [(uuid: String, date: Date)] = []
	
	private init() {
		names = (UserDefaults.standard.dictionary(forKey: "xsign.importedFileNames") as? [String: String]) ?? [:]
		
		NotificationCenter.default.addObserver(
			forName: .NSManagedObjectContextDidSave,
			object: nil,
			queue: .main
		) { [weak self] note in
			guard let inserted = note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> else { return }
			for case let app as Imported in inserted {
				if let uuid = app.uuid { self?._appAdded(uuid) }
			}
		}
	}
	
	/// Tên tệp gốc của app đã nhập (nil nếu không biết, ví dụ app nhập từ bản cũ)
	func name(for uuid: String?) -> String? {
		guard let uuid, let n = names[uuid], !n.isEmpty else { return nil }
		return n
	}
	
	/// Gọi khi một lượt nhập/tải xong (Download biến mất khỏi danh sách đang chạy)
	func downloadFinished(fileName: String) {
		guard !fileName.isEmpty else { return }
		_finishedFiles.append((fileName, Date()))
		_pair()
	}
	
	private func _appAdded(_ uuid: String) {
		_newApps.append((uuid, Date()))
		_pair()
	}
	
	private func _pair() {
		let now = Date()
		_finishedFiles.removeAll { now.timeIntervalSince($0.date) > _ttl }
		_newApps.removeAll { now.timeIntervalSince($0.date) > _ttl }
		
		var changed = false
		while let file = _finishedFiles.first, let app = _newApps.first {
			_finishedFiles.removeFirst()
			_newApps.removeFirst()
			names[app.uuid] = file.name
			changed = true
		}
		if changed {
			UserDefaults.standard.set(names, forKey: _key)
		}
	}
}
