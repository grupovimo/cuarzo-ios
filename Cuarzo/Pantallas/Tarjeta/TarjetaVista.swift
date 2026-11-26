import SwiftUI

/// Proporción de las láminas de la marca (1712 × 1080).
let proporcionTarjeta: CGFloat = 1712 / 1080

/// La tarjeta de vidrio en 3D: se inclina con el dedo (con resorte al soltar y un brillo que sigue al dedo),
/// se da vuelta al tocarla y muestra los datos en el dorso cuando se piden con Face ID.
struct TarjetaCuarzo3D: View {
    let tarjeta: Tarjeta
    var mostrarDatos = false
    var interactiva = true
    /// Desde afuera (Ver datos) se la puede dar vuelta.
    @Binding var dorso: Bool
    var alCopiar: (() -> Void)? = nil

    @State private var inclinacion: CGSize = .zero
    @State private var brillo: CGFloat = 0.45
    @GestureState private var arrastrando = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                CaraFrente(tarjeta: tarjeta, ancho: w, brillo: brillo)
                    .opacity(dorso ? 0 : 1)
                CaraDorso(tarjeta: tarjeta, ancho: w, mostrarDatos: mostrarDatos, alCopiar: alCopiar)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(dorso ? 1 : 0)
                if tarjeta.congelada {
                    Escarcha(ancho: w)
                        .transition(.opacity)
                }
            }
            .frame(width: w, height: w / proporcionTarjeta)
            .clipShape(RoundedRectangle(cornerRadius: w * 0.055, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: w * 0.055, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .rotation3DEffect(.degrees(dorso ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double(inclinacion.width) / 9), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double(-inclinacion.height) / 9), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .shadow(color: .black.opacity(0.55), radius: 30, x: -inclinacion.width / 6, y: 24 - inclinacion.height / 6)
            .shadow(color: .rosa.opacity(tarjeta.congelada ? 0.1 : 0.32), radius: 34)
            .gesture(interactiva ? arrastre(ancho: w) : nil)
            .simultaneousGesture(interactiva ? TapGesture().onEnded {
                Haptico.firme()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { dorso.toggle() }
            } : nil)
        }
        .aspectRatio(proporcionTarjeta, contentMode: .fit)
        .animation(.easeInOut(duration: 0.4), value: tarjeta.congelada)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiquetaAccesible)
        .accessibilityHint(interactiva ? "Tocá dos veces para darla vuelta" : "")
        .accessibilityAddTraits(interactiva ? .isButton : [])
    }

    private var etiquetaAccesible: String {
        let base = "Tarjeta \(tarjeta.tipo == .virtual ? "virtual" : "física") terminada en \(tarjeta.ultimos4)"
        return tarjeta.congelada ? base + ", congelada" : base
    }

    private func arrastre(ancho: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                let tope: CGFloat = 110
                inclinacion = CGSize(width: max(-tope, min(tope, v.translation.width)),
                                     height: max(-tope, min(tope, v.translation.height)))
                brillo = max(0, min(1, v.location.x / ancho))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                    inclinacion = .zero
                    brillo = 0.45
                }
            }
    }
}

/// El frente: la lámina del diseño, «•••• 2048» y el reflejo que se mueve.
private struct CaraFrente: View {
    let tarjeta: Tarjeta
    let ancho: CGFloat
    let brillo: CGFloat

    private var tinta: Color { tarjeta.diseno == .rosa ? .noche : Color(UIColor(hex: 0xFBF5F9)) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(tarjeta.diseno.frente)
                .resizable()
                .aspectRatio(proporcionTarjeta, contentMode: .fill)
            LinearGradient(stops: [
                .init(color: .clear, location: max(0, brillo - 0.15)),
                .init(color: .white.opacity(0.2), location: brillo),
                .init(color: .clear, location: min(1, brillo + 0.13)),
            ], startPoint: UnitPoint(x: 0, y: 0.1), endPoint: UnitPoint(x: 1, y: 0.9))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            Text("••••\u{00A0}" + tarjeta.ultimos4)
                .font(.custom("GeistMono-Medium", fixedSize: ancho * 0.044))
                .tracking(ancho * 0.044 * 0.14)
                .foregroundStyle(tinta)
                .padding(.leading, ancho * 0.075)
                .padding(.bottom, ancho / proporcionTarjeta * 0.21)
        }
        .frame(width: ancho, height: ancho / proporcionTarjeta)
        .clipped()
    }
}

/// El dorso: material facetado teñido según el diseño, titular, número, vence y CVV.
private struct CaraDorso: View {
    let tarjeta: Tarjeta
    let ancho: CGFloat
    let mostrarDatos: Bool
    var alCopiar: (() -> Void)?

    private var claro: Bool { tarjeta.diseno == .rosa }
    private var tinta: Color { claro ? .noche : Color(UIColor(hex: 0xFBF5F9)) }
    private var tintaSec: Color { claro ? Color.noche.opacity(0.6) : Color(UIColor(hex: 0xFBF5F9)).opacity(0.65) }

    var body: some View {
        let alto = ancho / proporcionTarjeta
        let f = ancho / 343
        ZStack(alignment: .topLeading) {
            fondo
            VStack(alignment: .leading, spacing: 0) {
                Text(tarjeta.titular)
                    .font(.custom("GeistMono-Medium", fixedSize: 11 * f)).tracking(1.8 * f)
                    .foregroundStyle(tinta)
                    .padding(.top, alto * 0.17)
                Text(mostrarDatos ? tarjeta.numeroEnBloques : "••••  ••••  ••••  " + tarjeta.ultimos4)
                    .font(.custom("GeistMono-Medium", fixedSize: 19 * f)).tracking(1.4 * f)
                    .foregroundStyle(tinta)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.top, 10 * f)
                HStack(alignment: .top, spacing: 34 * f) {
                    dato("Vence", mostrarDatos ? tarjeta.vence : "••/••", f: f)
                    dato("CVV", mostrarDatos ? tarjeta.cvv : "•••", f: f)
                    Spacer()
                    if mostrarDatos, let alCopiar {
                        Button {
                            alCopiar()
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                                .font(.geistFijo(12 * f, .semi))
                                .padding(.horizontal, 10 * f).frame(height: 28 * f)
                                .foregroundStyle(claro ? Color.rosa2 : Color.noche)
                                .background(Capsule().fill(claro ? Color.noche : Color.rosa))
                        }
                        .buttonStyle(Presionable())
                        .accessibilityLabel("Copiar el número de la tarjeta")
                    }
                }
                .padding(.top, 14 * f)
                Spacer()
                HStack(alignment: .bottom) {
                    Text("Emitida por el socio emisor. Si la encontrás,\navisanos en cuarzo.ar/ayuda.")
                        .font(.geistFijo(7.5 * f, .regular))
                        .foregroundStyle(tintaSec)
                    Spacer()
                    Image(claro ? "simbolo-claro" : "simbolo-noche")
                        .resizable().scaledToFit().frame(width: 22 * f)
                }
                .padding(.bottom, alto * 0.08)
            }
            .padding(.horizontal, ancho * 0.075)
        }
        .frame(width: ancho, height: alto)
    }

    @ViewBuilder private var fondo: some View {
        ZStack {
            Image("material-facetas").resizable().aspectRatio(contentMode: .fill)
            switch tarjeta.diseno {
            case .rosa: Color.rosa2.opacity(0.82)
            case .noche: Color.black.opacity(0.35)
            case .vidrio, .virtual: Color(UIColor(hex: 0x3A2440)).opacity(0.55)
            }
        }
        .frame(width: ancho, height: ancho / proporcionTarjeta)
        .clipped()
    }

    private func dato(_ t: String, _ v: String, f: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3 * f) {
            Text(t.uppercased()).font(.custom("GeistMono-Medium", fixedSize: 8 * f)).tracking(1.4 * f).foregroundStyle(tintaSec)
            Text(v).font(.custom("GeistMono-Medium", fixedSize: 14 * f)).foregroundStyle(tinta)
                .contentTransition(.numericText())
        }
    }
}

/// Escarcha sobre la tarjeta congelada: vidrio esmerilado, copos y un borde helado.
private struct Escarcha: View {
    let ancho: CGFloat
    @State private var on = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.85)
            LinearGradient(colors: [Color.white.opacity(0.28), Color(UIColor(hex: 0xCFE6FF)).opacity(0.12), Color.white.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<7, id: \.self) { i in
                Image(systemName: "snowflake")
                    .font(.system(size: ancho * [0.05, 0.035, 0.06, 0.03, 0.045, 0.04, 0.03][i], weight: .light))
                    .foregroundStyle(.white.opacity(0.75))
                    .position(x: ancho * [0.12, 0.3, 0.82, 0.62, 0.9, 0.45, 0.2][i],
                              y: ancho / proporcionTarjeta * [0.2, 0.75, 0.22, 0.12, 0.8, 0.55, 0.45][i])
                    .scaleEffect(on ? 1 : 0.2)
                    .rotationEffect(.degrees(on ? 0 : -60))
                    .opacity(on ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(i) * 0.05), value: on)
            }
            VStack(spacing: 6) {
                Image(systemName: "snowflake").font(.system(size: ancho * 0.09, weight: .light))
                Text("Congelada").font(.geistFijo(ancho * 0.045, .semi))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 6)
            .scaleEffect(on ? 1 : 0.8)
            .opacity(on ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: on)
        }
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}

/// La tarjeta sin pedir: el contorno punteado de una tarjeta y la lámina apenas visible.
struct TarjetaFantasma: View {
    var diseno: DisenoTarjeta = .vidrio
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                Image(diseno.frente).resizable().aspectRatio(proporcionTarjeta, contentMode: .fill)
                    .opacity(0.22)
                    .saturation(0.4)
                RoundedRectangle(cornerRadius: w * 0.055, style: .continuous)
                    .strokeBorder(Color.acento.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                VStack(spacing: 6) {
                    Image(systemName: "shippingbox").font(.system(size: 26, weight: .light)).foregroundStyle(Color.acento)
                    Text("Todavía no la pediste").font(.geist(14, .medio)).foregroundStyle(Color.texto)
                }
            }
            .frame(width: w, height: w / proporcionTarjeta)
            .clipShape(RoundedRectangle(cornerRadius: w * 0.055, style: .continuous))
        }
        .aspectRatio(proporcionTarjeta, contentMode: .fit)
        .accessibilityElement(children: .combine)
    }
}

/// Días hábiles desde hoy (para la fecha de llegada).
func diasHabiles(_ n: Int, desde: Date = .now) -> Date {
    var d = desde
    var faltan = n
    let c = Fecha.calendario
    while faltan > 0 {
        d = c.date(byAdding: .day, value: 1, to: d) ?? d
        let w = c.component(.weekday, from: d)
        if w != 1 && w != 7 { faltan -= 1 }
    }
    return d
}
