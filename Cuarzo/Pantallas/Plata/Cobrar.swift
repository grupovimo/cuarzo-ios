import SwiftUI

struct CobrarPantalla: View {
    var modo: ModoCobro = .qr
    var body: some View { ZStack { FondoCuarzo(); Text("CobrarPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
