import SwiftUI

struct FrenadaPantalla: View {
    let frenada: Frenada
    var body: some View { ZStack { FondoCuarzo(); Text("FrenadaPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
