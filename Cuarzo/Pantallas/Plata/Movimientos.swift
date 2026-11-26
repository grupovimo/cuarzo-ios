import SwiftUI

struct MovimientosPantalla: View {

    var body: some View { ZStack { FondoCuarzo(); Text("MovimientosPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}

struct DetalleMovimiento: View {
    let id: String
    var body: some View { ZStack { FondoCuarzo(); Text("DetalleMovimiento").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
