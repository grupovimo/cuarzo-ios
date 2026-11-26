import SwiftUI
import CoreImage.CIFilterBuiltins

/// QR de verdad (escaneable) con el símbolo de Cuarzo al centro, sobre papel nácar.
struct QRCuarzo: View {
    let contenido: String
    var tamano: CGFloat = 200
    /// Aparece de a poco, módulo por módulo (la primera vez).
    var animado = true
    @State private var visible = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.nacar)
            if let img = QRCuarzo.imagen(contenido) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .mask {
                        if animado {
                            RadialGradient(colors: [.black, .black, .clear], center: .center, startRadius: 0,
                                           endRadius: visible ? tamano : 1)
                        } else {
                            Color.black
                        }
                    }
            }
            Image("simbolo-noche")
                .resizable().scaledToFit()
                .frame(width: tamano * 0.16)
                .padding(tamano * 0.035)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nacar))
                .scaleEffect(visible || !animado ? 1 : 0.4)
        }
        .frame(width: tamano, height: tamano)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { visible = true } }
        .accessibilityElement()
        .accessibilityLabel("Código QR para cobrar")
    }

    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

    static func imagen(_ s: String) -> UIImage? {
        if let i = cache[s] { return i }
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8)
        f.correctionLevel = "H"
        guard let out = f.outputImage else { return nil }
        let color = CIFilter.falseColor()
        color.inputImage = out
        color.color0 = CIColor(red: 12 / 255, green: 9 / 255, blue: 17 / 255)
        color.color1 = CIColor(red: 248 / 255, green: 243 / 255, blue: 246 / 255)
        guard let teñida = color.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(teñida, from: teñida.extent) else { return nil }
        let i = UIImage(cgImage: cg)
        cache[s] = i
        return i
    }
}
