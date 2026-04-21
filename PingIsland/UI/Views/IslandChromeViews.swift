import SwiftUI

struct IslandDragHandleVisual: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.22))
            .frame(width: 38, height: 6)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: 20, height: 4)
            }
            .accessibilityLabel("Drag to detach")
    }
}
