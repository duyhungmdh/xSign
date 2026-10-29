//
//  AppearanceView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//
//  xSign: giao diện theo mẫu Zsign (xem trước, màu chủ đạo 3 chế độ, sáng/tối, biểu tượng).
//

import SwiftUI
import NimbleViews

struct AppearanceView: View {
    @AppStorage("Feather.userInterfaceStyle") private var _userIntefacerStyle: Int = UIUserInterfaceStyle.unspecified.rawValue
    @StateObject private var _accent = AccentColorManager.shared
    
    @State private var _mode: Int = AccentColorManager.shared.mode.rawValue
    @State private var _preset: Int = AccentColorManager.shared.presetIndex
    @State private var _customColor: Color = Color(xsignHex: AccentColorManager.shared.customHex)
    
    private var _accentColor: Color { _accent.currentAccentColor }
    
    var body: some View {
        NBList(.localized("Giao diện")) {
            _preview()
            _languageSection()
            _accentSection()
            _styleSection()
            _iconSection()
        }
        .onChange(of: _userIntefacerStyle) { value in
            if let style = UIUserInterfaceStyle(rawValue: value) {
                UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
            }
        }
    }
}

// MARK: - Sections
extension AppearanceView {
    @ViewBuilder
    private func _preview() -> some View {
        Section {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(uiImage: UIImage(named: Bundle.main.iconFileName ?? "") ?? UIImage())
                        .appIconStyle(size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: Bundle.main.name).font(.headline)
                        Text("Xem trước màu chủ đạo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("Nút mẫu")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(_accentColor))
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.2), value: _accentColor)
        }
    }
    
    @ViewBuilder
    private func _languageSection() -> some View {
        Section {
            NavigationLink(destination: LanguagePickerView()) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(_accentColor)
                        .frame(width: 26)
                    Text("Ngôn ngữ")
                    Spacer()
                    Text(verbatim: AppLanguage.current.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func _accentSection() -> some View {
        Section {
            Picker("Màu chủ đạo", selection: $_mode) {
                Text("Theo máy").tag(0)
                Text("Chọn sẵn").tag(1)
                Text("Tùy chỉnh").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: _mode) { value in
                _accent.mode = AccentColorManager.Mode(rawValue: value) ?? .device
            }
            
            switch _mode {
            case 1:
                _presetGrid()
            case 2:
                ColorPicker("Chọn màu tùy ý", selection: $_customColor, supportsOpacity: false)
                    .onChange(of: _customColor) { value in
                        _accent.customHex = value.hexString
                    }
            default:
                NavigationLink(destination: DeviceColorPickerView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.title3)
                            .foregroundStyle(_accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tự động theo máy")
                            Text(verbatim: DeviceInfo.modelName + (DeviceInfo.selectedColor.map { " · \($0.name)" } ?? ""))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if DeviceInfo.selectedColor == nil {
                                Text("Chạm để chọn màu máy")
                                    .font(.footnote)
                                    .foregroundStyle(_accentColor)
                            }
                        }
                        Spacer()
                        Circle().fill(_accentColor).frame(width: 24, height: 24)
                    }
                }
            }
        } header: {
            Text("Màu chủ đạo")
        } footer: {
            Text("Áp cho nút, tab, điểm nhấn trong toàn app.")
        }
    }
    
    @ViewBuilder
    private func _presetGrid() -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(AccentColorManager.presets.indices, id: \.self) { index in
                let color = Color(xsignHex: AccentColorManager.presets[index].hex)
                Button {
                    _preset = index
                    _accent.presetIndex = index
                } label: {
                    ZStack {
                        Circle().fill(color).frame(width: 38, height: 38)
                        if _preset == index {
                            Circle().strokeBorder(Color.primary, lineWidth: 2).frame(width: 46, height: 46)
                            Image(systemName: "checkmark").font(.footnote.bold()).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AccentColorManager.presets[index].name)
            }
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private func _styleSection() -> some View {
        Section {
            Picker("Sáng & Tối", selection: $_userIntefacerStyle) {
                Text("Hệ thống").tag(UIUserInterfaceStyle.unspecified.rawValue)
                Text("Sáng").tag(UIUserInterfaceStyle.light.rawValue)
                Text("Tối").tag(UIUserInterfaceStyle.dark.rawValue)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Sáng & Tối")
        }
    }
    
    @ViewBuilder
    private func _iconSection() -> some View {
        Section {
            Button {
                UIApplication.shared.setAlternateIconName(nil)
            } label: {
                VStack(spacing: 6) {
                    Image(uiImage: UIImage(named: Bundle.main.iconFileName ?? "") ?? UIImage())
                        .appIconStyle(size: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(_accentColor, lineWidth: 2)
                                .frame(width: 70, height: 70)
                        )
                    Text("Mặc định").font(.footnote).foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Biểu tượng ứng dụng")
        }
    }
}

// MARK: - Ngôn ngữ (Tiếng Việt / English)
enum AppLanguage: String, CaseIterable, Identifiable {
    case vi, en
    
    static let key = "xsign.appLanguage"
    var id: String { rawValue }
    var title: String { self == .vi ? "Tiếng Việt" : "English" }
    
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .vi
    }
    
    /// Lưu lựa chọn. SwiftUI đổi ngay nhờ .environment(\.locale); phần dùng String.localized đổi sau khi mở lại app.
    static func apply(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }
    
    /// Gọi lúc mở app: lần đầu mặc định Tiếng Việt
    static func bootstrap() {
        if UserDefaults.standard.string(forKey: key) == nil { apply(.vi) }
    }
}

struct LanguagePickerView: View {
    @AppStorage(AppLanguage.key) private var _language: String = AppLanguage.vi.rawValue
    
    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        _language = language.rawValue
                        AppLanguage.apply(language)
                    } label: {
                        HStack {
                            Text(verbatim: language.title).foregroundStyle(.primary)
                            Spacer()
                            if _language == language.rawValue {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } footer: {
                Text("Một số chữ trong app đổi sau khi mở lại app.")
            }
        }
        .navigationTitle(Text("Ngôn ngữ"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
