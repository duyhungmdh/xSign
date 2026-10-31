//
//  Storage+Sources.swift
//  Feather
//
//  Created by samara on 12.04.2025.
//

import CoreData
import AltSourceKit
import NimbleJSON

// MARK: - Class extension: Sources
extension Storage {
	/// Retrieve sources in an array, we don't normally need this in swiftUI but we have it for the copy sources action
	func getSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		return (try? context.fetch(request)) ?? []
	}
	
	func addSource(
		_ url: URL,
		name: String? = "Unknown",
		identifier: String,
		iconURL: URL? = nil,
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		if sourceExists(identifier) {
			completion(nil)
			print("ignoring \(identifier)")
			return
		}
		
		let new = AltSource(context: context)
		new.name = name
		new.date = Date()
		new.identifier = identifier
		new.sourceURL = url
		new.iconURL = iconURL
		new.setValue(isBuiltIn, forKey: "isBuiltIn")
		
		do {
			if !deferSave {
				try context.save()
			}
			completion(nil)
		} catch {
			completion(error)
		}
	}
	
	func addSource(
		_ url: URL,
		repository: ASRepository,
		id: String = "",
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		addSource(
			url,
			name: repository.name,
			identifier: !id.isEmpty
						? id
						: (repository.id ?? url.absoluteString),
			iconURL: repository.currentIconURL,
			deferSave: deferSave,
			isBuiltIn: isBuiltIn,
			completion: completion
		)
	}

	func addSources(
		repos: [URL: ASRepository],
		completion: @escaping (Error?) -> Void
	) {
		for (url, repo) in repos {
			addSource(
				url,
				repository: repo,
				deferSave: true,
				completion: { error in
					if let error {
						completion(error)
					}
				}
			)
		}
		
        saveContext()
        completion(nil)
	}


	/// xSign: xoá một lần các repo mặc định không dùng (SideStore Team Pick, crystall1ne.dev)
	/// đã được thêm từ các bản cài trước.
	func removeUnwantedBuiltInSources() {
		let flag = "xsign.removedDefaultSources.v1"
		guard !UserDefaults.standard.bool(forKey: flag) else { return }
		
		let blockedHosts = ["community-apps.sidestore.io", "alt.crystall1ne.dev"]
		for source in getSources() {
			if let host = source.sourceURL?.host, blockedHosts.contains(host) {
				context.delete(source)
			}
		}
		saveContext()
		UserDefaults.standard.set(true, forKey: flag)
	}

	/// xSign v1.9.3: kho mặc định của xSign (thay cho "Ksign Repository" của Nyasami).
	static let mdhSourceURL = "https://raw.githubusercontent.com/duyhungmdh/MDHIOS/main/Apps.json"
	
	/// xSign v1.9.3: với bản đã cài từ trước, thêm kho MDH và xoá "Ksign Repository" (chạy một lần).
	/// Chạy lặng lẽ: không hiện hộp thoại (khác `FR.handleSource`). Mạng lỗi thì KHÔNG đặt cờ,
	/// lần mở app sau tự thử lại. Bản cài mới hoàn toàn không cần hàm này (đã dùng kho MDH sẵn).
	func replaceKsignRepositoryWithMDH() {
		let flag = "xsign.replacedKsignRepo.v1"
		guard !UserDefaults.standard.bool(forKey: flag),
			  let url = URL(string: Storage.mdhSourceURL) else { return }
		
		NBFetchService().fetch<ASRepository>(from: url) { (result: Result<ASRepository, Error>) in
			guard case .success(let data) = result else { return }
			
			DispatchQueue.main.async {
				let storage = Storage.shared
				let id = data.id ?? url.absoluteString
				if !storage.sourceExists(id) {
					storage.addSource(url, repository: data, id: id) { _ in }
				}
				
				for source in storage.getSources() {
					if source.sourceURL?.absoluteString.contains("Nyasami/Ksign") == true {
						storage.context.delete(source)
					}
				}
				storage.saveContext()
				UserDefaults.standard.set(true, forKey: flag)
			}
		}
	}

	func addBuiltInSources() {
		removeUnwantedBuiltInSources()
		
		// xSign v1.9.3: kho mặc định "Ksign Repository" được thay bằng kho MDH (MDHIOS)
		let builtInSourceURLs = [
            Storage.mdhSourceURL,
            "https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps.json"
		]
		
		for urlString in builtInSourceURLs {
			FR.handleSource(urlString) { }
		}
	}

	func deleteSource(for source: AltSource) {
		context.delete(source)
		saveContext()
	}

	func sourceExists(_ identifier: String) -> Bool {
		let fetchRequest: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

		do {
			let count = try context.count(for: fetchRequest)
			return count > 0
		} catch {
			print("Error checking if repository exists: \(error)")
			return false
		}
	}
}
