//
//  ContentView.swift
//  GraphStudio
//
//  Created by Michael Wang on 12/21/25.
//

import SwiftUI
import MathParser

struct GraphItem: Identifiable {
    let id = UUID()
    
    var label: String
    var evaluator: Evaluator
    let color: Color
    
    var hasEdited: Bool = false
}

struct ContentView: View {
    @State private var items: [GraphItem] = []
    
    var body: some View {
        VStack {
            GraphView(items: $items)
            GraphInput(items: $items)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
