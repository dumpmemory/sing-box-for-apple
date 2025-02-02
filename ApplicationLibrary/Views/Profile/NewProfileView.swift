import Foundation
import Libbox
import Library
import SwiftUI

public struct NewProfileView: View {
    #if os(macOS)
        public static let windowID = "new-profile"
    #endif

    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var profileName = ""
    @State private var profileType = ProfileType.local
    @State private var fileImport = false
    @State private var fileURL: URL!
    @State private var remotePath = ""
    @State private var pickerPresented = false
    @State private var alert: Alert?

    public struct ImportRequest: Codable, Hashable {
        public let name: String
        public let url: String
    }

    private let callback: (() -> Void)?
    public init(_ importRequest: ImportRequest? = nil, _ callback: (() -> Void)? = nil) {
        self.callback = callback
        if let importRequest {
            _profileName = .init(initialValue: importRequest.name)
            _profileType = .init(initialValue: .remote)
            _remotePath = .init(initialValue: importRequest.url)
        }
    }

    public var body: some View {
        FormView {
            FormItem("Name") {
                TextField("Name", text: $profileName, prompt: Text("Required"))
                    .multilineTextAlignment(.trailing)
            }
            Picker(selection: $profileType) {
                #if !os(tvOS)
                    Text("Local").tag(ProfileType.local)
                    Text("iCloud").tag(ProfileType.icloud)
                #endif
                Text("Remote").tag(ProfileType.remote)
            } label: {
                Text("Type")
            }
            if profileType == .local {
                Picker(selection: $fileImport) {
                    Text("Create New").tag(false)
                    Text("Import").tag(true)
                } label: {
                    Text("File")
                }
                #if os(tvOS)
                .disabled(true)
                #endif
                viewBuilder {
                    if fileImport {
                        HStack {
                            Text("File Path")
                            Spacer()
                            Spacer()
                            if let fileURL {
                                Button(fileURL.fileName) {
                                    pickerPresented = true
                                }
                            } else {
                                Button("Choose") {
                                    pickerPresented = true
                                }
                            }
                        }
                    }
                }
            } else if profileType == .icloud {
                FormItem("Path") {
                    TextField("Path", text: $remotePath, prompt: Text("Required"))
                        .multilineTextAlignment(.trailing)
                }
            } else if profileType == .remote {
                FormItem("URL") {
                    TextField("URL", text: $remotePath, prompt: Text("Required"))
                        .multilineTextAlignment(.trailing)
                }
            }
            Section {
                if !isSaving {
                    Button("Create") {
                        isSaving = true
                        Task.detached {
                            await createProfile()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("New Profile")
        .alertBinding($alert)
        #if os(iOS) || os(macOS)
            .fileImporter(
                isPresented: $pickerPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let urls = try result.get()
                    if !urls.isEmpty {
                        fileURL = urls[0]
                    }
                } catch {
                    alert = Alert(error)
                    return
                }
            }
        #endif
    }

    private func createProfile() async {
        defer {
            isSaving = false
        }
        if profileName.isEmpty {
            alert = Alert(errorMessage: "Missing profile name")
            return
        }
        if remotePath.isEmpty {
            if profileType == .icloud {
                alert = Alert(errorMessage: "Missing path")
                return
            } else if profileType == .remote {
                alert = Alert(errorMessage: "Missing URL")
                return
            }
        }
        do {
            try createProfile0()
        } catch {
            alert = Alert(error)
            return
        }
        await MainActor.run {
            dismiss()
            if let callback {
                callback()
            }
            #if os(macOS)
                NotificationCenter.default.post(name: ProfileView.notificationName, object: nil)
                resetFields()
            #endif
        }
    }

    private func resetFields() {
        profileName = ""
        profileType = .local
        fileImport = false
        fileURL = nil
        remotePath = ""
    }

    private func createProfile0() throws {
        let nextProfileID = try ProfileManager.nextID()

        var savePath = ""
        var remoteURL: String? = nil
        var lastUpdated: Date? = nil

        if profileType == .local {
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            if fileImport {
                guard let fileURL else {
                    alert = Alert(errorMessage: "Missing file")
                    return
                }
                if !fileURL.startAccessingSecurityScopedResource() {
                    alert = Alert(errorMessage: "Missing access to selected file")
                    return
                }
                defer {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                try String(contentsOf: fileURL).write(to: profileConfig, atomically: true, encoding: .utf8)
            } else {
                try "{}".write(to: profileConfig, atomically: true, encoding: .utf8)
            }
            savePath = profileConfig.relativePath
        } else if profileType == .icloud {
            if !FileManager.default.fileExists(atPath: FilePath.iCloudDirectory.path) {
                try FileManager.default.createDirectory(at: FilePath.iCloudDirectory, withIntermediateDirectories: true)
            }
            let saveURL = FilePath.iCloudDirectory.appendingPathComponent(remotePath, isDirectory: false)
            _ = saveURL.startAccessingSecurityScopedResource()
            defer {
                saveURL.stopAccessingSecurityScopedResource()
            }
            do {
                _ = try String(contentsOf: saveURL)
            } catch {
                try "{}".write(to: saveURL, atomically: true, encoding: .utf8)
            }
            savePath = remotePath
        } else if profileType == .remote {
            let remoteContent = try HTTPClient().getString(remotePath)
            var error: NSError?
            LibboxCheckConfig(remoteContent, &error)
            if let error {
                throw error
            }
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try remoteContent.write(to: profileConfig, atomically: true, encoding: .utf8)
            savePath = profileConfig.relativePath
            remoteURL = remotePath
            lastUpdated = .now
        }
        try ProfileManager.create(Profile(name: profileName, type: profileType, path: savePath, remoteURL: remoteURL, lastUpdated: lastUpdated))
    }
}
