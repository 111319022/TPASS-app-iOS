import SwiftUI

// 1. 定義 Key：用來收集各個元件的位置
struct ViewFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// 2. 定義擴充功能：讓任何 View 都可以回報自己的位置
extension View {
    func reportFrame(id: String, in space: CoordinateSpace = .global) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ViewFrameKey.self,
                                value: [id: geo.frame(in: space)])
            }
        )
    }
}
