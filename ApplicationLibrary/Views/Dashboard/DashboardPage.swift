import Foundation
import Library
import SwiftUI

public enum DashboardPage: Int, CaseIterable, Identifiable {
    public var id: Self {
        self
    }

    case overview
    case groups
}

public extension DashboardPage {
    var title: String {
        switch self {
        case .overview:
            return NSLocalizedString("Overview", comment: "")
        case .groups:
            return NSLocalizedString("Groups", comment: "")
        }
    }

    var label: some View {
        switch self {
        case .overview:
            return Label("Overview", systemImage: "text.and.command.macwindow")
        case .groups:
            return Label("Groups", systemImage: "rectangle.3.group.fill")
        }
    }

    func contentView(_ profileList: Binding<[Profile]>, _ selectedProfileID: Binding<Int64?>) -> some View {
        viewBuilder {
            switch self {
            case .overview:
                OverviewView(profileList, selectedProfileID)
            case .groups:
                GroupListView()
            }
        }
    }
}
