//
//  ChatDetailView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import SwiftUI

struct ChatDetailView: View {

    @State private var viewModel: ChatDetailViewModel
    private let onUpdate: (ChatSession) -> Void

    init(chat: ChatSession, onUpdate: @escaping (ChatSession) -> Void) {
        _viewModel = State(initialValue: ChatDetailViewModel(chat: chat))
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.chat.messages) { message in
                            MessageView(message: message, isLoading: false)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            MessageView(
                                message: Message(isUser: false, text: ""),
                                isLoading: true
                            )
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: viewModel.chat.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.chat.messages.last?.text) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) {
                    scrollToBottom(proxy: proxy)
                }
            }

            inputBar
        } //: VStack
        .navigationTitle(viewModel.chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.chat) {
            onUpdate(viewModel.chat)
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.gray.opacity(0.15))
                )

            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } //: HStack
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let target: AnyHashable? = viewModel.isLoading ? "loading" : viewModel.chat.messages.last?.id
        guard let target else { return }
        withAnimation {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(chat: .sample, onUpdate: { _ in })
    }
}
