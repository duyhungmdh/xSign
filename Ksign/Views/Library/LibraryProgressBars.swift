//
//  LibraryProgressBars.swift
//  xSign v7
//
//  Thanh tiến trình dẹt (4 pt, bo tròn 2 đầu) cho tab Thư viện:
//  - Ứng dụng tải về: tiến trình thêm/giải nén tệp (1 tệp hoặc nhiều tệp)
//  - Ứng dụng đã ký: tiến trình cài đặt theo 4 chặng
//    (Đóng gói → Gửi dữ liệu → Đang cài → Xong)
//

import SwiftUI
import Combine
import IDeviceSwift

// MARK: - Khoảng cách & màu dùng chung (v7)
enum XSignBarLayout {
	/// Khoảng cách thanh → bộ chọn 2 tab. Bộ chọn đã có sẵn 8 pt bên dưới, nên thêm 8 pt = 16 pt.
	static let gapTop: CGFloat = 8
	/// Khoảng cách thanh → dòng tiêu đề danh sách. Chỉnh số này nếu thấy lệch so với 16 pt trong phác thảo.
	static let gapBottom: CGFloat = 8
}

/// Màu 4 chặng cài đặt: Đóng gói = màu giao diện (be), Gửi dữ liệu = xanh dương, Đang cài = vàng, Xong = xanh lá
enum XSignStageColor {
	static let blue = Color(red: 0.25, green: 0.52, blue: 1.0)
	static let yellow = Color(red: 1.0, green: 0.80, blue: 0.0)
	
	/// `index` tính từ 0
	static func color(_ index: Int) -> Color {
		switch index {
		case 0: return .accentColor
		case 1: return blue
		case 2: return yellow
		default: return .green
		}
	}
}

// MARK: - Thanh dẹt dùng chung
struct XSignThinBar: View {
	var fraction: Double
	var color: Color
	
	var body: some View {
		GeometryReader { geo in
			ZStack(alignment: .leading) {
				Capsule().fill(Color(UIColor.systemFill))
				Capsule()
					.fill(color)
					.frame(width: geo.size.width * CGFloat(min(1, max(0, fraction))))
			}
		}
		.frame(height: 4)
		.animation(.easeOut(duration: 0.2), value: fraction)
	}
}

// MARK: - Model: tiến trình thêm tệp (tab Ứng dụng tải về)
/// Theo dõi `DownloadManager.shared.downloads` (cả nhập từ Tệp, từ URL, từ Nguồn).
/// Gom các tệp đang chạy thành 1 "lô": số tệp xong / tổng + % chung.
final class ImportProgressModel: ObservableObject {
	static let shared = ImportProgressModel()
	
	enum Phase { case idle, running, done }
	
	@Published private(set) var phase: Phase = .idle
	@Published private(set) var fraction: Double = 0
	@Published private(set) var finished: Int = 0
	@Published private(set) var total: Int = 0
	@Published private(set) var currentName: String = ""
	
	private var _seen = Set<String>()
	private var _activeNames: [String: String] = [:] // id lượt tải → tên tệp (để ghi nhớ tên gốc)
	private var _hideWork: DispatchWorkItem?
	private var _timer: AnyCancellable?
	
	private init() {
		// `Download.progress` là thuộc tính lồng nhau nên không tự báo thay đổi
		// lên mảng `downloads`; đọc lại 5 lần/giây là đủ mượt và rất nhẹ.
		_timer = Timer.publish(every: 0.2, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in self?._tick() }
	}
	
	private func _tick() {
		let active = DownloadManager.shared.downloads
		
		// v7: tệp nào vừa biến mất khỏi danh sách đang chạy = đã nhập xong → nhớ tên tệp gốc
		let activeIDs = Set(active.map { $0.id })
		for (id, name) in _activeNames where !activeIDs.contains(id) {
			ImportedFileNames.shared.downloadFinished(fileName: name)
			_activeNames[id] = nil
		}
		for d in active { _activeNames[d.id] = d.fileName }
		
		if active.isEmpty {
			if phase == .running { _finishBatch() }
			return
		}
		
		_hideWork?.cancel()
		_hideWork = nil
		
		// Bắt đầu lô mới (lần đầu, hoặc sau khi lô trước đã hoàn tất)
		if phase != .running {
			_seen.removeAll()
			total = 0
			finished = 0
			fraction = 0
			phase = .running
		}
		
		for d in active where !_seen.contains(d.id) {
			_seen.insert(d.id)
			total += 1
		}
		
		let done = max(0, total - active.count)
		let partial = active.reduce(0.0) { $0 + $1.overallProgress }
		let value = total > 0 ? (Double(done) + partial) / Double(total) : 0
		
		if done != finished { finished = done }
		if let name = active.first?.fileName, name != currentName { currentName = name }
		// Không cho thanh lùi lại khi có thêm tệp vào giữa chừng
		let next = min(1, max(fraction, value))
		if abs(next - fraction) >= 0.005 { fraction = next }
	}
	
	private func _finishBatch() {
		finished = total
		fraction = 1
		phase = .done
		
		let work = DispatchWorkItem { [weak self] in
			guard let self else { return }
			self.phase = .idle
			self.total = 0
			self.finished = 0
			self.fraction = 0
			self._seen.removeAll()
		}
		_hideWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
	}
}

// MARK: - View: tab Ứng dụng tải về
struct ImportProgressBar: View {
	@ObservedObject private var _model = ImportProgressModel.shared
	
	var body: some View {
		Group {
			if _model.phase != .idle {
				let isDone = _model.phase == .done
				let tint: Color = isDone ? .green : .accentColor
				
				VStack(spacing: 4) {
					HStack(spacing: 6) {
						_label(isDone: isDone, tint: tint)
							.lineLimit(1)
							.truncationMode(.middle)
						Spacer(minLength: 8)
						Text("\(Int((_model.fraction * 100).rounded()))%")
							.monospacedDigit()
							.foregroundStyle(tint)
					}
					.font(.caption2)
					.foregroundStyle(isDone ? AnyShapeStyle(Color.green) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
					
					XSignThinBar(fraction: _model.fraction, color: tint)
				}
				.padding(.horizontal)
				.padding(.top, XSignBarLayout.gapTop)
				.padding(.bottom, XSignBarLayout.gapBottom)
				.transition(.opacity.combined(with: .move(edge: .top)))
				.accessibilityElement(children: .combine)
				.accessibilityValue(Text("\(Int((_model.fraction * 100).rounded()))%"))
			}
		}
		.animation(.easeInOut(duration: 0.25), value: _model.phase)
	}
	
	private func _label(isDone: Bool, tint: Color) -> Text {
		let multiple = _model.total > 1
		if isDone {
			let head = Text(verbatim: String.localized("Completed") + " · ")
			return multiple
			? head + Text(verbatim: "\(_model.total)/\(_model.total) " + String.localized("files"))
			: head + Text(verbatim: _model.currentName)
		}
		let adding = Text(verbatim: String.localized("Adding") + " ")
		if multiple {
			return adding
			+ Text(verbatim: "\(_model.finished)/\(_model.total)").foregroundColor(tint)
			+ Text(verbatim: " " + String.localized("files") + " · " + _model.currentName)
		}
		return adding + Text(verbatim: "· " + _model.currentName)
	}
}

// MARK: - Model: tiến trình cài đặt (tab Ứng dụng đã ký)
/// 4 chặng: 1 Đóng gói · 2 Gửi dữ liệu · 3 Đang cài · 4 Xong.
/// `InstallPreviewView` đẩy trạng thái vào đây; `InstallProgressBar` chỉ hiển thị.
final class InstallProgressCenter: ObservableObject {
	static let shared = InstallProgressCenter()
	
	enum Phase { case idle, running, done, failed }
	
	@Published private(set) var phase: Phase = .idle
	@Published private(set) var appName: String = ""
	@Published private(set) var stage: Int = 1            // 1...3 khi đang chạy
	@Published private(set) var stageFraction: Double = 0 // 0...1 trong chặng hiện tại
	/// v7: hộp thoại cài đặt đang mở → thanh sau lưng danh sách không hiện (tránh hiện 2 chỗ)
	@Published private(set) var sheetOpen: Bool = false
	
	static let stageCount = 4
	private var _hideWork: DispatchWorkItem?
	
	private init() {}
	
	/// Tổng % (mỗi chặng chiếm 1/4)
	var overall: Double {
		phase == .done ? 1 : (Double(stage - 1) + stageFraction) / Double(Self.stageCount)
	}
	
	func segmentFraction(_ index: Int) -> Double {
		if phase == .done { return 1 }
		let n = index + 1
		if n < stage { return 1 }
		if n == stage { return stageFraction }
		return 0
	}
	
	// MARK: Điều khiển
	func begin(appName: String) {
		_hideWork?.cancel()
		_hideWork = nil
		self.appName = appName
		stage = 1
		stageFraction = 0
		phase = .running
		sheetOpen = true
	}
	
	func sync(_ vm: InstallerStatusViewModel) {
		guard phase == .running else { return }
		
		switch vm.status {
		case .none:            _set(1, Double(vm.packageProgress))
		case .ready:           _set(2, 0.15)
		case .sendingManifest: _set(2, 0.5)
		case .sendingPayload:  _set(2, 0.85)
		case .installing:      _set(3, Double(vm.installProgress))
		case .completed:       complete()
		case .broken:          fail()
		}
	}
	
	func complete() {
		guard phase == .running else { return }
		phase = .done
		stage = Self.stageCount
		stageFraction = 1
		let work = DispatchWorkItem { [weak self] in self?.dismiss() }
		_hideWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
	}
	
	func fail() {
		guard phase == .running else { return }
		phase = .failed
	}
	
	func dismiss() {
		_hideWork?.cancel()
		_hideWork = nil
		phase = .idle
		stage = 1
		stageFraction = 0
	}
	
	/// Gọi khi bảng cài đặt đóng: nếu đang dở dang thì ẩn thanh (tránh đứng im).
	/// Đang cài dở thì ẩn thanh (như v6); đã xong / lỗi thì thanh hiện lại ở danh sách.
	func sheetClosed() {
		sheetOpen = false
		if phase == .running { dismiss() }
	}
	
	private func _set(_ newStage: Int, _ fraction: Double) {
		let f = min(1, max(0, fraction))
		guard newStage >= stage else { return } // chặng không lùi
		if newStage != stage {
			stage = newStage
			stageFraction = f
		} else if abs(f - stageFraction) >= 0.005 || f == 0 || f == 1 {
			stageFraction = f
		}
	}
}

// MARK: - View: tab Ứng dụng đã ký
struct InstallProgressBar: View {
	@ObservedObject private var _center = InstallProgressCenter.shared
	
	private var _steps: [String] {
		[
			String.localized("Packaging"),
			String.localized("Sending data"),
			String.localized("Installing"),
			String.localized("Done")
		]
	}
	
	var body: some View {
		Group {
			if _center.phase != .idle && !_center.sheetOpen {
				let isDone = _center.phase == .done
				let isFailed = _center.phase == .failed
				let tint: Color = isDone ? .green : XSignStageColor.color(_center.stage - 1)
				
				VStack(spacing: 4) {
					HStack(spacing: 6) {
						Text(verbatim: _title(isDone: isDone, isFailed: isFailed))
							.lineLimit(1)
							.truncationMode(.middle)
						Spacer(minLength: 8)
						if isFailed {
							Button {
								_center.dismiss()
							} label: {
								Image(systemName: "xmark.circle.fill")
							}
							.buttonStyle(.plain)
						} else {
							Text("\(Int((_center.overall * 100).rounded()))%")
								.monospacedDigit()
								.foregroundStyle(tint)
						}
					}
					.font(.caption2)
					.foregroundStyle(
						isDone ? AnyShapeStyle(Color.green)
						: isFailed ? AnyShapeStyle(Color.red)
						: AnyShapeStyle(HierarchicalShapeStyle.secondary)
					)
					
					HStack(spacing: 4) {
						ForEach(0..<InstallProgressCenter.stageCount, id: \.self) { i in
							XSignThinBar(
								fraction: _center.segmentFraction(i),
								color: (isFailed && i + 1 == _center.stage) ? .red : XSignStageColor.color(i)
							)
						}
					}
					
					if !isDone {
						HStack(spacing: 4) {
							ForEach(0..<InstallProgressCenter.stageCount, id: \.self) { i in
								Text(verbatim: _steps[i])
									.font(.system(size: 9.5, weight: i + 1 == _center.stage ? .semibold : .regular))
									.foregroundStyle(_stepStyle(i, isFailed: isFailed))
									.frame(maxWidth: .infinity)
									.lineLimit(1)
									.minimumScaleFactor(0.7)
							}
						}
					}
				}
				.padding(.horizontal)
				.padding(.top, XSignBarLayout.gapTop)
				.padding(.bottom, XSignBarLayout.gapBottom)
				.transition(.opacity.combined(with: .move(edge: .top)))
				.accessibilityElement(children: .combine)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: _center.phase)
		.animation(.easeInOut(duration: 0.25), value: _center.sheetOpen)
	}
	
	private func _title(isDone: Bool, isFailed: Bool) -> String {
		let step = _steps[min(max(_center.stage, 1), 4) - 1]
		if isDone {
			return String.localized("Completed") + " · " + _center.appName
		}
		let counter = "\(_center.stage)/\(InstallProgressCenter.stageCount)"
		if isFailed {
			return String.localized("Error") + " · " + counter + " · " + step
		}
		return String.localized("Install") + " \(counter) · " + step + " · " + _center.appName
	}
	
	private func _stepStyle(_ index: Int, isFailed: Bool) -> AnyShapeStyle {
		let n = index + 1
		if n == _center.stage {
			return isFailed ? AnyShapeStyle(Color.red) : AnyShapeStyle(XSignStageColor.color(index))
		}
		return n < _center.stage ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(HierarchicalShapeStyle.tertiary)
	}
}

// MARK: - Nền hộp thoại (v7.2): đậm hơn trắng một chút ở chế độ Sáng
enum XSignSheetBG {
	static let color = Color(UIColor { t in
		t.userInterfaceStyle == .dark
		? UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
		: UIColor(red: 0.925, green: 0.925, blue: 0.94, alpha: 1)
	})
}

extension View {
	/// Đổi nền hộp thoại (iOS 16.4+); bản thấp hơn dùng nền của nội dung.
	@ViewBuilder
	func xsignSheetBackground() -> some View {
		if #available(iOS 16.4, *) {
			self.presentationBackground(XSignSheetBG.color)
		} else {
			self
		}
	}
}

// MARK: - Khối tiến trình 4 chặng dùng chung (cài đặt + ký)
struct XSignStageProgress: View {
	let steps: [String]
	let stage: Int          // 1...4
	let overall: Double     // 0...1
	let segment: (Int) -> Double
	let isDone: Bool
	let isFailed: Bool
	
	private var _index: Int { min(max(stage, 1), steps.count) - 1 }
	private var _percent: Int { Int((overall * 100).rounded()) }
	private var _tint: Color {
		if isFailed { return .red }
		if isDone { return .green }
		return XSignStageColor.color(_index)
	}
	
	var body: some View {
		VStack(spacing: 8) {
			HStack(spacing: 6) {
				_titleText.lineLimit(1).truncationMode(.tail)
				Spacer(minLength: 8)
				Text(verbatim: "\(_percent)%")
					.monospacedDigit()
					.fontWeight(.semibold)
					.foregroundStyle(_tint)
			}
			.font(.subheadline)
			
			HStack(spacing: 4) {
				ForEach(0..<steps.count, id: \.self) { i in
					XSignThinBar(
						fraction: segment(i),
						color: (isFailed && i == _index) ? .red : XSignStageColor.color(i)
					)
				}
			}
			
			HStack(spacing: 4) {
				ForEach(0..<steps.count, id: \.self) { i in
					Text(verbatim: steps[i])
						.font(.system(size: 12, weight: i == _index ? .semibold : .regular))
						.foregroundStyle(i == _index ? AnyShapeStyle(HierarchicalShapeStyle.primary) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
						.frame(maxWidth: .infinity)
						.lineLimit(1)
						.minimumScaleFactor(0.7)
				}
			}
		}
		.accessibilityElement(children: .combine)
	}
	
	/// "Bước **3/4** · Đang cài"  |  "Hoàn tất"  |  "Lỗi · Bước 2/4 · Gửi dữ liệu"
	private var _titleText: Text {
		let counter = "\(stage)/\(steps.count)"
		let step = steps[_index]
		if isDone {
			return Text(verbatim: String.localized("Completed")).fontWeight(.semibold).foregroundColor(.green)
		}
		if isFailed {
			return Text(verbatim: String.localized("Error") + " · " + String.localized("Step") + " " + counter + " · " + step)
				.foregroundColor(.red)
		}
		return Text(verbatim: String.localized("Step") + " ")
			+ Text(verbatim: counter).fontWeight(.bold)
			+ Text(verbatim: " · " + step)
	}
}

// MARK: - Phần đầu hộp thoại: icon + tên + (tuỳ chọn) dòng chứng chỉ
struct XSignSheetHeader: View {
	let app: AppInfoPresentable
	var certificateName: String? = nil
	
	/// "Nhãn: giá trị" — nhãn xám, giá trị đậm (giá trị có thể tô màu riêng)
	@ViewBuilder
	private func _line(_ label: String, _ value: String, valueColor: Color? = nil) -> some View {
		(Text(verbatim: label + ": ").foregroundColor(.secondary)
		 + Text(verbatim: value).foregroundColor(valueColor ?? .primary))
			.font(.footnote)
			.lineLimit(1)
			.truncationMode(.middle)
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: 14) {
			FRAppIconView(app: app, size: 50)
			VStack(alignment: .leading, spacing: 2) {
				Text(app.name ?? .localized("Unknown"))
					.font(.title3.weight(.bold))
					.lineLimit(1)
				if let version = app.version {
					_line(String.localized("Version"), version)
				}
				if let id = app.identifier {
					_line("Bundle ID", id)
				}
				if let certificateName, !certificateName.isEmpty {
					_line(String.localized("Certificate"), certificateName, valueColor: Color.xsignAction)
				}
			}
			Spacer(minLength: 0)
		}
	}
}

// MARK: - Nội dung hộp thoại cài đặt (v7)
struct InstallSheetContent: View {
	let app: AppInfoPresentable
	@ObservedObject private var _center = InstallProgressCenter.shared
	
	/// Chứng chỉ đã dùng để ký app này (hiện ở dòng "Chứng chỉ:")
	private var _certificateName: String? {
		guard let cert = Storage.shared.getCertificate(from: app) else { return nil }
		return cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name
	}
	
	private var _steps: [String] {
		[String.localized("Packaging"), String.localized("Sending data"), String.localized("Installing"), String.localized("Done")]
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			XSignSheetHeader(app: app, certificateName: _certificateName)
			XSignStageProgress(
				steps: _steps,
				stage: _center.stage,
				overall: _center.overall,
				segment: { _center.segmentFraction($0) },
				isDone: _center.phase == .done,
				isFailed: _center.phase == .failed
			)
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.background(XSignSheetBG.color.ignoresSafeArea())
	}
}

// MARK: - Tiến trình ký (v7.2)
/// 4 chặng: 1 Chuẩn bị · 2 Đang ký · 3 Đóng gói · 4 Xong.
/// Màn hình ký gọi `begin` khi bấm "Bắt đầu ký", `update` khi tiến độ đổi, `complete`/`fail` khi kết thúc.
final class SigningProgressCenter: ObservableObject {
	static let shared = SigningProgressCenter()
	
	enum Phase { case idle, running, done, failed }
	
	@Published private(set) var phase: Phase = .idle
	@Published private(set) var stage: Int = 1
	@Published private(set) var stageFraction: Double = 0
	@Published private(set) var certificateName: String = ""
	@Published private(set) var app: AppInfoPresentable?
	
	static let stageCount = 4
	private var _hideWork: DispatchWorkItem?
	private var _creepTimer: Timer?
	/// Việc chạy sau khi hộp thoại đóng (vd. xoá app gốc, để hộp thoại không đọc app đã xoá)
	private var _afterDismiss: (() -> Void)?
	private init() {}
	
	var overall: Double {
		phase == .done ? 1 : (Double(stage - 1) + stageFraction) / Double(Self.stageCount)
	}
	
	func segmentFraction(_ index: Int) -> Double {
		if phase == .done { return 1 }
		let n = index + 1
		if n < stage { return 1 }
		if n == stage { return stageFraction }
		return 0
	}
	
	/// Có thể gọi từ luồng nền: mọi thay đổi được chuyển về luồng chính, đúng thứ tự gọi
	private func _main(_ block: @escaping () -> Void) {
		if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
	}
	
	func begin(app: AppInfoPresentable, certificateName: String) {
		_main { [self] in
			_hideWork?.cancel(); _hideWork = nil
			_afterDismiss = nil
			self.app = app
			self.certificateName = certificateName
			stage = 1
			stageFraction = 0
			phase = .running
			_startCreep()
		}
	}
	
	func update(stage newStage: Int, fraction: Double) {
		_main { [self] in
			guard phase == .running, newStage >= stage else { return }
			let clamped = min(1, max(0, fraction))
			if newStage == stage {
				stageFraction = max(stageFraction, clamped)   // không lùi trong cùng chặng
			} else {
				stage = min(newStage, Self.stageCount - 1)
				stageFraction = clamped
			}
		}
	}
	
	/// Đặt việc chạy khi hộp thoại đã đóng hẳn
	func runAfterDismiss(_ block: @escaping () -> Void) {
		_main { [self] in _afterDismiss = block }
	}
	
	func complete() {
		_main { [self] in
			guard phase == .running else { return }
			_stopCreep()
			phase = .done
			stage = Self.stageCount
			stageFraction = 1
			let work = DispatchWorkItem { [weak self] in self?.dismiss() }
			_hideWork = work
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
		}
	}
	
	func fail() {
		_main { [self] in
			guard phase == .running else { return }
			_stopCreep()
			phase = .failed
		}
	}
	
	func dismiss() {
		_main { [self] in
			_hideWork?.cancel(); _hideWork = nil
			_stopCreep()
			phase = .idle
			stage = 1
			stageFraction = 0
			app = nil
			let job = _afterDismiss
			_afterDismiss = nil
			job?()
		}
	}
	
	// Zsign không báo % thật, nên trong mỗi chặng thanh trôi chậm dần tới ~90% để người dùng thấy đang chạy
	private func _startCreep() {
		_stopCreep()
		_creepTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
			guard let self, self.phase == .running else { return }
			let cap = 0.9
			if self.stageFraction < cap {
				self.stageFraction += (cap - self.stageFraction) * 0.05
			}
		}
	}
	
	private func _stopCreep() {
		_creepTimer?.invalidate()
		_creepTimer = nil
	}
}

struct SigningSheetContent: View {
	@ObservedObject private var _center = SigningProgressCenter.shared
	
	private var _steps: [String] {
		[String.localized("Preparing"), String.localized("Signing app"), String.localized("Packaging"), String.localized("Done")]
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			if let app = _center.app {
				XSignSheetHeader(app: app, certificateName: _center.certificateName)
			}
			XSignStageProgress(
				steps: _steps,
				stage: _center.stage,
				overall: _center.overall,
				segment: { _center.segmentFraction($0) },
				isDone: _center.phase == .done,
				isFailed: _center.phase == .failed
			)
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.background(XSignSheetBG.color.ignoresSafeArea())
	}
}
