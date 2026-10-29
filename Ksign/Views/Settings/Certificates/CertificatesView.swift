//
//  CertificatesView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//
//  xSign v5: thẻ lớn có menu chevron (Xem chi tiết / Chia sẻ / Xóa), UDID có nút sao chép.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@State private var _isAddingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?
	@State private var _sharePending: CertificatePair?
	@State private var _isShareAlertPresenting = false

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	//
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	// MARK: Body
	var body: some View {
		NBGrid {
			ForEach(Array(certificates.enumerated()), id: \.element.uuid) { index, cert in
				_cellButton(for: cert, at: index)
			}
		}
		.navigationTitle("Chứng chỉ")
		.navigationBarTitleDisplayMode(.inline)
        .overlay {
            if certificates.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("No Certificates"), systemImage: "questionmark.folder.fill")
                    } description: {
                        Text(.localized("Get started signing by importing your first certificate."))
                    } actions: {
                        Button {
                            _isAddingPresenting = true
                        } label: {
							Text("Import").bg()
                        }
                    }
                }
            }
        }
		.toolbar {
			if _bindingSelectedCert == nil {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing
				) {
					_isAddingPresenting = true
				}
			}
			if certificates.count > 0 {
			NBToolbarButton(
				systemImage: "arrow.counterclockwise",
				style: .icon,
				placement: .topBarTrailing
				) {
					// Kiểm tra lại trạng thái (thu hồi) của tất cả chứng chỉ
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					for cert in certificates {
						Storage.shared.revokagedCertificate(for: cert)
					}
				}
			}
		}
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.large])
		}
		.alert("Chia sẻ chứng chỉ", isPresented: $_isShareAlertPresenting) {
			Button("Chia sẻ") {
				if let cert = _sharePending {
					CertificateSharing.share(cert)
				}
				_sharePending = nil
			}
			Button("Hủy", role: .cancel) {
				_sharePending = nil
			}
		} message: {
			Text("Tệp .xsigncert gồm chứng chỉ .p12, provisioning profile và cả mật khẩu. Chỉ gửi cho người bạn tin tưởng.")
		}
	}
}

extension CertificatesView {
	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		let isSelected = _selectedCertBinding.wrappedValue == index
		// Không bọc trong Button để nút chevron (menu) và nút sao chép UDID bấm riêng được
		CertificatesCellView(
			cert: cert,
			isDefault: isSelected,
			style: .card,
			menu: AnyView(
				Group {
					_contextActions(for: cert)
					Divider()
					_actions(for: cert)
				}
			)
		)
		.padding()
		.background(
			RoundedRectangle(cornerRadius: _cornerRadius)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.overlay(
			RoundedRectangle(cornerRadius: _cornerRadius)
				.strokeBorder(
					isSelected ? Color.accentColor : Color.clear,
					lineWidth: 2
				)
		)
		.contentShape(RoundedRectangle(cornerRadius: _cornerRadius))
		.onTapGesture {
			_selectedCertBinding.wrappedValue = index
		}
		.contextMenu {
			_contextActions(for: cert)
			Divider()
			_actions(for: cert)
		}
		.animation(.smooth, value: _selectedCertBinding.wrappedValue)
	}
    
    private var _cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 28.0
        } else {
            return 17.0
        }
    }
    
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button(role: .destructive) {
			if certificates.count == 1 {
                UIAlertController.showAlertWithOk(
                    title: .localized("You don't want to do this!"),
                    message: .localized("You don't want to delete your only certificate, right >.<?"),
                    isCancel: true
                )
            } else {
                Storage.shared.deleteCertificate(for: cert)
            }
		} label: {
			Label("Xóa", systemImage: "trash")
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button {
			_isSelectedInfoPresenting = cert
		} label: {
			Label("Xem chi tiết", systemImage: "info.circle")
		}
		
		Button {
			_sharePending = cert
			_isShareAlertPresenting = true
		} label: {
			Label("Chia sẻ chứng chỉ", systemImage: "square.and.arrow.up")
		}
	}
	

}
