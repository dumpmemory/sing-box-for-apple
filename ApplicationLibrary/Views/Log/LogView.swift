import Library
import SwiftUI

public struct LogView: View {
    @Environment(\.selection) private var selection
    @EnvironmentObject private var environments: ExtensionEnvironments

    private let logFont = Font.system(.caption2, design: .monospaced)

    public init() {}

    public var body: some View {
        if environments.logClient.logList.isEmpty {
            VStack {
                if environments.logClient.isConnected {
                    Text("Empty logs")
                } else {
                    Text("Service not started").onAppear {
                        environments.connectLog()
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(environments.logClient.logList.enumerated()), id: \.offset) { it in
                            Text(it.element)
                                .font(logFont)
                            #if os(tvOS)
                                .focusable()
                            #endif
                            Spacer(minLength: 8)
                        }

                        .onChangeCompat(of: environments.logClient.logList.count) { newCount in
                            withAnimation {
                                reader.scrollTo(newCount - 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                }
                #if os(tvOS)
                .focusEffectDisabled()
                .focusSection()
                #endif
                .onAppear {
                    reader.scrollTo(environments.logClient.logList.count - 1)
                }
            }
        }
    }
}
