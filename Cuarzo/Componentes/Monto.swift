import SwiftUI

/// El monto grande del sistema: «$» chico arriba, la parte entera en Geist 600 apretada y «,50» chico.
/// Oculto, muestra puntos del mismo ancho aproximado (el ojo del inicio).
struct Monto: View {
    let centavos: Centavos
    var tamano: CGFloat = 40
    var color: Color = .texto
    var oculto = false
    /// nil: centavos si los hay; true: siempre «,00»; false: nunca.
    var conCentavos: Bool? = true
    var signo: Bool = false

    var body: some View {
        let p = Formato.partes(centavos)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if signo && !oculto {
                Text(centavos >= 0 ? "+" : "−")
                    .font(.geistFijo(tamano * 0.6, .medio))
                    .foregroundStyle(Color.sec)
                    .padding(.trailing, tamano * 0.08)
            }
            Text("$")
                .font(.geistFijo(tamano * 0.55, .medio))
                .foregroundStyle(Color.sec)
                .baselineOffset(tamano * 0.34)
                .padding(.trailing, tamano * 0.06)
            if oculto {
                Text("••••••")
                    .font(.geistFijo(tamano * 0.8, .semi))
                    .tracking(tamano * 0.02)
                    .foregroundStyle(color)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text(p.entero)
                    .font(.geistFijo(tamano, .semi))
                    .monospacedDigit()
                    .tracking(-tamano * 0.045)
                    .foregroundStyle(color)
                    .contentTransition(.numericText(value: Double(centavos)))
                if conCentavos ?? (centavos % 100 != 0) {
                    Text(p.centavos)
                        .font(.geistFijo(tamano * 0.5, .medio))
                        .monospacedDigit()
                        .tracking(-tamano * 0.01)
                        .foregroundStyle(Color.sec)
                        .contentTransition(.numericText(value: Double(centavos)))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: centavos)
        .animation(.easeInOut(duration: 0.25), value: oculto)
        .accessibilityElement()
        .accessibilityLabel(oculto ? "Saldo oculto" : Formato.plata(centavos).replacingOccurrences(of: Formato.nbsp, with: " "))
    }
}

/// Monto mediano en una sola línea («$ 842.150,00» con los centavos chicos), para bolsillos y tarjetas.
struct MontoChico: View {
    let centavos: Centavos
    var tamano: CGFloat = 19
    var color: Color = .texto
    var oculto = false
    var conCentavos = true

    var body: some View {
        let p = Formato.partes(centavos)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(oculto ? "$" + Formato.nbsp + "••••" : "$" + Formato.nbsp + p.entero)
                .font(.geistFijo(tamano, .semi)).monospacedDigit().tracking(-tamano * 0.035)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(centavos)))
            if conCentavos && !oculto {
                Text(p.centavos).font(.geistFijo(tamano * 0.68, .medio)).foregroundStyle(Color.sec)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: centavos)
        .accessibilityElement()
        .accessibilityLabel(oculto ? "Oculto" : Formato.plata(centavos).replacingOccurrences(of: Formato.nbsp, with: " "))
    }
}
