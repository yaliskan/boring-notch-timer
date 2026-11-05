//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//  Reordering (press and hold, then drag) added in the Timer/System build.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
    TabModel(label: "Timer", icon: "timer", view: .timer),
    TabModel(label: "System", icon: "cpu", view: .system)
]

extension Defaults.Keys {
    /// User-chosen tab order (raw values of NotchViews). Empty = default order.
    static let notchTabOrder = Key<[String]>("notchTabOrder", default: [])
}

/// Frames of the tabs inside the tab bar, used while dragging.
private struct TabFramesKey: PreferenceKey {
    static var defaultValue: [NotchViews: CGRect] = [:]
    static func reduce(value: inout [NotchViews: CGRect], nextValue: () -> [NotchViews: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.notchTabOrder) private var savedOrder
    @Namespace var animation

    @State private var tabFrames: [NotchViews: CGRect] = [:]
    @State private var dragging: NotchViews? = nil
    @State private var dragStartFrames: [NotchViews: CGRect] = [:]
    @State private var dragTranslation: CGFloat = 0
    @State private var dropIndex: Int? = nil

    private var orderedTabs: [TabModel] {
        let order = savedOrder.compactMap { NotchViews(rawValue: $0) }
        var result = order.compactMap { view in tabs.first { $0.view == view } }
        for tab in tabs where !result.contains(where: { $0.view == tab.view }) {
            result.append(tab)
        }
        return result
    }

    var body: some View {
        let ordered = orderedTabs
        HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.view) { index, tab in
                tabView(tab, at: index, in: ordered)
            }
        }
        .coordinateSpace(name: "tabBar")
        .onPreferenceChange(TabFramesKey.self) { tabFrames = $0 }
        .clipShape(Capsule())
    }

    private func tabView(_ tab: TabModel, at index: Int, in ordered: [TabModel]) -> some View {
        let isSelected = coordinator.currentView == tab.view
        let isDragging = dragging == tab.view
        return Image(systemName: tab.icon)
            .padding(.horizontal, 15)
            .frame(height: 26)
            .contentShape(Capsule())
            .foregroundStyle(isSelected ? .white : .gray)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color(nsColor: .secondarySystemFill))
                        .matchedGeometryEffect(id: "capsule", in: animation)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .matchedGeometryEffect(id: "capsule", in: animation)
                        .hidden()
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TabFramesKey.self, value: [tab.view: geo.frame(in: .named("tabBar"))])
                }
            )
            .offset(x: isDragging ? dragTranslation : shift(for: index, in: ordered))
            .scaleEffect(isDragging ? 1.1 : 1)
            .zIndex(isDragging ? 1 : 0)
            .animation(.smooth(duration: 0.2), value: dropIndex)
            .onTapGesture {
                guard dragging == nil else { return }
                withAnimation(.smooth) {
                    coordinator.currentView = tab.view
                }
            }
            .gesture(reorderGesture(for: tab, at: index, in: ordered))
            .help("Click to open, press and hold to reorder")
    }

    // MARK: Reordering

    /// How far a non-dragged tab moves aside to make room for the dragged one.
    private func shift(for index: Int, in ordered: [TabModel]) -> CGFloat {
        guard let dragging, let target = dropIndex,
              let source = ordered.firstIndex(where: { $0.view == dragging }),
              let width = dragStartFrames[dragging]?.width else { return 0 }
        if source < index && index <= target { return -width }
        if target <= index && index < source { return width }
        return 0
    }

    private func reorderGesture(for tab: TabModel, at index: Int, in ordered: [TabModel]) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("tabBar")))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if dragging == nil {
                    dragging = tab.view
                    dragStartFrames = tabFrames
                    dropIndex = index
                }
                dragTranslation = drag.translation.width
                let pointerX = drag.location.x
                // Find the tab whose original frame contains the pointer.
                var target = index
                for (candidateIndex, candidate) in ordered.enumerated() {
                    if let frame = dragStartFrames[candidate.view], frame.minX <= pointerX, pointerX <= frame.maxX {
                        target = candidateIndex
                        break
                    }
                }
                if let first = ordered.first, let firstFrame = dragStartFrames[first.view], pointerX < firstFrame.minX {
                    target = 0
                }
                if let last = ordered.last, let lastFrame = dragStartFrames[last.view], pointerX > lastFrame.maxX {
                    target = ordered.count - 1
                }
                if target != dropIndex { dropIndex = target }
            }
            .onEnded { value in
                defer {
                    withAnimation(.smooth(duration: 0.2)) {
                        dragging = nil
                        dragTranslation = 0
                        dropIndex = nil
                    }
                }
                guard case .second(true, _) = value,
                      let source = ordered.firstIndex(where: { $0.view == tab.view }),
                      let target = dropIndex, target != source else { return }
                var views = ordered.map(\.view)
                let moved = views.remove(at: source)
                views.insert(moved, at: target)
                savedOrder = views.map(\.rawValue)
            }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
