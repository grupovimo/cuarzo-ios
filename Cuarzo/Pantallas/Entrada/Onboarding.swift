import SwiftUI

/// Bienvenida en tres pantallas (01-03): bolsillos, cobrar sin costo y una persona que contesta.
/// `alTerminar(false)`: abrir la cuenta. `alTerminar(true)`: ya tengo cuenta.
struct Onboarding: View {
    var paso: Int = 0
    var alTerminar: (Bool) -> Void
    @State private var actual: Int

    init(paso: Int = 0, alTerminar: @escaping (Bool) -> Void) {
        self.paso = paso
        self.alTerminar = alTerminar
        _actual = State(initialValue: min(max(paso, 0), 2))
    }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.3), tamanoBrillo: 500)
            VStack(spacing: 0) {
                encabezado
                TabView(selection: $actual) {
                    ForEach(0..<3, id: \.self) { i in
                        SlideBienvenida(indice: i, activo: actual == i).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: actual) { _, _ in Haptico.seleccion() }
                pie
            }
        }
    }

    private var encabezado: some View {
        HStack {
            LogoCuarzo(alto: 24)
            Spacer()
            Button("Saltar") {
                Haptico.tocar()
                alTerminar(false)
            }
            .font(.geist(15, .medio))
            .foregroundStyle(Color.sec)
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: 12) {
            Puntos(total: 3, actual: actual)
                .padding(.bottom, 10)
            Button("Abrir mi cuenta") { Haptico.firme(); alTerminar(false) }
                .buttonStyle(.principal)
            Button("Ya tengo cuenta") { Haptico.tocar(); alTerminar(true) }
                .buttonStyle(.secundario)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// El logotipo horizontal que corresponde a la apariencia.
struct LogoCuarzo: View {
    var alto: CGFloat = 24
    @Environment(\.colorScheme) private var esquema
    var body: some View {
        Image(esquema == .dark ? "horizontal-noche" : "horizontal-claro")
            .resizable().scaledToFit()
            .frame(height: alto)
            .accessibilityLabel("cuarzo")
    }
}

/// Dibuja un lienzo de tamaño fijo (el del diseño, 390 × alto) escalado para que entre en el lugar que haya.
struct LienzoEscalado<Contenido: View>: View {
    var ancho: CGFloat = 390
    var alto: CGFloat
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        GeometryReader { g in
            let s = min(1, g.size.width / ancho, g.size.height / alto)
            contenido()
                .frame(width: ancho, height: alto)
                .scaleEffect(s)
                .frame(width: g.size.width, height: g.size.height)
        }
    }
}

private struct SlideBienvenida: View {
    let indice: Int
    let activo: Bool

    private var rotulo: String { ["Para el que labura y cobra", "Cobrar", "Seguridad"][indice] }
    private var titulo: String { ["Lo del laburo, aparte.", "Cobrar no cuesta nada.", "Te contesta una persona."][indice] }
    private var texto: String {
        [
            "Una cuenta con dos bolsillos: el del negocio y el tuyo.",
            "Entre cuentas Cuarzo, ni hoy ni después. QR y link para cobrarle a cualquiera.",
            "Si frenamos algo, te decimos por qué, qué falta y hasta cuándo.",
        ][indice]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LienzoEscalado(alto: 372) {
                switch indice {
                case 0: VisualBolsillos(activo: activo)
                case 1: VisualCobrar(activo: activo)
                default: VisualCharla(activo: activo)
                }
            }
            .frame(maxHeight: 372)
            .layoutPriority(-1)
            VStack(alignment: .leading, spacing: 12) {
                Text(rotulo).rotulo(.acento)
                Titulo(titulo, tamano: 36)
                Text(texto).parrafo(15)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// 01: la tarjeta de vidrio en perspectiva, dos esquirlas y los dos bolsillos.
private struct VisualBolsillos: View {
    let activo: Bool
    @State private var flota = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("cristal-a").resizable().scaledToFit().frame(width: 70)
                .rotationEffect(.degrees(12))
                .offset(x: 390 - 30 - 70, y: 8 + (flota ? -6 : 4))
            Image("tarjeta-vidrio-frente").resizable().scaledToFit().frame(width: 330)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .rotation3DEffect(.degrees(14), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                .rotation3DEffect(.degrees(flota ? -14 : -20), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                .rotationEffect(.degrees(-9))
                .shadow(color: .black.opacity(0.55), radius: 40, y: 30)
                .shadow(color: .rosa.opacity(0.3), radius: 35)
                .offset(x: 30, y: 40 + (flota ? -4 : 4))
            Image("cristal-b").resizable().scaledToFit().frame(width: 52)
                .rotationEffect(.degrees(-18))
                .offset(x: 36, y: 372 - 80 - 68 + (flota ? 6 : -4))
            HStack(spacing: 10) {
                bolsillo("Negocio", 84_215_000, rosa: true)
                bolsillo("Personal", 21_348_000, rosa: false)
            }
            .padding(.horizontal, 24)
            .frame(width: 390)
            .offset(y: 372 - 6 - 70)
        }
        .frame(width: 390, height: 372, alignment: .topLeading)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { flota = true }
        }
        .accessibilityHidden(true)
    }

    private func bolsillo(_ nombre: String, _ c: Centavos, rosa: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(nombre).rotulo(rosa ? .acento : .sec)
            MontoChico(centavos: c, tamano: 19, conCentavos: false)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 70)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.sup.opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
    }
}

/// 02: el QR de vidrio y dos avisos de cobro que flotan.
private struct VisualCobrar: View {
    let activo: Bool
    @State private var flota = false
    @State private var visibles = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Icono3D(nombre: "ic-qr", tamano: 250)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 26)
                .offset(x: 70, y: 20 + (flota ? -5 : 5))
            AvisoCobro(iniciales: "MR", tono: .rosa, titulo: "Te entró $\u{00A0}15.000", detalle: "Seña de Martina · Negocio")
                .offset(x: 18, y: 236 + (flota ? 3 : -3))
                .opacity(visibles ? 1 : 0)
                .offset(x: visibles ? 0 : -30)
            HStack {
                Spacer()
                AvisoCobro(iniciales: "LF", tono: .violeta, titulo: "$\u{00A0}32.000 por QR", detalle: "Comisión: $\u{00A0}0")
            }
            .padding(.trailing, 18)
            .frame(width: 390)
            .offset(y: 304 + (flota ? -3 : 3))
            .opacity(visibles ? 1 : 0)
            .offset(x: visibles ? 0 : 30)
        }
        .frame(width: 390, height: 372, alignment: .topLeading)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { flota = true }
            mostrar()
        }
        .onChange(of: activo) { _, v in if v { visibles = false; mostrar() } }
        .accessibilityHidden(true)
    }

    private func mostrar() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25)) { visibles = true }
    }
}

private struct AvisoCobro: View {
    let iniciales: String
    let tono: Tono
    let titulo: String
    let detalle: String

    var body: some View {
        HStack(spacing: 10) {
            Avatar(iniciales: iniciales, tono: tono, tamano: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.geistFijo(14, .semi)).monospacedDigit().tracking(-0.14).foregroundStyle(Color.texto)
                Text(detalle).font(.geistFijo(12)).foregroundStyle(Color.sec)
            }
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.sup2.opacity(0.86)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
        .fixedSize()
    }
}

/// 03: el escudo de vidrio y la charla con el equipo, que aparece de a una burbuja.
private struct VisualCharla: View {
    let activo: Bool
    @State private var paso = 0
    @State private var flota = false

    var body: some View {
        ZStack(alignment: .top) {
            Icono3D(nombre: "ic-escudo", tamano: 200)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 26)
                .offset(y: flota ? -4 : 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 60)
                    Text("¿Por qué no salió mi transferencia?")
                        .font(.geistFijo(14.5, .medio))
                        .foregroundStyle(Color.noche)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(BurbujaForma(propia: true).fill(Color.rosa))
                }
                .opacity(paso >= 1 ? 1 : 0)
                .offset(y: paso >= 1 ? 0 : 12)
                HStack(spacing: 8) {
                    Circle().fill(Color.ok).frame(width: 8, height: 8)
                    Text(paso >= 3 ? "Equipo de Cuarzo · respondió en 4 min" : "Equipo de Cuarzo · escribiendo…")
                        .font(.geistFijo(12)).foregroundStyle(Color.sec)
                        .contentTransition(.opacity)
                }
                .opacity(paso >= 2 ? 1 : 0)
                Text("Falta el dorso de tu DNI. Subilo y sale hoy mismo.")
                    .font(.geistFijo(14.5))
                    .foregroundStyle(Color.texto)
                    .lineSpacing(2)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: 290, alignment: .leading)
                    .background(BurbujaForma(propia: false).fill(Color.sup2.opacity(0.92)))
                    .overlay(BurbujaForma(propia: false).stroke(Color.acentoBorde, lineWidth: 1))
                    .opacity(paso >= 3 ? 1 : 0)
                    .offset(y: paso >= 3 ? 0 : 12)
            }
            .padding(.horizontal, 20)
            .offset(y: 196)
        }
        .frame(width: 390, height: 372, alignment: .top)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { flota = true }
            if activo { animar() }
        }
        .onChange(of: activo) { _, v in if v { paso = 0; animar() } }
        .accessibilityHidden(true)
    }

    private func animar() {
        Task { @MainActor in
            for p in 1...3 {
                try? await Task.sleep(for: .milliseconds(p == 3 ? 900 : 350))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { paso = p }
            }
        }
    }
}

/// Burbuja de charla con la esquina de abajo del lado de quien habla más cerrada.
struct BurbujaForma: Shape {
    var propia: Bool
    func path(in r: CGRect) -> Path {
        let radios = propia
            ? RectangleCornerRadii(topLeading: 18, bottomLeading: 18, bottomTrailing: 6, topTrailing: 18)
            : RectangleCornerRadii(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18)
        return UnevenRoundedRectangle(cornerRadii: radios, style: .continuous).path(in: r)
    }
}
