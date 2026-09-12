import SwiftUI

/// Wraps a logical control group in a subtle card background with rounded
/// corners, so the control surface reads as grouped sections instead of a
/// flat chain of stacks.
public struct H9SectionCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

public extension View {
    func h9SectionCard() -> some View {
        H9SectionCard { self }
    }
}
