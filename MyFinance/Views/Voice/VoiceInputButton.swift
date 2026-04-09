import SwiftUI

struct VoiceInputButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 56, height: 56)
                    .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
    }
}
