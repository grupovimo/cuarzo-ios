import SwiftUI

/// Pestaña Tarjeta (pantalla 12): virtual y física, en vidrio 3D, con congelar, datos, clave y límites.
struct TarjetaPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var tipo: Tarjeta.Tipo = .virtual

    private var tarjeta: Tarjeta? { tipo == .virtual ? estado.tarjetaVirtual : estado.tarjetaFisica }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.45, y: 0.3), tamanoBrillo: 460)
            ScrollView {
                VStack(spacing: 0) {
                    TituloPestana("Tarjeta") {
                        Redondo("slider.horizontal.3", "Límites y ajustes") { estado.ir(.limitesTarjeta) }
                    }
                    Segmentado(opciones: [(Tarjeta.Tipo.virtual, "Virtual", nil), (Tarjeta.Tipo.fisica, "Física", nil)], seleccion: $tipo)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    if let t = tarjeta {
                        contenido(t)
                            .id(t.id)
                            .transition(.asymmetric(insertion: .move(edge: tipo == .virtual ? .leading : .trailing).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private func contenido(_ t: Tarjeta) -> some View {
        if t.tipo == .fisica {
            switch t.estadoFisica {
            case .sinPedir: FisicaSinPedir()
            case .enCamino(let llega): FisicaEnCamino(tarjeta: t, llega: llega)
            case .activa: TarjetaActiva(tarjeta: t)
            }
        } else {
            TarjetaActiva(tarjeta: t)
        }
    }
}

/// Una tarjeta en uso: la tarjeta 3D, estado, Ver datos, acciones, límites y últimas compras.
private struct TarjetaActiva: View {
    let tarjeta: Tarjeta
    @Environment(Estado.self) private var estado
    @State private var dorso = false
    @State private var datos = false
    @State private var segundos = 0
    @State private var reloj: Task<Void, Never>?
    @State private var confirmarAfuera = false
    @State private var verClave = false

    var body: some View {
        VStack(spacing: 0) {
            TarjetaCuarzo3D(tarjeta: tarjeta, mostrarDatos: datos, dorso: $dorso) {
                copiar(tarjeta.numero, aviso: "Copiamos el número", estado: estado)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            filaEstado
                .padding(.horizontal, 20)
                .padding(.top, 14)
            acciones
                .padding(.horizontal, 20)
                .padding(.top, 16)
            LimitesResumen(tarjeta: tarjeta)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            UltimasCompras()
                .padding(.horizontal, 20)
        }
        .onDisappear { ocultar() }
        .confirmationDialog(tarjeta.comprasAfuera ? "¿Apagar las compras afuera?" : "¿Prender las compras afuera?",
                            isPresented: $confirmarAfuera, titleVisibility: .visible) {
            Button(tarjeta.comprasAfuera ? "Apagarlas" : "Prenderlas") { alternarAfuera() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(tarjeta.comprasAfuera
                 ? "No va a andar en comercios ni sitios de otros países."
                 : "Vas a poder pagar en comercios y sitios de otros países. Se cobra en dólares al tipo de cambio del día.")
        }
        .sheet(isPresented: $verClave) { ClaveHoja(tarjeta: tarjeta).environment(estado) }
    }

    private var filaEstado: some View {
        HStack {
            if tarjeta.congelada {
                Etiqueta(texto: "Congelada", simbolo: "snowflake", tipo: .alerta)
            } else {
                Etiqueta(texto: "Activa · " + tarjeta.bolsillo.nombre, simbolo: "checkmark", tipo: .ok)
            }
            Spacer()
            Button {
                Haptico.tocar()
                if datos { ocultar() } else { Task { await mostrarDatos() } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: datos ? "eye.slash" : "eye").font(.system(size: 15))
                    Text(datos ? "Ocultar · \(segundos) s" : "Ver datos").font(.geist(14, .medio)).monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Color.acento)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(tarjeta.congelada)
            .opacity(tarjeta.congelada ? 0.4 : 1)
        }
    }

    private var acciones: some View {
        HStack(spacing: 8) {
            AccionTarjeta(simbolo: "snowflake", titulo: tarjeta.congelada ? "Descongelar" : "Congelar", hielo: true) {
                Task { await congelar() }
            }
            AccionTarjeta(simbolo: "lock", titulo: "Clave") { verClave = true }
            AccionTarjeta(simbolo: "globe", titulo: "Compras afuera", activa: tarjeta.comprasAfuera) { confirmarAfuera = true }
        }
    }

    private func mostrarDatos() async {
        guard await estado.pedirFaceID("Para ver los datos de tu tarjeta") else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { dorso = true; datos = true }
        segundos = 30
        reloj?.cancel()
        reloj = Task { @MainActor in
            while segundos > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                withAnimation { segundos -= 1 }
            }
            ocultar()
        }
    }

    private func ocultar() {
        reloj?.cancel()
        reloj = nil
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { datos = false; dorso = false }
    }

    private func congelar() async {
        var t = tarjeta
        t.congelada.toggle()
        if t.congelada { Haptico.firme(); ocultar() } else { Haptico.exito() }
        await estado.guardarTarjeta(t)
        estado.avisar(t.congelada ? "Congelada. No pasa ninguna compra." : "Lista para usar otra vez.", tipo: .info)
    }

    private func alternarAfuera() {
        var t = tarjeta
        t.comprasAfuera.toggle()
        Task {
            await estado.guardarTarjeta(t)
            estado.avisar(t.comprasAfuera ? "Compras afuera prendidas" : "Compras afuera apagadas", tipo: .info)
        }
    }
}

/// Botón de acción de la tarjeta (cuadro de 3 columnas).
private struct AccionTarjeta: View {
    let simbolo: String
    let titulo: String
    var hielo = false
    var activa = false
    let accion: () -> Void

    var body: some View {
        Button {
            Haptico.tocar()
            accion()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: simbolo).font(.system(size: 20)).foregroundStyle(Color.acento)
                    .symbolEffect(.bounce, value: activa)
                Text(titulo).font(.geist(13, .medio)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14).padding(.bottom, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hielo || activa ? Color.acentoSuave : Color.sup))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(hielo || activa ? Color.acento.opacity(0.3) : Color.linea, lineWidth: 1))
        }
        .buttonStyle(Presionable())
        .accessibilityLabel(titulo + (activa ? ", prendido" : ""))
    }
}

/// Límites por día y por mes con su barra (toca para ajustarlos).
private struct LimitesResumen: View {
    let tarjeta: Tarjeta
    @Environment(Estado.self) private var estado

    var body: some View {
        Button { estado.ir(.limitesTarjeta) } label: {
            VStack(alignment: .leading, spacing: 0) {
                linea("Límite por día", tarjeta.usadoDia, tarjeta.limiteDia)
                linea("Límite por mes", tarjeta.usadoMes, tarjeta.limiteMes).padding(.top, 14)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
    }

    private func linea(_ t: String, _ usado: Centavos, _ limite: Centavos) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(t).font(.geist(14, .medio)).foregroundStyle(Color.texto)
                Spacer()
                Text(Formato.plata(usado) + " de " + Formato.plata(limite))
                    .font(.geist(13)).monospacedDigit().foregroundStyle(Color.sec)
            }
            BarraProgreso(valor: limite > 0 ? Double(usado) / Double(limite) : 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Las compras con la tarjeta.
private struct UltimasCompras: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        let compras = estado.panel.movimientos.filter { $0.tipo == .compraTarjeta }.prefix(4)
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Últimas compras")
            if compras.isEmpty {
                Text("Cuando la uses, tus compras aparecen acá.").parrafo(14).padding(.vertical, 8)
            } else {
                ForEach(Array(compras)) { m in
                    Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m, conHora: true) }
                        .buttonStyle(.plain)
                    if m.id != compras.last?.id { Separador() }
                }
            }
        }
    }
}

/// La clave del cajero, después de Face ID.
private struct ClaveHoja: View {
    let tarjeta: Tarjeta
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var visible = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.linea2).frame(width: 36, height: 5).padding(.top, 8)
            Icono3D(nombre: "ic-escudo", tamano: 84)
            Titulo("Tu clave de la tarjeta", tamano: 22, centrado: true)
            HStack(spacing: 12) {
                ForEach(Array((visible ? "7391" : "••••").enumerated()), id: \.offset) { _, c in
                    Text(String(c))
                        .font(.geistFijo(30, .semi)).monospacedDigit()
                        .foregroundStyle(Color.texto)
                        .frame(width: 54, height: 64)
                        .caja(radio: 14)
                        .contentTransition(.numericText())
                }
            }
            Text(tarjeta.tipo == .virtual
                 ? "Te la pueden pedir algunos comercios. No se la des a nadie que te llame."
                 : "Es la del cajero y la de algunos posnets. Nadie de Cuarzo te la va a pedir.")
                .parrafo(14).multilineTextAlignment(.center).padding(.horizontal, 12)
            Spacer(minLength: 0)
            if visible {
                Button("Listo") { dismiss() }.buttonStyle(.principal)
            } else {
                Button { Task { await ver() } } label: { Label("Ver con Face ID", systemImage: "faceid") }
                    .buttonStyle(.principal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.2), tamanoBrillo: 340))
        .presentationDetents([.medium])
        .capas()
    }

    private func ver() async {
        guard await estado.pedirFaceID("Para ver tu clave") else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { visible = true }
    }
}

/// Física sin pedir: la tarjeta fantasma y por qué pedirla.
private struct FisicaSinPedir: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TarjetaFantasma()
                .padding(.top, 20)
            Titulo("Tu tarjeta de vidrio, gratis.", tamano: 26)
                .padding(.top, 22)
            VStack(alignment: .leading, spacing: 12) {
                beneficio("shippingbox", "Te llega a tu casa en 5 días hábiles.")
                beneficio("wave.3.right", "Pagás apoyándola, en cualquier comercio.")
                beneficio("banknote", "Sacás plata del cajero con tu clave.")
            }
            .padding(.top, 14)
            Button { estado.abrir(.pedirFisica) } label: { Label("Pedila gratis", systemImage: "sparkles") }
                .buttonStyle(.principal)
                .padding(.top, 22)
            Text("Sin costo de emisión ni de envío.").font(.geist(12)).foregroundStyle(Color.sec)
                .frame(maxWidth: .infinity).padding(.top, 10)
        }
        .padding(.horizontal, 20)
    }

    private func beneficio(_ s: String, _ t: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: s).font(.system(size: 15)).foregroundStyle(Color.acento)
                .frame(width: 32, height: 32).background(Circle().fill(Color.acentoSuave))
            Text(t).font(.geist(15)).foregroundStyle(Color.texto)
        }
    }
}

/// Física en camino: la tarjeta, el seguimiento y activarla cuando llega.
private struct FisicaEnCamino: View {
    let tarjeta: Tarjeta
    let llega: Date
    @Environment(Estado.self) private var estado
    @State private var dorso = false

    private var pasos: [(String, String, Bool)] {
        [("Pedida", "Hoy", true),
         ("La estamos preparando", "Con tu nombre", true),
         ("En viaje", "Te avisamos cuando salga", false),
         ("Llega el " + Fecha.corta(llega), Fecha.larga(llega), false)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TarjetaCuarzo3D(tarjeta: tarjeta, dorso: $dorso)
                .padding(.top, 20)
            HStack {
                Etiqueta(texto: "En camino", simbolo: "shippingbox", tipo: .rosa)
                Spacer()
                Text("Llega el " + Fecha.corta(llega)).font(.geist(14, .medio)).foregroundStyle(Color.acento)
            }
            .padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pasos.indices, id: \.self) { i in
                    PasoSeguimiento(titulo: pasos[i].0, detalle: pasos[i].1, hecho: pasos[i].2,
                                    actual: i == 2, ultimo: i == pasos.count - 1)
                }
            }
            .padding(16)
            .caja()
            .padding(.top, 14)
            Button { Task { await activar() } } label: { Label("Ya la tengo: activarla", systemImage: "faceid") }
                .buttonStyle(.secundario)
                .padding(.top, 16)
            Text("Cuando la tengas en la mano, la activás con Face ID.").font(.geist(12)).foregroundStyle(Color.sec)
                .frame(maxWidth: .infinity).padding(.top, 10)
        }
        .padding(.horizontal, 20)
    }

    private func activar() async {
        guard await estado.pedirFaceID("Para activar tu tarjeta") else { return }
        var t = tarjeta
        t.estadoFisica = .activa
        await estado.guardarTarjeta(t)
        estado.avisar("Tarjeta activada. ¡A usarla!")
    }
}

private struct PasoSeguimiento: View {
    let titulo: String
    let detalle: String
    let hecho: Bool
    let actual: Bool
    let ultimo: Bool
    @State private var pulso = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(hecho ? Color.rosa : (actual ? Color.acentoSuave : Color.sup3)).frame(width: 22, height: 22)
                    if hecho {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.noche)
                    } else if actual {
                        Circle().fill(Color.acento).frame(width: 8, height: 8).scaleEffect(pulso ? 1.3 : 0.8)
                    }
                }
                if !ultimo {
                    Rectangle().fill(hecho ? Color.acento.opacity(0.6) : Color.linea2).frame(width: 2, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.geist(15, .medio)).foregroundStyle(hecho || actual ? Color.texto : Color.sec)
                Text(detalle).font(.geist(13)).foregroundStyle(Color.sec)
            }
            Spacer()
        }
        .onAppear { if actual { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulso = true } } }
        .accessibilityElement(children: .combine)
        .accessibilityValue(hecho ? "Hecho" : actual ? "En curso" : "Pendiente")
    }
}

// MARK: - Límites

/// Ajustar los límites de la tarjeta y las compras online y afuera.
struct LimitesTarjetaPantalla: View {
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var tipo: Tarjeta.Tipo = .virtual
    @State private var dia: Double = 0
    @State private var mes: Double = 0
    @State private var online = true
    @State private var afuera = false
    @State private var cargado = false

    private var tarjeta: Tarjeta? { tipo == .virtual ? estado.tarjetaVirtual : estado.tarjetaFisica }
    private var cambio: Bool {
        guard let t = tarjeta else { return false }
        return Int(dia) != t.limiteDia || Int(mes) != t.limiteMes || online != t.comprasOnline || afuera != t.comprasAfuera
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FondoCuarzo(brillo: CGPoint(x: 0.3, y: 0.1), tamanoBrillo: 360)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CabeceraAtras("Límites y ajustes")
                    Segmentado(opciones: [(Tarjeta.Tipo.virtual, "Virtual", nil), (Tarjeta.Tipo.fisica, "Física", nil)], seleccion: $tipo)
                        .padding(.top, 6)
                        .padding(.horizontal, 20)
                    if let t = tarjeta {
                        BloqueLimite(titulo: "Por día", usado: t.usadoDia, valor: $dia, rango: 1_000_000...100_000_000,
                                     rapidos: [10_000_000, 30_000_000, 50_000_000])
                            .padding(.top, 20)
                        BloqueLimite(titulo: "Por mes", usado: t.usadoMes, valor: $mes, rango: 10_000_000...500_000_000,
                                     rapidos: [50_000_000, 150_000_000, 300_000_000])
                            .padding(.top, 12)
                        compras.padding(.top, 12)
                        Text("Los límites te cuidan si alguien usa tus datos. Los podés cambiar cuando quieras.")
                            .parrafo(13).padding(.horizontal, 20).padding(.top, 14)
                    }
                }
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            Button("Guardar cambios") { Task { await guardar() } }
                .buttonStyle(.principal)
                .disabled(!cambio)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(LinearGradient(colors: [Color.fondo.opacity(0), Color.fondo], startPoint: .top, endPoint: .center)
                    .padding(.top, -30).ignoresSafeArea())
        }
        .onAppear { if !cargado { cargar(); cargado = true } }
        .onChange(of: tipo) { _, _ in cargar() }
    }

    private var compras: some View {
        VStack(spacing: 0) {
            FilaAjuste(simbolo: "cart", titulo: "Compras online", detalle: "Tiendas y apps del país") {
                Interruptor(on: $online, etiqueta: "Compras online")
            }
            Separador(sangria: 48)
            FilaAjuste(simbolo: "globe", titulo: "Compras afuera", detalle: "Comercios y sitios de otros países") {
                Interruptor(on: $afuera, etiqueta: "Compras afuera")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .caja()
        .padding(.horizontal, 20)
    }

    private func cargar() {
        guard let t = tarjeta else { return }
        dia = Double(t.limiteDia); mes = Double(t.limiteMes); online = t.comprasOnline; afuera = t.comprasAfuera
    }

    private func guardar() async {
        guard var t = tarjeta else { return }
        t.limiteDia = Int(dia); t.limiteMes = Int(mes); t.comprasOnline = online; t.comprasAfuera = afuera
        await estado.guardarTarjeta(t)
        estado.avisar("Guardamos tus límites")
        dismiss()
    }
}

/// Un límite: monto grande, slider de a $ 10.000 y montos rápidos.
private struct BloqueLimite: View {
    let titulo: String
    let usado: Centavos
    @Binding var valor: Double
    let rango: ClosedRange<Double>
    let rapidos: [Centavos]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).rotulo()
                Spacer()
                Text("Usaste " + Formato.plata(usado)).font(.geist(13)).monospacedDigit().foregroundStyle(Color.sec)
            }
            MontoChico(centavos: Int(valor), tamano: 30, conCentavos: false)
                .padding(.top, 8)
            Slider(value: Binding(get: { valor }, set: { nuevo in
                if Int(nuevo) != Int(valor) { Haptico.seleccion() }
                valor = nuevo
            }), in: rango, step: 1_000_000)
            .tint(.rosa)
            .padding(.top, 6)
            .accessibilityLabel("Límite " + titulo.lowercased())
            .accessibilityValue(Formato.plata(Int(valor)))
            HStack(spacing: 8) {
                ForEach(rapidos, id: \.self) { r in
                    Chip(texto: Formato.plata(r), on: Int(valor) == r) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { valor = Double(r) }
                    }
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        .caja()
        .padding(.horizontal, 20)
    }
}
