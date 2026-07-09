//
//  ChatDetailView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import SwiftUI

struct ChatDetailView: View {

    @Binding var chat: ChatSession

    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var service = ChatModelService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(chat.messages) { message in
                        MessageView(message: message, isLoading: false)
                    }

                    if isLoading {
                        MessageView(
                            message: Message(isUser: false, text: ""),
                            isLoading: true
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            inputBar
        } //: VStack
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $inputText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.gray.opacity(0.15))
                )

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } //: HStack
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chat.messages.append(Message(isUser: true, text: text))
        inputText = ""

        if let reason = service.unavailableReason {
            chat.messages.append(Message(isUser: false, text: reason))
            return
        }

        isLoading = true
        Task { @MainActor in
            var assistantIndex: Int?
            do {
                for try await partial in service.streamResponse(to: text) {
                    if let index = assistantIndex {
                        chat.messages[index].text = partial
                    } else {
                        isLoading = false
                        assistantIndex = chat.messages.count
                        chat.messages.append(Message(isUser: false, text: partial))
                    }
                }
            } catch {
                isLoading = false
                let errorText = "응답 생성에 실패했어요: \(error.localizedDescription)"
                if let index = assistantIndex {
                    chat.messages[index].text = errorText
                } else {
                    chat.messages.append(Message(isUser: false, text: errorText))
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var chat = ChatSession.sample
    NavigationStack {
        ChatDetailView(chat: $chat)
    }
}
