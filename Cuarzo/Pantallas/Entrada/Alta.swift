import SwiftUI

struct Alta: View {
    var paso: Int = 0
    var alVolver: () -> Void
    var alTerminar: () -> Void
    init(paso: Int = 0, alVolver: @escaping () -> Void, alTerminar: @escaping () -> Void) { self.paso = paso; self.alVolver = alVolver; self.alTerminar = alTerminar }
    var body: some View { ZStack { FondoCuarzo(); Text("Alta").font(.geist(17, .semi)).foregroundStyle(Color.texto) } }
}
