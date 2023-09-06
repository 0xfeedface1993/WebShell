//
//  StatefulPreviewWrapper.swift
//  S8Blocker
//
//  Created by john on 2023/9/2.
//

import SwiftUI

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    public var body: some View {
        content($value)
    }

    public init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        self._value = State(wrappedValue: value)
        self.content = content
    }
}

struct StatefulPreviewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        StatefulPreviewWrapper(10) { state in
            Text("\(state.wrappedValue)")
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct StatefulObservblePreviewWrapper<Value: ObservableObject, Content: View>: View {
    @StateObject var value: Value
    var content: (Value) -> Content

    public var body: some View {
        content(value)
    }

    public init(_ value: Value, content: @escaping (Value) -> Content) {
        self._value = StateObject(wrappedValue: value)
        self.content = content
    }
}

struct StatefulObservblePreviewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        StatefulObservblePreviewWrapper(StatefulObject()) { state in
            Text(state.title)
        }
    }
}

final class StatefulObject: ObservableObject {
    @Published var title = "apple"
}
