import SwiftUI

struct Bloqueo: View {
    var alEntrar: () -> Void
    var body: some View { ZStack { FondoCuarzo(); Text("Bloqueo").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
