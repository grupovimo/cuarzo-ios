import SwiftUI

struct NuevoApartadoFlujo: View {

    var body: some View { ZStack { FondoCuarzo(); Text("NuevoApartadoFlujo").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}

struct MoverApartadoPantalla: View {
    let id: String
    var guardar: Bool
    var body: some View { ZStack { FondoCuarzo(); Text("MoverApartadoPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
