//
//  XSignAboutView.swift
//  xSign (personal customization)
//
//  Màn hình Giới thiệu: logo, tên app, phiên bản, Build ID, tác giả.
//

import SwiftUI
import NimbleViews

struct XSignAboutView: View {
	/// Lấy từ MARKETING_VERSION trong project.pbxproj nên đổi một chỗ là khớp mọi nơi
	private let _version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.6"
	private let _buildID = "mdh.xsign"
	private let _author = "Mai Hồng Vũ"
	
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack(spacing: 10) {
					Image("XSignLogo")
						.resizable()
						.scaledToFit()
						.frame(width: 96, height: 96)
						.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
					Text(verbatim: "xSign")
						.font(.title2.weight(.semibold))
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 12)
			}
			
			Section {
				_infoRow("Phiên bản", _version)
				_infoRow("Build ID", _buildID)
				_infoRow("Tác giả", _author)
			}
		}
	}
	
	@ViewBuilder
	private func _infoRow(_ title: LocalizedStringKey, _ value: String) -> some View {
		HStack {
			Text(title)
			Spacer()
			Text(verbatim: value)
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
		}
	}
}
