//
//  MessageView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI

struct MessageView: View {
    
    let message: Message
    let isLoading: Bool
    
    var body: some View {
        
        if message.isUser {
            
            HStack(spacing: 0) {
                Spacer()
                Text(message.text)
                    .font(.callout)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .foregroundStyle(.gray.opacity(0.2))
                    )
                    .padding(5)
            } //: HStack
            
        } else {
            HStack(spacing: 0) {
                Group {
                    if isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("생각 중...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(message.text)
                    }
                }
                .font(.callout)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundStyle(.blue.opacity(0.1))
                )
                .padding(5)
                Spacer()
            } //: HStack
        }
        
    }
}

#Preview("User Message") {
    MessageView(message: .sampleUser, isLoading: false)
}

#Preview("Assistant Message") {
    MessageView(message: .sampleAssistant, isLoading: true)
}
