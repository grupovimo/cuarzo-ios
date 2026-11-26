import SwiftUI

struct Onboarding: View {
    var paso: Int = 0
    var alTerminar: (Bool) -> Void
    init(paso: Int = 0, alTerminar: @escaping (Bool) -> Void) { self.paso = paso; self.alTerminar = alTerminar }
    var body: some View { ZStack { FondoCuarzo(); Text("Onboarding").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
