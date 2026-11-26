import SwiftUI

struct PasarPantalla: View {
    var desde: Bolsillo
    var body: some View { ZStack { FondoCuarzo(); Text("PasarPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}

struct IngresarPlataPantalla: View {

    var body: some View { ZStack { FondoCuarzo(); Text("IngresarPlataPantalla").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
