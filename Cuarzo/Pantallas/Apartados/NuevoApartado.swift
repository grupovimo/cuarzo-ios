import SwiftUI

/// Una plantilla para arrancar un apartado.
private struct Plantilla: Identifiable, Hashable {
    let id: String
    let nombre: String
    let sugerido: String
    let icono: String
    let objetivo: Centavos
    let dia: Int?
    let regla: ReglaElegida

    static let todas: [Plantilla] = [
        Plantilla(id: "alquiler", nombre: "Alquiler", sugerido: "Alquiler", icono: "ic-llaves", objetivo: 42_000_000, dia: 1, regla: .porcentaje),
        Plantilla(id: "aguinaldo", nombre: "Aguinaldo", sugerido: "Aguinaldo propio", icono: "ic-calendario", objetivo: 48_000_000, dia: 18, regla: .fijo),
        Plantilla(id: "monotributo", nombre: "Monotributo", sugerido: "Monotributo", icono: "ic-escudo", objetivo: 4_239_000, dia: 20, regla: .manual),
        Plantilla(id: "vacaciones", nombre: "Vacaciones", sugerido: "Vacaciones", icono: "ic-monedas", objetivo: 120_000_000, dia: nil, regla: .fijo),
        Plantilla(id: "otro", nombre: "Otro", sugerido: "", icono: "ic-frasco", objetivo: 0, dia: nil, regla: .manual),
    ]
}

/// Crear un apartado en pasos: plantilla, objetivo, cuándo y cómo se llena, resumen y listo.
struct NuevoApartadoFlujo: View {
    enum Paso: Int { case plantilla, objetivo, regla, resumen, listo }

    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso
    @State private var plantilla: Plantilla?
    @State private var nombre = ""
    @State private var objetivo = EntradaMonto()
    @State private var conFecha = true
    @State private var fecha = Fecha.proximo(dia: 1)
    @State private var regla: ReglaElegida = .porcentaje
    @State private var porcentaje = 15
    @State private var fijo: Centavos = 4_000_000
    @State private var bolsillo: Bolsillo = .personal
    @State private var guardando = false
    @State private var error: String?
    @State private var adelante = true
    @FocusState private var enNombre: Bool

    init(paso: Int = 0) {
        _paso = State(initialValue: Paso(rawValue: paso) ?? .plantilla)
        if paso > 0 {
            _plantilla = State(initialValue: Plantilla.todas[0])
            _nombre = State(initialValue: "Alquiler")
            _objetivo = State(initialValue: EntradaMonto(centavos: 42_000_000))
        }
    }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.2), tamanoBrillo: 420)
            VStack(spacing: 0) {
                if paso != .listo {
                    CabeceraCerrar("Nuevo apartado", atras: paso == .plantilla ? nil : { ir(-1) })
                    PasosSegmentos(total: 4, actual: paso.rawValue).padding(.horizontal, 20)
                }
                Group {
                    switch paso {
                    case .plantilla: pasoPlantilla
                    case .objetivo: pasoObjetivo
                    case .regla: pasoRegla
                    case .resumen: pasoResumen
                    case .listo: pasoListo
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: adelante ? .trailing : .leading).combined(with: .opacity),
                                        removal: .opacity))
            }
        }
    }

    private func ir(_ d: Int) {
        Haptico.tocar()
        enNombre = false
        adelante = d > 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { paso = Paso(rawValue: paso.rawValue + d) ?? paso }
    }

    private var icono: String { plantilla?.icono ?? "ic-frasco" }

    // MARK: 1. Plantilla

    private var pasoPlantilla: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Paso 1 de 4 · Para qué").rotulo(.acento).padding(.top, 18)
                Titulo("¿Para qué lo apartás?", tamano: 26).padding(.top, 10)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Plantilla.todas) { p in
                        Button { elegir(p) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Icono3D(nombre: p.icono, tamano: 56)
                                Text(p.nombre).font(.geist(16, .semi)).foregroundStyle(Color.texto)
                                Text(p.objetivo > 0 ? "Sugerido " + Formato.plata(p.objetivo, centavos: false) : "Lo que quieras")
                                    .font(.geist(12)).foregroundStyle(Color.sec).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .caja(radio: 18, seleccionada: plantilla == p)
                        }
                        .buttonStyle(Presionable())
                        .accessibilityAddTraits(plantilla == p ? .isSelected : [])
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func elegir(_ p: Plantilla) {
        Haptico.seleccion()
        plantilla = p
        nombre = p.sugerido
        objetivo = EntradaMonto(centavos: p.objetivo)
        regla = p.regla
        if let d = p.dia { fecha = Fecha.proximo(dia: d); conFecha = true } else {
            conFecha = p.id == "vacaciones"
            fecha = Fecha.calendario.date(byAdding: .month, value: 3, to: .now) ?? .now
        }
        bolsillo = p.id == "monotributo" ? .negocio : .personal
        ir(1)
        if p.id == "otro" { enNombre = true }
    }

    // MARK: 2. Nombre y objetivo

    private var pasoObjetivo: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Icono3D(nombre: icono, tamano: 44)
                TextField("Ponele un nombre", text: $nombre)
                    .font(.geist(20, .semi))
                    .foregroundStyle(Color.texto)
                    .focused($enNombre)
                    .submitLabel(.done)
                Image(systemName: "pencil").foregroundStyle(Color.sec)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .caja(radio: 16)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            Text("¿Cuánto querés juntar?").rotulo().padding(.top, 26)
            MontoTipeado(entrada: objetivo, tamano: 48).padding(.top, 8).padding(.horizontal, 20)
            HStack(spacing: 8) {
                ForEach([10_000_000, 50_000_000, 100_000_000], id: \.self) { c in
                    Chip(texto: Formato.plata(c), on: objetivo.centavos == c) { objetivo = EntradaMonto(centavos: c) }
                }
            }
            .padding(.top, 12)
            Spacer(minLength: 8)
            if !enNombre {
                TecladoNumerico(entrada: $objetivo, alto: 50).padding(.horizontal, 12)
            }
            Button("Seguir") { ir(1) }
                .buttonStyle(.principal)
                .disabled(objetivo.vacio || nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
        }
    }

    // MARK: 3. Cuándo y cómo

    private var pasoRegla: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paso 3 de 4 · Cuándo y cómo").rotulo(.acento).padding(.top, 18)
                    Titulo("¿Para cuándo lo necesitás?", tamano: 24).padding(.top, 10)
                    VStack(spacing: 0) {
                        FilaAjuste(simbolo: "calendar", titulo: "Tiene fecha", detalle: conFecha ? Fecha.larga(fecha) : "Sin apuro") {
                            Interruptor(on: $conFecha, etiqueta: "Tiene fecha")
                        }
                        if conFecha {
                            Separador(sangria: 48)
                            DatePicker("Fecha", selection: $fecha, in: Date.now..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .environment(\.locale, Fecha.locale)
                                .font(.geist(15, .medio))
                                .tint(.acento)
                                .frame(minHeight: 50)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .caja()
                    .padding(.top, 16)
                    Text("Cómo se llena").rotulo().padding(.top, 24).padding(.bottom, 10)
                    SelectorRegla(regla: $regla, porcentaje: $porcentaje, fijo: $fijo)
                    Text("Sale del bolsillo").rotulo().padding(.top, 24).padding(.bottom, 10)
                    Segmentado(opciones: [(Bolsillo.personal, "Personal", "wallet.bifold"), (Bolsillo.negocio, "Negocio", "briefcase")],
                               seleccion: $bolsillo)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            Button("Seguir") { ir(1) }
                .buttonStyle(.principal)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: 4. Resumen

    private var reglaFinal: Apartado.Regla { regla.regla(porcentaje: porcentaje, fijo: fijo) }

    private var pasoResumen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paso 4 de 4 · Resumen").rotulo(.acento).padding(.top, 18)
                    Titulo("Así queda.", tamano: 26).padding(.top, 10)
                    TarjetaApartado(apartado: borrador).padding(.top, 20)
                    VStack(spacing: 0) {
                        RenglonTicket(etiqueta: "Objetivo", valor: Formato.plata(objetivo.centavos))
                        RenglonTicket(etiqueta: "Para", valor: conFecha ? Fecha.larga(fecha) : "Sin fecha")
                        RenglonTicket(etiqueta: "Sale de", valor: bolsillo.nombre)
                        if let p = proyeccion {
                            RenglonTicket(etiqueta: "A este ritmo", valor: p)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .caja()
                    .padding(.top, 12)
                    Text("Mientras espera, rinde a diario. Lo podés sacar cuando quieras, sin costo.").parrafo(13).padding(.top, 14)
                    if let error {
                        Text(error).font(.geist(13, .medio)).foregroundStyle(Color.error).padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            Button { Task { await crear() } } label: {
                HStack(spacing: 8) {
                    if guardando { ProgressView().tint(.noche) }
                    Text(guardando ? "Creándolo…" : "Crear apartado")
                }
            }
            .buttonStyle(.principal)
            .disabled(guardando)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    private var borrador: Apartado {
        Apartado(id: "a-" + UUID().uuidString.prefix(8).lowercased(), nombre: nombre.trimmingCharacters(in: .whitespaces), icono: icono,
                 objetivo: objetivo.centavos, actual: 0, vence: conFecha ? fecha : nil, regla: reglaFinal, bolsillo: bolsillo)
    }

    /// Cuándo llega con la regla elegida (cobros de muestra: ~$ 45.000 por día hábil).
    private var proyeccion: String? {
        let total = objetivo.centavos
        guard total > 0 else { return nil }
        let porSemana: Centavos
        switch reglaFinal {
        case .porcentaje(let p): porSemana = 22_500_000 * p / 100
        case .fijo(let c, _): porSemana = c
        case .manual: return nil
        }
        guard porSemana > 0 else { return nil }
        let semanas = Int((Double(total) / Double(porSemana)).rounded(.up))
        let llega = Fecha.calendario.date(byAdding: .day, value: semanas * 7, to: .now) ?? .now
        return "Llegás el " + Fecha.corta(llega)
    }

    private func crear() async {
        error = nil
        guardando = true
        defer { guardando = false }
        do {
            try await estado.guardarApartado(borrador)
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
            Titulo("«\(nombre)» ya tiene su lugar.", tamano: 28, centrado: true).padding(.top, 8).padding(.horizontal, 24)
            textoRegla(reglaFinal).font(.geist(15)).foregroundStyle(Color.sec).multilineTextAlignment(.center)
                .padding(.top, 10).padding(.horizontal, 32)
            Icono3D(nombre: icono, tamano: 110).padding(.top, 24)
            Spacer()
            Button("Listo") { dismiss() }
                .buttonStyle(.principal)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

// MARK: - Guardar y sacar

/// Hoja para guardar plata en un apartado o sacarla.
struct MoverApartadoPantalla: View {
    let id: String
    @State var guardar: Bool
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var entrada = EntradaMonto()
    @State private var moviendo = false
    @State private var error: String?

    init(id: String, guardar: Bool) {
        self.id = id
        _guardar = State(initialValue: guardar)
    }

    var body: some View {
        if let a = estado.apartado(id) {
            contenido(a)
        } else {
            Vacio(icono: "ic-frasco", titulo: "Ese apartado ya no está.", texto: "Probá con otro.", accion: "Cerrar") { dismiss() }
        }
    }

    private func disponible(_ a: Apartado) -> Centavos { guardar ? estado.saldo(a.bolsillo) : a.actual }

    private func contenido(_ a: Apartado) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Icono3D(nombre: a.icono, tamano: 36)
                    Text(a.nombre).font(.geist(17, .semi)).foregroundStyle(Color.texto).lineLimit(1)
                    Spacer()
                }
                .padding(.top, 22)
                Segmentado(opciones: [(true, "Guardar", "plus"), (false, "Sacar", "arrow.up.right")], seleccion: $guardar)
                    .padding(.top, 14)
                MontoTipeado(entrada: entrada, tamano: 48).padding(.top, 18)
                Text((guardar ? "Disponible en " + a.bolsillo.nombre + ": " : "En el apartado: ") + Formato.plata(disponible(a)))
                    .font(.geist(13)).monospacedDigit()
                    .foregroundStyle(entrada.centavos > disponible(a) ? Color.error : Color.sec)
                    .padding(.top, 6)
                HStack(spacing: 8) {
                    if guardar && a.falta > 0 {
                        Chip(texto: "Lo que falta", on: entrada.centavos == min(a.falta, disponible(a))) {
                            entrada = EntradaMonto(centavos: min(a.falta, disponible(a)))
                        }
                    }
                    Chip(texto: guardar ? Formato.plata(1_000_000) : "Todo", on: false) {
                        entrada = EntradaMonto(centavos: guardar ? 1_000_000 : a.actual)
                    }
                }
                .padding(.top, 12)
                if let error {
                    Text(error).font(.geist(13, .medio)).foregroundStyle(Color.error).padding(.top, 8)
                }
                TecladoNumerico(entrada: $entrada, alto: 48).padding(.top, 10)
                Button { Task { await mover(a) } } label: {
                    HStack(spacing: 8) {
                        if moviendo { ProgressView().tint(.noche) }
                        Text((guardar ? "Guardar " : "Sacar ") + Formato.plata(entrada.centavos))
                    }
                }
                .buttonStyle(.principal)
                .disabled(entrada.vacio || entrada.centavos > disponible(a) || moviendo)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .onChange(of: guardar) { _, _ in entrada = EntradaMonto(); error = nil }
    }

    private func mover(_ a: Apartado) async {
        error = nil
        moviendo = true
        defer { moviendo = false }
        let c = entrada.centavos
        do {
            _ = try await estado.mover(guardar ? c : -c, apartado: a.id)
            estado.avisar(guardar ? "Guardaste " + Formato.plata(c) + " en " + a.nombre : "Volvieron " + Formato.plata(c) + " a " + a.bolsillo.nombre)
            dismiss()
        } catch {
            Haptico.error()
            self.error = estado.mensaje(error)
        }
    }
}
