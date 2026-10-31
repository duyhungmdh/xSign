//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//
//  xSign v1.9.5: tab mở đầu tiên lấy từ cấu hình thanh điều hướng.
//

import SwiftUI

struct TabbarView: View {
	@State private var selectedTab: TabEnum = TabEnum.launchDefaultTab

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
	}
}
