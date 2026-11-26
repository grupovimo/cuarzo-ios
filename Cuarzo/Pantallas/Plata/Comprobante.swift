import SwiftUI

struct ComprobanteVista: View {
    let movimientoID: String
    var celebrar = false
    var body: some View { ZStack { FondoCuarzo(); Text("ComprobanteVista").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
