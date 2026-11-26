import SwiftUI

struct ApartadosPantalla: View {

    var body: some View { ZStack { FondoCuarzo(); Text("ApartadosPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}

struct DetalleApartado: View {
    let id: String
    var body: some View { ZStack { FondoCuarzo(); Text("DetalleApartado").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
