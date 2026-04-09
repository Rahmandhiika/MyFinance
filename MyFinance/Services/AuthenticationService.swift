import LocalAuthentication
import Foundation

@Observable
class AuthenticationService {
    var isLocked = true

    func authenticate() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = false
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Buka MyFinance untuk akses data keuangan Anda"
            )
            if success { isLocked = false }
        } catch {
            // Fallback to passcode
            let ctx2 = LAContext()
            let success = (try? await ctx2.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Buka MyFinance")) ?? false
            if success { isLocked = false }
        }
    }

    func lock() { isLocked = true }
}
