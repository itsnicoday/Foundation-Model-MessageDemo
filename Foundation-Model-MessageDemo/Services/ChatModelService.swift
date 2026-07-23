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
    private let initialTranscript: Transcript?

    init(transcript: Transcript? = nil) {
        self.initialTranscript = transcript
    }

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

    /// 세션이 한 번이라도 만들어졌으면 현재 대화 맥락. 모델을 아직 호출한 적 없으면 nil.
    var currentTranscript: Transcript? { session?.transcript }

    /// 응답을 조각 단위로 스트리밍한다. 각 요소는 "지금까지 생성된 전체 텍스트"(누적 스냅샷)이다.
    /// 모델이 종료 토큰을 못 내고 같은 구절을 무한 반복하는 경우, 반복이 감지되는 즉시
    /// 중복분을 잘라내고 스트림을 끝낸다. maximumResponseTokens는 반복이 아닌 다른 형태의
    /// 폭주 생성에 대비한 최후 안전장치.
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        let session = activeSession()
        let options = GenerationOptions(maximumResponseTokens: 2000)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: prompt, options: options) {
                        let text = partial.content
                        if let trimmed = Self.trimmedIfRepeating(text) {
                            continuation.yield(trimmed)
                            break
                        }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 텍스트 끝부분이 같은 구절을 연속 3회 이상 반복하고 있으면, 그 중복분을 제거하고
    /// (1회만 남기고) 반환한다. 반복이 아니면 nil.
    private static func trimmedIfRepeating(_ text: String) -> String? {
        let minUnitLength = 6   // 조사/어미 수준의 짧은 반복은 정상적인 표현일 수 있어 무시
        let maxUnitLength = 120 // 문장 하나 정도 길이까지만 검사
        let repeatCountThreshold = 3

        let chars = Array(text)
        let maxCheckable = min(maxUnitLength, chars.count / repeatCountThreshold)
        guard maxCheckable >= minUnitLength else { return nil }

        for unitLength in stride(from: maxCheckable, through: minUnitLength, by: -1) {
            let totalLength = unitLength * repeatCountThreshold
            let tail = chars.suffix(totalLength)
            let unit = Array(tail.prefix(unitLength))

            let isRepeating = (1..<repeatCountThreshold).allSatisfy { i in
                Array(tail.dropFirst(i * unitLength).prefix(unitLength)) == unit
            }

            if isRepeating {
                let trimmedChars = chars.prefix(chars.count - unitLength * (repeatCountThreshold - 1))
                return String(trimmedChars)
            }
        }
        return nil
    }

    private func activeSession() -> LanguageModelSession {
        if let session {
            return session
        }
        let session = initialTranscript.map { LanguageModelSession(transcript: $0) }
            ?? LanguageModelSession(
                instructions: "당신은 친절한 어시스턴트입니다. 한국어로 간결하게 답하세요."
            )
        self.session = session
        return session
    }
}
