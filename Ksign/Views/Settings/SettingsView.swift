//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//
//  xSign: bố cục cài đặt cá nhân hoá (theo mẫu Zsign).
//  Nhóm: Thông tin thiết bị / Quản lý / Hệ thống / Tính năng / Khác.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SettingsView: View {
    @AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
    @AppStorage(DeviceInfo.colorNameKey) private var _deviceColorName: String = ""
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>
    
    @State private var _udid: String? = DeviceInfo.udid
    @State private var _copied = false
    @State private var _showTunnel = false
    
    private var selectedCertificate: CertificatePair? {
        guard
            _storedSelectedCert >= 0,
            _storedSelectedCert < _certificates.count
        else {
            return nil
        }
        return _certificates[_storedSelectedCert]
    }
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Cài đặt")) {
            Form {
                _deviceSection()
                _manageSection()
                _systemSection()
                _featureSection()
                _resetSection()
            }
            .onAppear { _udid = DeviceInfo.udid }
            .background(
                NavigationLink(destination: TunnelView(), isActive: $_showTunnel) { EmptyView() }
                    .hidden()
            )
        }
    }
}

// MARK: - Sections
extension SettingsView {
    @ViewBuilder
    private func _deviceSection() -> some View {
        Section {
            // 1) Thiết bị (chỉ hiển thị: tên máy + màu máy, màu chọn trong Giao diện)
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thiết bị")
                    Text(verbatim: DeviceInfo.modelName + (DeviceInfo.selectedColor.map { " · \($0.name)" } ?? ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let color = DeviceInfo.selectedColor {
                    Circle().fill(color.color).frame(width: 14, height: 14)
                }
            }
            
            // 2) UDID (chỉ icon sao chép, giữ lâu để dán UDID tay)
            HStack(spacing: 12) {
                // xSign v1.9.2: logo Apple giữ nguyên màu bạc gốc (không tô theo màu giao diện).
                // Ảnh `AppleLogo` có lề trong suốt ~10%, khung 26 pt giữ thẳng hàng chữ với hàng "Thiết bị".
                Image("AppleLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("UDID thiết bị này")
                    if let udid = _udid {
                        Text(verbatim: udid)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Text("Chưa có UDID · giữ để dán")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    if let udid = _udid {
                        UIPasteboard.general.string = udid
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        _copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { _copied = false }
                    } else {
                        _pasteUDID()
                    }
                } label: {
                    Image(systemName: _udid == nil ? "doc.on.clipboard" : (_copied ? "checkmark" : "doc.on.doc"))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Sao chép UDID"))
            }
            .contextMenu {
                Button { _pasteUDID() } label: { Label("Dán UDID", systemImage: "doc.on.clipboard") }
                if DeviceInfo.manualUDID != nil {
                    Button(role: .destructive) {
                        DeviceInfo.manualUDID = nil
                        _udid = DeviceInfo.udid
                    } label: { Label("Xoá UDID đã dán", systemImage: "trash") }
                }
                Button { _showTunnel = true } label: { Label("Thiết lập pairing file", systemImage: "link") }
            }
        } header: {
            Text("Thông tin thiết bị")
        }
    }
    
    private func _pasteUDID() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              DeviceInfo.isValidUDID(text) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        DeviceInfo.manualUDID = text
        _udid = DeviceInfo.udid
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @ViewBuilder
    private func _manageSection() -> some View {
        // Một nền trắng chung cho 3 dòng. Thẻ "Chứng chỉ đang dùng" nằm bên trong,
        // nền và viền theo màu chủ đạo (Giao diện), không có đường kẻ giữa thẻ và mục "Chứng chỉ".
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chứng chỉ đang dùng")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let cert = selectedCertificate {
                    CertificatesCellView(cert: cert, isDefault: true, style: .compact)
                } else {
                    Text("Chưa có chứng chỉ")
                        .font(.footnote)
                        .foregroundColor(.disabled())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden, edges: .bottom)
            
            NavigationLink(destination: CertificatesView()) {
                _row("Chứng chỉ", "\(_certificates.count) chứng chỉ · thêm bằng .p12, .zip hoặc .xsigncert", icon: "signature")
            }
            .listRowSeparator(.hidden, edges: .top)
            
            NavigationLink(destination: ConfigurationView()) {
                _row("Tùy chọn ký", "Tên, bundle ID, quyền và tweak", icon: "slider.horizontal.3")
            }
        } header: {
            Text("Quản lý")
        }
    }
    
    @ViewBuilder
    private func _systemSection() -> some View {
        Section {
            NavigationLink(destination: AppearanceView()) {
                _row("Giao diện", "Màu chủ đạo, màu máy, ngôn ngữ", icon: "paintpalette")
            }
            NavigationLink(destination: StorageCleanupView()) {
                _row("Dung lượng & Dọn dẹp", "Phân tích dung lượng và công cụ dọn dẹp", icon: "internaldrive")
            }
            NavigationLink(destination: InstallationView()) {
                _row("Máy chủ", "Phương thức cài đặt và máy chủ cục bộ", icon: "server.rack")
            }
        } header: {
            Text("Hệ thống")
        }
    }

    @ViewBuilder
    private func _featureSection() -> some View {
        Section {
            // v1.9.5: mục đầu tiên của phần Tính năng
            NavigationLink(destination: TabBarCustomizationView()) {
                _row("Điều chỉnh thanh điều hướng", "Sắp xếp, mặc định và mục hiển thị", icon: "rectangle.bottomthird.inset.filled")
            }
            NavigationLink(destination: AppFeaturesView()) {
                _row("Nâng cao", "Các tính năng bổ sung của app", icon: "sparkles")
            }
            NavigationLink(destination: LogsView(manager: LogsManager.shared)) {
                _row("Nhật ký", "Nhật ký hoạt động của app", icon: "apple.terminal")
            }
            NavigationLink(destination: ArchiveView()) {
                _row("Lưu trữ & Giải nén", "Tùy chọn nén và giải nén", icon: "archivebox")
            }
        } header: {
            Text("Tính năng")
        }
    }

    @ViewBuilder
    private func _resetSection() -> some View {
        Section {
            NavigationLink(destination: ResetView()) {
                _row("Đặt lại", nil, icon: "trash")
            }
            NavigationLink(destination: XSignAboutView()) {
                _row("Giới thiệu", nil, icon: "info.circle")
            }
        } header: {
            Text("Khác")
        }
    }
}

// MARK: - Row helpers
extension SettingsView {
    @ViewBuilder
    private func _row(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey?, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            _rowText(title, subtitle)
        }
    }
    
    @ViewBuilder
    private func _rowText(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
