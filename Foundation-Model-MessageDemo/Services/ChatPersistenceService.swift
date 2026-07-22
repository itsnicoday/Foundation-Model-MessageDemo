//
//  ChatPersistenceService.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import SwiftData
import FoundationModels

@MainActor
final class ChatPersistenceService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadAllChats() -> [ChatSession] {
        let descriptor = FetchDescriptor<ChatSessionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map { entity in
            let messages = entity.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { Message(id: $0.id, isUser: $0.isUser, text: $0.text) }
            return ChatSession(id: entity.id, title: entity.title, messages: messages)
        }
    }

    func createChat(_ chat: ChatSession) {
        let entity = ChatSessionEntity(id: chat.id, title: chat.title)
        modelContext.insert(entity)
        saveIfNeeded()
    }

    func deleteChat(id: ChatSession.ID) {
        guard let entity = fetchEntity(id: id) else { return }
        modelContext.delete(entity)
        saveIfNeeded()
    }

    func appendMessage(_ message: Message, toChatID chatID: ChatSession.ID) {
        guard let chatEntity = fetchEntity(id: chatID) else { return }
        let messageEntity = MessageEntity(id: message.id, isUser: message.isUser, text: message.text)
        messageEntity.chat = chatEntity
        chatEntity.messages.append(messageEntity)
        saveIfNeeded()
    }

    func loadTranscript(forChatID chatID: ChatSession.ID) -> Transcript? {
        guard let entity = fetchEntity(id: chatID), let data = entity.transcriptData else { return nil }
        return try? JSONDecoder().decode(Transcript.self, from: data)
    }

    func saveTranscript(_ transcript: Transcript?, forChatID chatID: ChatSession.ID) {
        guard let transcript, let entity = fetchEntity(id: chatID) else { return }
        entity.transcriptData = try? JSONEncoder().encode(transcript)
        saveIfNeeded()
    }

    private func fetchEntity(id: ChatSession.ID) -> ChatSessionEntity? {
        var descriptor = FetchDescriptor<ChatSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func saveIfNeeded() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            print("ChatPersistenceService save failed: \(error)")
        }
    }
}
