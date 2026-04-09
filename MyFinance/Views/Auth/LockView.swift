import SwiftUI

struct LockView: View {
    @Environment(AuthenticationService.self) private var auth

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("MyFinance")
                        .font(.largeTitle.bold())
                    Text("Masuk untuk melanjutkan")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await auth.authenticate() }
                } label: {
                    Label("Buka dengan FaceID / Touch ID", systemImage: "faceid")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }
        }
        .task { await auth.authenticate() }
    }
}
