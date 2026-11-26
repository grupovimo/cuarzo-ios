import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// Color que cambia con la apariencia. La app es oscura primero: todo lo que no es «claro» usa el de noche.
    static func dinamico(_ oscuro: UInt32, _ claro: UInt32, ao: CGFloat = 1, ac: CGFloat = 1) -> UIColor {
        UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: claro, alpha: ac) : UIColor(hex: oscuro, alpha: ao) }
    }
}

/// Tokens del manual (marca/index.html) y de pantallas/app.css. Noche ciruela de base; nácar en claro.
extension Color {
    private static func d(_ o: UInt32, _ c: UInt32, ao: CGFloat = 1, ac: CGFloat = 1) -> Color {
        Color(UIColor.dinamico(o, c, ao: ao, ac: ac))
    }

    // Superficies
    static let fondo = d(0x0C0911, 0xF8F3F6)
    static let sup = d(0x15101B, 0xFFFFFF)
    static let sup2 = d(0x1C1522, 0xF3EAF0)
    static let sup3 = d(0x241B2B, 0xEADFE5)
    static let linea = d(0x251C2C, 0xEADFE5)
    static let linea2 = d(0x3A2D40, 0xD9C7D2)

    // Texto
    static let texto = d(0xFBF5F9, 0x0C0911)
    static let sec = d(0xA99BAE, 0x6B5A70)
    static let ter = d(0x8A7B90, 0x8B7A90)

    /// Rosa cuarzo en noche; tinta (#A3306F) en nácar, que es la que da contraste sobre claro.
    static let acento = d(0xF4A9D2, 0xA3306F)
    static let acentoSuave = d(0xF4A9D2, 0xA3306F, ao: 0.12, ac: 0.09)
    static let acentoBorde = d(0xF4A9D2, 0xA3306F, ao: 0.16, ac: 0.18)

    // Fijos de marca
    static let rosa = Color(UIColor(hex: 0xF4A9D2))
    static let rosa2 = Color(UIColor(hex: 0xFBD3EA))
    static let rosaClaro = Color(UIColor(hex: 0xF8C3E0))
    static let rosaOsc = Color(UIColor(hex: 0xE487C0))
    static let rosaTinta = Color(UIColor(hex: 0xA3306F))
    static let ciruela = Color(UIColor(hex: 0x9E4A86))
    static let nacar = Color(UIColor(hex: 0xF8F3F6))
    static let noche = Color(UIColor(hex: 0x0C0911))
    static let tintaSec = Color(UIColor(hex: 0x6B5A70))
    static let lineaPapel = Color(UIColor(hex: 0xEADFE5))

    // Estados
    static let ok = d(0x9FE3C0, 0x1B7F53)
    static let alerta = d(0xFFC48A, 0x9A5A06)
    static let error = d(0xFF9B9B, 0xBE2F47)
    static let okSuave = d(0x9FE3C0, 0x1B7F53, ao: 0.12, ac: 0.10)
    static let alertaSuave = d(0xFFC48A, 0x9A5A06, ao: 0.12, ac: 0.10)
    static let errorSuave = d(0xFF9B9B, 0xBE2F47, ao: 0.12, ac: 0.09)

    /// Barra de pestañas y hojas flotantes (noche al 88 %).
    static let velo = d(0x0C0911, 0xF8F3F6, ao: 0.88, ac: 0.9)
}

/// Tonos de los avatares (.av.r/.c/.v/.m del diseño).
enum Tono: String, Codable, Hashable, CaseIterable {
    case rosa, cobre, violeta, menta, neutro

    var fondo: Color {
        switch self {
        case .rosa: return .acentoSuave
        case .cobre: return Color(UIColor.dinamico(0x2B1E2A, 0xF6E6DA))
        case .violeta: return Color(UIColor.dinamico(0x211F33, 0xE9E6FA))
        case .menta: return Color(UIColor.dinamico(0x1C2A26, 0xDDF1E8))
        case .neutro: return .sup3
        }
    }

    var frente: Color {
        switch self {
        case .rosa: return .acento
        case .cobre: return Color(UIColor.dinamico(0xF2C9A5, 0x8A4B1E))
        case .violeta: return Color(UIColor.dinamico(0xC9C2FF, 0x4B3FB0))
        case .menta: return Color(UIColor.dinamico(0xA9E5CF, 0x1D6B50))
        case .neutro: return .texto
        }
    }
}

/// Degradé del botón principal (#F8C3E0 → rosa).
extension LinearGradient {
    static let botonRosa = LinearGradient(colors: [.rosaClaro, .rosa], startPoint: .top, endPoint: .bottom)
    static let barraRosa = LinearGradient(colors: [.rosaOsc, .rosa2], startPoint: .leading, endPoint: .trailing)
}
