//
//  GraphInput.swift
//  GraphStudio
//
//  Created by Michael Wang on 12/26/25.
//

import SwiftUI
import MathParser

struct GraphItemRow: View {
    @Binding var item: GraphItem
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    @State private var alertPresented: Bool = false
    @State private var alertMessage: String? = nil
    
    var body: some View {
        HStack {
            if (isEditing) {
                TextField("ExpressionInput", text: $item.label)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onSubmit {
                        let parser = MathParser()
                        let result = parser.parseResult(item.label)
                        switch result {
                        case .success(let evaluator):
                            item.evaluator = evaluator
                            item.hasEdited = true
                            isEditing = false
                        case .failure(let error):
                            alertMessage = error.description
                            alertPresented = true
                        }
                    }
                    .submitLabel(.done)
                    .alert("Error", isPresented: $alertPresented) {
                        Button("OK") { alertPresented = false }
                    } message: {
                        Text(alertMessage ?? "Unknown error")
                    }
            } else {
                Text(item.label)
                    .lineLimit(1)
                    .onTapGesture {
                        guard item.hasEdited else { return }
                        isEditing = true
                    }
            }
            Spacer()
        }
    }
}

struct DraftRow: View {
    var onSubmit: (GraphItem) -> Void
    var onCancel: () -> Void
    
    @State private var text: String = ""
    @FocusState private var focused: Bool
    
    @State private var alertPresented: Bool = false
    @State private var alertMessage: String? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .foregroundStyle(.secondary)

            TextField("Type an expression…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let parser = MathParser()
                    let result = parser.parseResult(text)
                    switch result {
                    case .success(let evaluator):
                        onSubmit(GraphItem(
                            label: text, evaluator: evaluator, color: Color.blue
                        ))
                    case .failure(let error):
                        alertMessage = error.description
                        alertPresented = true
                    }
                }
                .alert("Error", isPresented: $alertPresented) {
                    Button("OK") {
                        alertPresented = false
                        onCancel()
                    }
                } message: {
                    Text(alertMessage ?? "Unknown error")
                }

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .onAppear { focused = true }
        .padding(.vertical, 4)
    }
}

struct GraphInput: View {
    @Binding var items: [GraphItem]
    
    @State private var isAdding: Bool = false
    @State private var isHidden: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Expressions")
                    .font(.headline)
                Spacer()
                Button {
                    isHidden.toggle()
                } label: {
                    if isHidden {
                        Image(systemName: "chevron.up")
                    } else {
                        Image(systemName: "chevron.down")
                    }
                }
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .keyboardShortcut(.init("+"), modifiers: [.command])
            }
            .padding()
            .background(.ultraThinMaterial)
            
            if (isHidden == false) {
                List {
                    ForEach($items) { $item in
                        GraphItemRow(item: $item)
                    }
                    .onDelete { indexSet in
                        items.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        items.move(fromOffsets: from, toOffset: to)
                    }
                    
                    if isAdding {
                        DraftRow(onSubmit: { item in
                            guard isAdding else { return }
                            withAnimation {
                                isAdding = false
                            }
                            // Defer the append to the next run loop to avoid List diff glitches
                            DispatchQueue.main.async {
                                items.append(item)
                            }
                        }, onCancel: {
                            withAnimation {
                                isAdding = false
                            }
                        })
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    GraphInput(items: .constant([]))
}
