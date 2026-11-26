import SwiftUI

/// Alta de la cuenta: celular (0), DNI frente (1) y dorso (2), selfie (3, pantalla 04), tu negocio (4) y lista (5).
/// Todo simulado: el código llega solo, la cámara es una maqueta y RENAPER contesta a los dos segundos.
struct Alta: View {
    var paso: Int = 0
    var alVolver: () -> Void
    var alTerminar: () -> Void

    @State private var actual: Int
    @State private var avanzando = true
    @State private var ayuda = false
    @Environment(Estado.self) private var estado

    init(paso: Int = 0, alVolver: @escaping () -> Void, alTerminar: @escaping () -> Void) {
        self.paso = paso
        self.alVolver = alVolver
        self.alTerminar = alTerminar
        _actual = State(initialValue: min(max(paso, 0), 5))
    }

    /// Paso de la barra de tres: celular, identidad, tu negocio.
    private var etapa: Int { actual == 0 ? 1 : actual <= 3 ? 2 : 3 }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.35), tamanoBrillo: 420)
            VStack(spacing: 0) {
                if actual < 5 {
                    Cabecera("Abrí tu cuenta") {
                        Redondo("chevron.left", "Volver") { atras() }
                    } derecha: {
                        Redondo("questionmark.circle", "Ayuda") { ayuda = true }
                    }
                    BarraEtapas(etapa: etapa).padding(.horizontal, 20).padding(.top, 4)
                }
                contenido
                    .id(actual)
                    .transition(.asymmetric(
                        insertion: .move(edge: avanzando ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: avanzando ? .leading : .trailing).combined(with: .opacity)))
            }
        }
        .sheet(isPresented: $ayuda) { ChatPantalla().environment(estado) }
    }

    @ViewBuilder private var contenido: some View {
        switch actual {
        case 0: PasoCelular { siguiente() }
        case 1: PasoDNI(lado: .frente) { siguiente() }
        case 2: PasoDNI(lado: .dorso) { siguiente() }
        case 3: PasoSelfie { siguiente() }
        case 4: PasoNegocio { siguiente() }
        default: PasoLista(alTerminar: alTerminar)
        }
    }

    private func siguiente() {
        avanzando = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { actual = min(actual + 1, 5) }
    }

    private func atras() {
        if actual == 0 { alVolver(); return }
        avanzando = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { actual -= 1 }
    }
}

/// Tres segmentos de 4 pt.
private struct BarraEtapas: View {
    let etapa: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                Capsule().fill(i <= etapa ? Color.acento : Color.linea2).frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: etapa)
        .accessibilityElement()
        .accessibilityLabel("Paso \(etapa) de 3")
    }
}

/// Encabezado de cada paso: rótulo rosa y título.
private struct EncabezadoPaso: View {
    let rotulo: String
    let titulo: String
    var texto: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rotulo).rotulo(.acento)
            Titulo(titulo, tamano: 24)
            if let texto { Text(texto).parrafo(15) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La letra chica con candado (cómo usamos los datos).
private struct LetraChica: View {
    let texto: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock").font(.system(size: 13)).foregroundStyle(Color.acento).padding(.top, 1)
            Text(texto).font(.geist(12)).foregroundStyle(Color.sec).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 0 · Celular

private struct PasoCelular: View {
    var listo: () -> Void
    @State private var numero = ""
    @State private var codigo = ""
    @State private var enviado = false
    @State private var verificando = false
    @FocusState private var foco: Bool

    private var completo: Bool { numero.filter(\.isNumber).count == 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    EncabezadoPaso(rotulo: "Paso 1 de 3 · Celular",
                                   titulo: enviado ? "Te mandamos un código." : "¿A qué celular te escribimos?",
                                   texto: enviado ? "Llega por SMS al " + visible + ". Lo completamos solo." : "Es tu usuario y por donde te avisamos de cada movimiento.")
                    if enviado { cajasCodigo } else { campoNumero }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                if enviado {
                    Button("Reenviar código") { Haptico.tocar(); codigo = ""; autocompletar() }
                        .buttonStyle(.textoRosa)
                        .disabled(verificando)
                } else {
                    Button("Mandar código") {
                        Haptico.firme()
                        foco = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { enviado = true }
                        autocompletar()
                    }
                    .buttonStyle(.principal)
                    .disabled(!completo)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onAppear { if !enviado { foco = true } }
    }

    private var visible: String {
        let d = Array(numero.filter(\.isNumber))
        guard d.count == 10 else { return numero }
        return "+54 " + String(d[0..<2]) + " " + String(d[2..<6]) + "-" + String(d[6..<10])
    }

    private var campoNumero: some View {
        HStack(spacing: 10) {
            Text("+54").font(.geist(17, .medio)).foregroundStyle(Color.sec)
                .padding(.horizontal, 14).frame(height: 56).caja(radio: 16)
            TextField("11 5555 0142", text: $numero)
                .font(.geist(19, .medio))
                .monospacedDigit()
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .focused($foco)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .caja(radio: 16, seleccionada: foco)
                .onChange(of: numero) { _, n in
                    let d = String(n.filter(\.isNumber).prefix(10))
                    if d != n { numero = d }
                }
                .accessibilityLabel("Número de celular, sin el 0 ni el 15")
        }
    }

    private var cajasCodigo: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let c = Array(codigo)
                    Text(i < c.count ? String(c[i]) : "")
                        .font(.geistFijo(24, .semi))
                        .foregroundStyle(Color.texto)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .caja(radio: 14, seleccionada: i == c.count && !verificando)
                        .scaleEffect(i == c.count - 1 ? 1.04 : 1)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Código de 6 dígitos")
            if verificando {
                Etiqueta(texto: "Verificando", tipo: .rosa, girando: true)
            } else {
                Text("Llegó por SMS. Lo pegamos por vos.").font(.geist(13)).foregroundStyle(Color.sec)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: codigo)
    }

    private func autocompletar() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            for d in "482915" {
                try? await Task.sleep(for: .milliseconds(110))
                codigo.append(d)
                Haptico.seleccion()
            }
            verificando = true
            try? await Task.sleep(for: .milliseconds(700))
            Haptico.exito()
            verificando = false
            listo()
        }
    }
}

// MARK: - 1 y 2 · DNI

private enum LadoDNI { case frente, dorso }

/// Las tres fichas de identidad: DNI frente, dorso y selfie.
private struct FichasIdentidad: View {
    /// 0 frente, 1 dorso, 2 selfie.
    let actual: Int
    var body: some View {
        HStack(spacing: 8) {
            ficha(0, "DNI frente", "person.text.rectangle")
            ficha(1, "DNI dorso", "barcode")
            ficha(2, "Selfie", "faceid")
        }
    }

    private func ficha(_ i: Int, _ titulo: String, _ simbolo: String) -> some View {
        let hecho = i < actual
        let ahora = i == actual
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: hecho ? "checkmark" : simbolo)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(hecho ? Color.ok : ahora ? Color.acento : Color.sec)
                .frame(height: 18)
            Text(titulo).font(.geist(13, .medio)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.8)
            Text(hecho ? "Listo" : ahora ? "Ahora" : "Después").font(.geist(12)).foregroundStyle(Color.sec)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .caja(radio: 14, seleccionada: ahora)
        .accessibilityElement(children: .combine)
    }
}

private struct PasoDNI: View {
    let lado: LadoDNI
    var listo: () -> Void
    @State private var fase = 0 // 0 apuntando, 1 foto, 2 leyendo, 3 listo
    @State private var barrido = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    EncabezadoPaso(rotulo: "Paso 2 de 3 · Identidad",
                                   titulo: lado == .frente ? "Una foto al frente de tu DNI." : "Ahora, el dorso del DNI.")
                    FichasIdentidad(actual: lado == .frente ? 0 : 1)
                    visor
                    HStack(spacing: 18) {
                        Label("Buena luz", systemImage: "sun.max")
                        Label("Sin reflejos", systemImage: "rectangle.dashed")
                    }
                    .font(.geist(13)).foregroundStyle(Color.sec)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            VStack(spacing: 12) {
                LetraChica(texto: "Validamos tu DNI con RENAPER. Lo guarda el proveedor de la cuenta, cifrado, como pide la ley.")
                Button {
                    sacar()
                } label: {
                    Label(fase == 0 ? "Sacar la foto" : fase == 3 ? "Listo" : "Leyendo el DNI…", systemImage: fase == 3 ? "checkmark" : "camera")
                }
                .buttonStyle(.principal)
                .disabled(fase != 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    /// La cámara simulada: el DNI dibujado sobre la mesa, el marco rosa y el barrido.
    private var visor: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0x2A2230)), Color(UIColor(hex: 0x120E16))], startPoint: .top, endPoint: .bottom))
            DNIDibujo(lado: lado)
                .frame(width: 250, height: 158)
                .rotationEffect(.degrees(fase >= 1 ? 0 : -3))
                .scaleEffect(fase >= 1 ? 1 : 0.96)
            MarcoEsquinas()
                .stroke(fase == 3 ? Color.ok : Color.rosa, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 272, height: 180)
            if fase == 2 || fase == 0 {
                LinearGradient(colors: [.clear, .rosa, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 240, height: 2)
                    .shadow(color: .rosa.opacity(0.7), radius: 8)
                    .offset(y: barrido ? 70 : -70)
            }
            if fase == 1 { Color.white.opacity(0.85).transition(.opacity) }
            if fase == 3 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(Color.ok)
                    .background(Circle().fill(Color.noche).padding(4))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.linea, lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { barrido = true } }
        .accessibilityElement()
        .accessibilityLabel(fase == 3 ? "DNI leído" : "Cámara: encuadrá el DNI dentro del marco")
    }

    private func sacar() {
        Haptico.firme()
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.08)) { fase = 1 }
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.easeOut(duration: 0.3)) { fase = 2 }
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { fase = 3 }
            Haptico.exito()
            try? await Task.sleep(for: .milliseconds(650))
            listo()
        }
    }
}

/// Un DNI argentino esquemático (sin datos reales).
private struct DNIDibujo: View {
    let lado: LadoDNI
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(UIColor(hex: 0xDCE6EE)), Color(UIColor(hex: 0xC9D6E2))], startPoint: .topLeading, endPoint: .bottomTrailing))
            if lado == .frente {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(UIColor(hex: 0x9FB1C2))).frame(width: 62, height: 78)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 34)).foregroundStyle(Color(UIColor(hex: 0xE7EEF4))))
                    VStack(alignment: .leading, spacing: 7) {
                        renglon(120); renglon(90); renglon(140); renglon(70); renglon(100)
                    }
                }
                .padding(14)
                .padding(.top, 16)
                renglon(80).padding(14)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 1.5) {
                        ForEach(0..<46, id: \.self) { i in
                            Rectangle().fill(Color(UIColor(hex: 0x3B4652))).frame(width: i % 3 == 0 ? 2.5 : 1.2, height: 34)
                        }
                    }
                    Spacer()
                    Text("IDARG<<<<<<<<<<<<<<<<<<<<<<<").font(.mono(9)).foregroundStyle(Color(UIColor(hex: 0x3B4652)))
                    Text("<<<<<<<<<<<<<<<<<<<<<<<<<<<<").font(.mono(9)).foregroundStyle(Color(UIColor(hex: 0x3B4652)))
                }
                .padding(14)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
    }

    private func renglon(_ w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(Color(UIColor(hex: 0x8DA0B3))).frame(width: w, height: 6)
    }
}

/// Las cuatro esquinas del marco de la cámara.
struct MarcoEsquinas: Shape {
    var largo: CGFloat = 30
    var radio: CGFloat = 18
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = largo, c = radio
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

// MARK: - 3 · Selfie (pantalla 04)

private struct PasoSelfie: View {
    var listo: () -> Void
    @State private var fase = 0 // 0 lista para sacar, 1 validando, 2 validada
    @State private var aro: CGFloat = 0.06

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EncabezadoPaso(rotulo: "Paso 2 de 3 · Identidad", titulo: "Ahora, una selfie.")
                    FichasIdentidad(actual: 2).padding(.top, 18)
                    ovalo.padding(.top, 22).frame(maxWidth: .infinity)
                    estadoValidacion.padding(.top, 16).frame(maxWidth: .infinity)
                    HStack(spacing: 18) {
                        Label("Buena luz", systemImage: "waveform.path.ecg")
                        Label("Cara despejada", systemImage: "faceid")
                    }
                    .font(.geist(13)).foregroundStyle(Color.sec)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            VStack(spacing: 12) {
                LetraChica(texto: "Usamos tu selfie sólo para validar tu identidad con RENAPER y la borramos al terminar.")
                Button { sacar() } label: {
                    Label(fase == 0 ? "Sacar la selfie" : fase == 1 ? "Validando…" : "Identidad validada",
                          systemImage: fase == 2 ? "checkmark" : "camera")
                }
                .buttonStyle(.principal)
                .disabled(fase != 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var ovalo: some View {
        ZStack {
            Image("selfie").resizable().scaledToFill()
                .frame(width: 202, height: 262)
                .clipShape(Ellipse())
                .saturation(0.9)
            Ellipse().stroke(Color.linea2, lineWidth: 3).frame(width: 224, height: 284)
            Ellipse()
                .trim(from: 0, to: aro)
                .stroke(fase == 2 ? Color.ok : Color.rosa, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90 + 22))
                .frame(width: 224, height: 284)
        }
        .frame(width: 230, height: 290)
        .accessibilityElement()
        .accessibilityLabel("Tu cara dentro del óvalo")
    }

    @ViewBuilder private var estadoValidacion: some View {
        switch fase {
        case 1: Etiqueta(texto: "Validando con RENAPER", tipo: .rosa, girando: true).transition(.opacity)
        case 2: Etiqueta(texto: "Identidad validada", simbolo: "checkmark", tipo: .ok).transition(.opacity)
        default: Etiqueta(texto: "Mirá a la cámara", simbolo: "camera", tipo: .neutra)
        }
    }

    private func sacar() {
        Haptico.firme()
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.25)) { fase = 1 }
            withAnimation(.easeInOut(duration: 2.0)) { aro = 1 }
            try? await Task.sleep(for: .milliseconds(2100))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { fase = 2 }
            Haptico.exito()
            try? await Task.sleep(for: .milliseconds(800))
            listo()
        }
    }
}

// MARK: - 4 · Tu negocio

private struct PasoNegocio: View {
    var listo: () -> Void
    @State private var nombre = ""
    @State private var rubro = ""
    @State private var acepto = false
    @State private var abriendo = false
    @FocusState private var foco: Bool

    private let rubros = ["Peluquería y estética", "Oficios", "Gastronomía", "Comercio", "Profesional", "Otro"]
    private var puede: Bool { nombre.trimmingCharacters(in: .whitespaces).count >= 2 && !rubro.isEmpty && acepto }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    EncabezadoPaso(rotulo: "Paso 3 de 3 · Tu negocio", titulo: "¿Cómo se llama lo tuyo?",
                                   texto: "Es el nombre que ve quien te paga en el QR y en el link.")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre del negocio").rotulo()
                        TextField("Ej.: Estudio Carla", text: $nombre)
                            .font(.geist(17, .medio))
                            .textInputAutocapitalization(.words)
                            .focused($foco)
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .caja(radio: 16, seleccionada: foco)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rubro").rotulo()
                        RubrosGrilla(rubros: rubros, elegido: $rubro)
                    }
                    cuit
                    terminos
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            Button {
                abrir()
            } label: {
                if abriendo { ProgressView().tint(Color.noche) } else { Text("Abrir mi cuenta") }
            }
            .buttonStyle(.principal)
            .disabled(!puede || abriendo)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var cuit: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield").font(.system(size: 18)).foregroundStyle(Color.ok)
            VStack(alignment: .leading, spacing: 2) {
                Text("CUIT").font(.geist(12, .medio)).foregroundStyle(Color.sec)
                Text("20-36123456-5").font(.mono(14)).foregroundStyle(Color.texto)
            }
            Spacer()
            Text("De RENAPER").font(.geist(12)).foregroundStyle(Color.sec)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .caja(radio: 16)
        .accessibilityElement(children: .combine)
    }

    private var terminos: some View {
        Button {
            Haptico.seleccion()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { acepto.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: acepto ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(acepto ? Color.acento : Color.ter)
                Text("Acepto los términos de Cuarzo y del proveedor de la cuenta, y la política de privacidad.")
                    .font(.geist(13)).foregroundStyle(Color.sec).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(acepto ? .isSelected : [])
    }

    private func abrir() {
        Haptico.firme()
        foco = false
        abriendo = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            abriendo = false
            listo()
        }
    }
}

private struct RubrosGrilla: View {
    let rubros: [String]
    @Binding var elegido: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(rubros, id: \.self) { r in
                let on = elegido == r
                Button {
                    Haptico.seleccion()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { elegido = r }
                } label: {
                    Text(r).font(.geist(14, .medio)).foregroundStyle(on ? Color.texto : Color.sec)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .caja(radio: 14, seleccionada: on)
                }
                .buttonStyle(Presionable())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

// MARK: - 5 · Lista

private struct PasoLista: View {
    var alTerminar: () -> Void
    @State private var visible = false
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            CristalExito(tamano: 76)
            VStack(spacing: 10) {
                Titulo("Tu cuenta ya está abierta.", tamano: 30, centrado: true)
                Text("Ya podés recibir plata y cobrar con QR.").parrafo(15).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            VStack(spacing: 0) {
                dato("Alias", "juan.paredes.cz")
                Separador()
                dato("CVU", "0000003100067812340012")
            }
            .padding(.horizontal, 16)
            .caja()
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .opacity(visible ? 1 : 0)
            LeyendaPSP().padding(.top, 14).opacity(visible ? 1 : 0)
            Spacer()
            Button("Entrar a Cuarzo") { Haptico.firme(); alTerminar() }
                .buttonStyle(.principal)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .opacity(visible ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { visible = true }
        }
    }

    private func dato(_ k: String, _ v: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(k).font(.geist(12, .medio)).foregroundStyle(Color.sec)
                Text(v).font(.mono(13)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Button {
                copiar(v, aviso: k + " copiado", estado: estado)
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 17)).foregroundStyle(Color.acento).frame(width: 44, height: 44)
            }
            .buttonStyle(Presionable(escala: 0.9))
            .accessibilityLabel("Copiar " + k)
        }
        .frame(minHeight: 56)
    }
}
