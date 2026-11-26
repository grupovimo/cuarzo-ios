import SwiftUI

/// Pedir la tarjeta física, como carrito: diseño, envío, ticket «Hoy pagás $ 0» y listo.
struct PedirTarjetaFlujo: View {
    enum Paso: Int { case diseno, envio, resumen, listo }

    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso
    @State private var diseno: DisenoTarjeta = .vidrio
    @State private var calle = "Gorriti 4870"
    @State private var piso = "2.º B"
    @State private var barrio = "Palermo, CABA"
    @State private var cp = "C1414"
    @State private var recibe = ""
    @State private var enviando = false
    @State private var error: String?
    @State private var adelante = true

    init(paso: Int = 0) {
        _paso = State(initialValue: Paso(rawValue: paso) ?? .diseno)
    }

    private var llega: Date { diasHabiles(5) }
    private var direccionCompleta: String {
        [calle, piso].filter { !$0.isEmpty }.joined(separator: " ") + " · " + barrio
    }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.22), tamanoBrillo: 480)
            VStack(spacing: 0) {
                if paso != .listo {
                    CabeceraCerrar("Tu tarjeta física", atras: paso == .diseno ? nil : { ir(-1) })
                    PasosSegmentos(total: 3, actual: paso.rawValue)
                        .padding(.horizontal, 20)
                }
                Group {
                    switch paso {
                    case .diseno: pasoDiseno
                    case .envio: pasoEnvio
                    case .resumen: pasoResumen
                    case .listo: pasoListo
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: adelante ? .trailing : .leading).combined(with: .opacity),
                                        removal: .opacity))
            }
        }
        .onAppear { if recibe.isEmpty { recibe = estado.usuario.nombreCompleto } }
    }

    private func ir(_ d: Int) {
        Haptico.tocar()
        adelante = d > 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            paso = Paso(rawValue: paso.rawValue + d) ?? paso
        }
    }

    // MARK: Diseño

    private var pasoDiseno: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paso 1 de 3 · Diseño").rotulo(.acento).padding(.top, 18)
                    Titulo("Elegí cómo la querés.", tamano: 26).padding(.top, 10)
                    TarjetaGrande(diseno: diseno, titular: estado.usuario.nombreCompleto.uppercased())
                        .padding(.top, 22)
                    HStack(spacing: 10) {
                        ForEach([DisenoTarjeta.vidrio, .rosa, .noche]) { d in
                            OpcionDiseno(diseno: d, on: d == diseno) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { diseno = d }
                            }
                        }
                    }
                    .padding(.top, 22)
                    Text("Todas son de débito, sin costo y con contactless.").parrafo(13).padding(.top, 14)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            Button("Seguir") { ir(1) }
                .buttonStyle(.principal)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: Envío

    private var pasoEnvio: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paso 2 de 3 · Envío").rotulo(.acento).padding(.top, 18)
                    Titulo("¿A dónde te la mandamos?", tamano: 26).padding(.top, 10)
                    VStack(spacing: 10) {
                        CampoRotulado(titulo: "Calle y número", texto: $calle)
                        HStack(spacing: 10) {
                            CampoRotulado(titulo: "Piso y depto.", texto: $piso)
                            CampoRotulado(titulo: "Código postal", texto: $cp).frame(width: 130)
                        }
                        CampoRotulado(titulo: "Barrio y ciudad", texto: $barrio)
                        CampoRotulado(titulo: "La recibe", texto: $recibe)
                    }
                    .padding(.top, 20)
                    HStack(spacing: 10) {
                        Image(systemName: "person.text.rectangle").foregroundStyle(Color.acento)
                        Text("Quien la reciba tiene que mostrar su DNI.").font(.geist(13)).foregroundStyle(Color.sec)
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            Button("Seguir") { ir(1) }
                .buttonStyle(.principal)
                .disabled(calle.trimmingCharacters(in: .whitespaces).count < 4 || recibe.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: Resumen (el carrito)

    private var pasoResumen: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paso 3 de 3 · Resumen").rotulo(.acento).padding(.top, 18)
                    Titulo("Revisá y pedila.", tamano: 26).padding(.top, 10)
                    HStack(spacing: 14) {
                        Image(diseno.frente).resizable().aspectRatio(proporcionTarjeta, contentMode: .fit)
                            .frame(width: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .shadow(color: .rosa.opacity(0.3), radius: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tarjeta física · " + diseno.nombre).font(.geist(16, .semi)).foregroundStyle(Color.texto)
                            Text("Débito · contactless").font(.geist(13)).foregroundStyle(Color.sec)
                        }
                    }
                    .padding(.top, 20)
                    ticket.padding(.top, 16)
                    Text("Se emite a tu nombre y se asocia a tu bolsillo Personal. Si la perdés, la congelás desde la app y pedís otra. Al pedirla aceptás los términos del socio emisor.")
                        .parrafo(12).padding(.top, 14)
                    if let error {
                        Text(error).font(.geist(13, .medio)).foregroundStyle(Color.error).padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            Button { Task { await pedir() } } label: {
                HStack(spacing: 8) {
                    if enviando { ProgressView().tint(.noche) } else { Image(systemName: "faceid") }
                    Text(enviando ? "Pidiéndola…" : "Pedir mi tarjeta")
                }
            }
            .buttonStyle(.principal)
            .disabled(enviando)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 8)
            RenglonTicket(etiqueta: "Emisión", valor: "$\u{00A0}0").padding(.horizontal, 18)
            RenglonTicket(etiqueta: "Envío a domicilio", valor: "Gratis").padding(.horizontal, 18)
            RenglonTicket(etiqueta: "Llega", valor: Fecha.larga(llega), sub: "5 días hábiles").padding(.horizontal, 18)
            RenglonTicket(etiqueta: "A", valor: direccionCompleta, sub: "Recibe " + recibe).padding(.horizontal, 18)
            RenglonTicket(etiqueta: "Mantenimiento", valor: "$\u{00A0}0 por mes").padding(.horizontal, 18)
            CorteTicket()
            HStack(alignment: .bottom) {
                Text("Hoy pagás").rotulo(.acento)
                Spacer()
                Monto(centavos: 0, tamano: 38)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 18)
        }
        .caja()
    }

    private func pedir() async {
        error = nil
        guard await estado.pedirFaceID("Para pedir tu tarjeta") else { return }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.pedirFisica(diseno: diseno, direccion: direccionCompleta)
            ir(1)
        } catch {
            Haptico.error()
            self.error = estado.mensaje(error)
        }
    }

    // MARK: Listo

    private var pasoListo: some View {
        VStack(spacing: 0) {
            Spacer()
            CristalExito(tamano: 72)
            Titulo("Va en camino.", tamano: 32, centrado: true).padding(.top, 8)
            Text("Llega el " + Fecha.larga(llega).lowercased() + ". Te avisamos cuando salga.")
                .parrafo(15).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 10)
            Image(diseno.frente).resizable().aspectRatio(proporcionTarjeta, contentMode: .fit)
                .frame(width: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .rotation3DEffect(.degrees(12), axis: (x: 1, y: -0.6, z: 0.1), perspective: 0.6)
                .shadow(color: .rosa.opacity(0.35), radius: 24, y: 10)
                .padding(.top, 30)
            Spacer()
            Text("Mientras tanto, usá la virtual: ya anda.").font(.geist(13)).foregroundStyle(Color.sec).padding(.bottom, 12)
            Button("Listo") { dismiss() }
                .buttonStyle(.principal)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

/// La tarjeta grande del paso de diseño, con el nombre y un leve vaivén.
private struct TarjetaGrande: View {
    let diseno: DisenoTarjeta
    let titular: String
    @State private var vaiven = false

    var body: some View {
        Image(diseno.frente)
            .resizable()
            .aspectRatio(proporcionTarjeta, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text(titular)
                    .font(.mono(10)).tracking(1.6)
                    .foregroundStyle(diseno == .rosa ? Color.noche.opacity(0.75) : Color.white.opacity(0.8))
                    .padding(.leading, 24).padding(.bottom, 44)
            }
            .rotation3DEffect(.degrees(vaiven ? 5 : -5), axis: (x: 0.2, y: 1, z: 0), perspective: 0.5)
            .shadow(color: .black.opacity(0.5), radius: 26, y: 20)
            .shadow(color: .rosa.opacity(0.3), radius: 30)
            .id(diseno)
            .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
            .onAppear { withAnimation(.easeInOut(duration: 3).repeatForever()) { vaiven = true } }
            .accessibilityLabel("Tarjeta " + diseno.nombre)
    }
}

/// Opción seleccionable de diseño.
private struct OpcionDiseno: View {
    let diseno: DisenoTarjeta
    let on: Bool
    let accion: () -> Void

    var body: some View {
        Button {
            Haptico.seleccion()
            accion()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(diseno.frente).resizable().aspectRatio(proporcionTarjeta, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                HStack {
                    Text(diseno.nombre).font(.geist(14, .semi)).foregroundStyle(Color.texto)
                    Spacer()
                    Circle()
                        .strokeBorder(on ? Color.clear : Color.linea2, lineWidth: 1.5)
                        .background(Circle().fill(on ? Color.rosa : .clear))
                        .overlay(Circle().fill(Color.noche).frame(width: 7, height: 7).opacity(on ? 1 : 0))
                        .frame(width: 18, height: 18)
                }
                Text("Gratis").font(.geist(12)).foregroundStyle(Color.sec)
            }
            .padding(10)
            .caja(radio: 16, seleccionada: on)
        }
        .buttonStyle(Presionable())
        .accessibilityLabel("Diseño " + diseno.nombre)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Barra de pasos (segmentos de 4 pt).
struct PasosSegmentos: View {
    let total: Int
    let actual: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i <= actual ? Color.acento : Color.linea2).frame(height: 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: actual)
        .padding(.top, 4)
        .accessibilityElement()
        .accessibilityLabel("Paso \(min(actual + 1, total)) de \(total)")
    }
}

/// Campo de texto del sistema: rótulo arriba y caja.
struct CampoRotulado: View {
    let titulo: String
    @Binding var texto: String
    var teclado: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.geist(12, .medio)).foregroundStyle(Color.sec)
            TextField(titulo, text: $texto)
                .font(.geist(16))
                .foregroundStyle(Color.texto)
                .keyboardType(teclado)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .caja(radio: 14)
    }
}
