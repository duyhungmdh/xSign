//
//  AccentColorManager.swift
//  Ksign
//
//  Created by Nagata Asami on 6/30/25.
//
//  xSign: 3 chế độ màu chủ đạo (Theo máy / Chọn sẵn / Tùy chỉnh).
//

import SwiftUI
import UIKit

// MARK: - Accent Color Manager
class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    enum Mode: Int { case device = 0, preset = 1, custom = 2 }
    
    static let modeKey = "xsign.accentMode"
    static let presetKey = "Feather.accentColor"
    static let customKey = "xsign.accentCustomHex"
    
    // 10 màu chọn sẵn (theo mẫu Zsign)
    static let presets: [(name: String, hex: String)] = [
        ("Xanh dương", "#337AE0"), ("Chàm", "#5057C4"), ("Tím", "#8B5CE6"), ("Hồng", "#EE5C8E"), ("Đỏ", "#E24B4F"),
        ("Cam", "#F58A2E"), ("Vàng", "#EEC23A"), ("Xanh lá", "#43B86F"), ("Xanh ngọc", "#27AEB0"), ("Xám xanh", "#69728C")
    ]
    
    var mode: Mode {
        get { Mode(rawValue: UserDefaults.standard.integer(forKey: Self.modeKey)) ?? .device }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.modeKey); refresh() }
    }
    
    var presetIndex: Int {
        get {
            let i = UserDefaults.standard.integer(forKey: Self.presetKey)
            return (0..<Self.presets.count).contains(i) ? i : 0
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.presetKey); refresh() }
    }
    
    var customHex: String {
        get { UserDefaults.standard.string(forKey: Self.customKey) ?? Self.presets[0].hex }
        set { UserDefaults.standard.set(newValue, forKey: Self.customKey); refresh() }
    }
    
    private var currentHex: String {
        switch mode {
        case .device: return DeviceInfo.selectedColor?.hex ?? Self.presets[0].hex
        case .preset: return Self.presets[presetIndex].hex
        case .custom: return customHex
        }
    }
    
    var currentAccentColor: Color { Color(xsignHex: currentHex) }
    var currentUIColor: UIColor { UIColor(Color(xsignHex: currentHex)) }
    
    /// Gọi khi bất kỳ giá trị màu nào đổi
    func refresh() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.updateGlobalTintColor()
        }
    }
    
    /// Updates the global app tint color
    func updateGlobalTintColor() {
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    window.tintColor = self.currentUIColor
                }
        }
    }
}
