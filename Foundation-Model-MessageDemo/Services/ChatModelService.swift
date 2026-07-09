//
//  ChatModelService.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation
import FoundationModels

/// LanguageModelSession(온디바이스 모델)을 감싸는 서비스 계층.
/// 채팅 하나당 인스턴스 하나를 사용해 대화 컨텍스트를 유지한다.
@MainActor
final class ChatModelService {

    private var session: LanguageModelSession?

    /// 모델 사용 불가 사유. 사용 가능하면 nil.
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "이 기기는 Apple Intelligence를 지원하지 않아요."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "설정에서 Apple Intelligence를 켜주세요."
        case .unavailable(.modelNotReady):
            return "모델을 준비 중이에요. 잠시 후 다시 시도해주세요."
        case .unavailable:
            return "지금은 모델을 사용할 수 없어요."
        }
    }

    /// 응답을 조각 단위로 스트리밍한다. 각 요소는 "지금까지 생성된 전체 텍스트"(누적 스냅샷)이다.
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        let session = activeSession()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: prompt) {
                        continuation.yield(partial)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func activeSession() -> LanguageModelSession {
        let session = self.session ?? LanguageModelSession(
            instructions: "당신은 친절한 어시스턴트입니다. 한국어로 간결하게 답하세요."
        )
        self.session = session
        return session
    }
}
