import SwiftUI
import UIKit

/// Geist (400/500/600) para todo y Geist Mono para rótulos, CVU, alias y números de operación.
enum Peso {
    case regular, medio, semi
    var nombre: String {
        switch self {
        case .regular: return "Geist-Regular"
        case .medio: return "Geist-Medium"
        case .semi: return "Geist-SemiBold"
        }
    }
}

extension Font {
    /// Geist que acompaña al Dynamic Type del teléfono (con tope en la raíz).
    static func geist(_ tamano: CGFloat, _ peso: Peso = .regular, relativo: Font.TextStyle = .body) -> Font {
        .custom(peso.nombre, size: tamano, relativeTo: relativo)
    }
    /// Geist de tamaño fijo: los montos grandes y los títulos no rompen la grilla.
    static func geistFijo(_ tamano: CGFloat, _ peso: Peso = .semi) -> Font {
        .custom(peso.nombre, fixedSize: tamano)
    }
    static func mono(_ tamano: CGFloat, relativo: Font.TextStyle = .caption) -> Font {
        .custom("GeistMono-Medium", size: tamano, relativeTo: relativo)
    }
}

extension UIFont {
    static func geist(_ tamano: CGFloat, _ peso: Peso = .semi) -> UIFont {
        UIFont(name: peso.nombre, size: tamano) ?? .systemFont(ofSize: tamano, weight: peso == .semi ? .semibold : peso == .medio ? .medium : .regular)
    }
}

extension View {
    /// Rótulo del sistema: Geist Mono 11, mayúsculas, tracking 0,14 em, gris.
    func rotulo(_ color: Color = .sec, tamano: CGFloat = 11) -> some View {
        self.font(.mono(tamano)).tracking(tamano * 0.14).textCase(.uppercase).foregroundStyle(color).lineLimit(1)
    }

    /// Texto corrido (15, gris, interlineado 1,45).
    func parrafo(_ tamano: CGFloat = 15, color: Color = .sec) -> some View {
        self.font(.geist(tamano)).foregroundStyle(color).lineSpacing(tamano * 0.12).fixedSize(horizontal: false, vertical: true)
    }
}

/// Título en Geist 600, interlineado 1,04, tracking −0,045 em y renglones balanceados (sin viudas):
/// si ocupa dos o más renglones, busca el ancho más angosto que mantiene la misma cantidad.
struct Titulo: View {
    let texto: String
    var tamano: CGFloat = 32
    var color: Color = .texto
    var centrado = false
    @Environment(\.dynamicTypeSize) private var dts

    init(_ texto: String, tamano: CGFloat = 32, color: Color = .texto, centrado: Bool = false) {
        self.texto = texto; self.tamano = tamano; self.color = color; self.centrado = centrado
    }

    private var escala: CGFloat {
        switch dts {
        case .xSmall, .small, .medium: return 0.95
        case .large: return 1
        case .xLarge: return 1.05
        default: return 1.1
        }
    }

    var body: some View {
        let t = tamano * escala
        EtiquetaTitulo(texto: texto, fuente: .geist(t, .semi), color: UIColor(color),
                       interlineado: tamano >= 24 ? 1.04 : 1.15, tracking: t * (tamano >= 24 ? -0.045 : -0.02),
                       centrado: centrado)
            .accessibilityElement()
            .accessibilityLabel(texto.replacingOccurrences(of: "\u{00A0}", with: " "))
            .accessibilityAddTraits(.isHeader)
    }
}

/// UILabel con interlineado fijo y renglones balanceados.
struct EtiquetaTitulo: UIViewRepresentable {
    let texto: String
    let fuente: UIFont
    let color: UIColor
    var interlineado: CGFloat = 1.04
    var tracking: CGFloat = 0
    var centrado = false

    func makeUIView(context: Context) -> UILabel {
        let l = UILabel()
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        l.lineBreakStrategy = .pushOut
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        l.isAccessibilityElement = false
        return l
    }

    func updateUIView(_ l: UILabel, context: Context) {
        l.attributedText = atribuido
    }

    var atribuido: NSAttributedString {
        let alto = fuente.pointSize * interlineado
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = alto
        p.maximumLineHeight = alto
        p.alignment = centrado ? .center : .natural
        p.lineBreakStrategy = .pushOut
        let natural = fuente.ascender - fuente.descender
        let desplazar = (alto - natural) / 2
        return NSAttributedString(string: texto, attributes: [
            .font: fuente, .foregroundColor: color, .paragraphStyle: p, .kern: tracking,
            .baselineOffset: desplazar / 2,
        ])
    }

    func sizeThatFits(_ propuesta: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let ancho = propuesta.width ?? 10_000
        let a = atribuido
        func medir(_ w: CGFloat) -> CGSize {
            a.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                           options: [.usesLineFragmentOrigin], context: nil).integral.size
        }
        let completo = medir(ancho)
        let alto = fuente.pointSize * interlineado
        let renglones = Int((completo.height / alto).rounded())
        guard renglones >= 2, propuesta.width != nil else {
            return CGSize(width: propuesta.width ?? completo.width, height: completo.height)
        }
        var bajo: CGFloat = ancho / CGFloat(renglones), alto2 = ancho
        for _ in 0..<12 {
            let medio = (bajo + alto2) / 2
            if Int((medir(medio).height / alto).rounded()) > renglones { bajo = medio } else { alto2 = medio }
        }
        // El label queda del ancho balanceado: así UIKit corta los renglones ahí (el contenedor lo alinea).
        let w = min(ancho, ceil(alto2) + 1)
        uiView.preferredMaxLayoutWidth = w
        let final = medir(w)
        return CGSize(width: w, height: final.height)
    }
}
