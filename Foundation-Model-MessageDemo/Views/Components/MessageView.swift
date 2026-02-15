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
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    // TODO: ChatGPT 와 같이 생각하는 중이라고 해야할듯?
                }
                
                // TODO: Component로 loading 중일때는 loading 표시 하고 메세지를 쫘-악 뿌려주는 느낌으로 아마 Animation 처리를 해야할듯?
            }
        }
        
    }
}

#Preview {
    MessageView(
        message: Message(
            isUser: true,
            text: "Test Message"
        ),
        isLoading: true
    )
}
