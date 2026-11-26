import SwiftUI

/// Pestaña Perfil (pantalla 14): quién sos, alias y CVU, seguridad, una persona a mano y el resto de la cuenta.
struct PerfilPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var confirmarSalida = false
    @State private var sesionCerrada = false

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.2, y: 0.05), tamanoBrillo: 380)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CabeceraPerfil()
                    TarjetaAliasCVU().padding(.top, 16)
                    Text("Seguridad").rotulo().padding(.top, 22).padding(.bottom, 8)
                    GrupoSeguridad()
                    PersonaCerca().padding(.top, 12)
                    Text("Tu cuenta").rotulo().padding(.top, 22).padding(.bottom, 8)
                    grupoCuenta
                    Text("La app").rotulo().padding(.top, 22).padding(.bottom, 8)
                    grupoApp
                    Button {
                        confirmarSalida = true
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.cuarzo(.peligro, alto: 50))
                    .padding(.top, 20)
                    LetraChicaPSP().padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .refreshable { await estado.cargar() }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Haptico.firme()
                sesionCerrada = true
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Para volver a entrar te pedimos Face ID o tu código.")
        }
        .fullScreenCover(isPresented: $sesionCerrada) {
            Bloqueo(automatico: false) {
                sesionCerrada = false
                estado.rutas = [:]
                estado.pestana = .inicio
            }
            .environment(estado)
            .capas()
        }
    }

    private var grupoCuenta: some View {
        VStack(spacing: 0) {
            NavegaFila(simbolo: "briefcase", titulo: "Cuarzo Negocios", detalle: "Ventas, cobros y liquidaciones", tono: .rosa) {
                estado.ir(.negocios)
            }
            Separador(sangria: 48)
            NavegaFila(simbolo: "person.text.rectangle", titulo: "Datos de la cuenta", detalle: "Titular, CUIT, CVU y alias") {
                estado.ir(.datosCuenta)
            }
            Separador(sangria: 48)
            NavegaFila(simbolo: "bell", titulo: "Notificaciones",
                       detalle: estado.sinLeer > 0 ? "\(estado.sinLeer) sin leer" : "Todo leído") {
                estado.ir(.notificaciones)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .caja()
    }

    private var grupoApp: some View {
        VStack(spacing: 0) {
            NavegaFila(simbolo: "circle.lefthalf.filled", titulo: "Apariencia", detalle: aparienciaActual) {
                estado.ir(.apariencia)
            }
            Separador(sangria: 48)
            NavegaFila(simbolo: "questionmark.circle", titulo: "Ayuda", detalle: "Preguntas y charla con el equipo") {
                estado.ir(.ayuda)
            }
            Separador(sangria: 48)
            NavegaFila(simbolo: "wand.and.stars", titulo: "Probar estados", detalle: "Cuenta nueva, sin conexión, frenada") {
                estado.ir(.probarEstados)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .caja()
    }

    private var aparienciaActual: String {
        (Apariencia(rawValue: UserDefaults.standard.string(forKey: "apariencia") ?? "") ?? .oscuro).titulo
    }
}

/// Avatar, nombre y CUIT con la identidad validada.
private struct CabeceraPerfil: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        HStack(spacing: 14) {
            Avatar(iniciales: estado.usuario.iniciales, tono: .rosa, tamano: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(estado.usuario.nombreCompleto)
                    .font(.geist(20, .semi)).tracking(-0.6).foregroundStyle(Color.texto).lineLimit(1)
                HStack(spacing: 4) {
                    Text("CUIT " + estado.usuario.cuit)
                    if estado.usuario.validado {
                        Text("·")
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(Color.ok)
                        Text("Identidad validada")
                    }
                }
                .font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Alias (copiar) y CVU (compartir), en mono.
struct TarjetaAliasCVU: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                dato("Alias", estado.usuario.alias)
                Button {
                    copiar(estado.usuario.alias, aviso: "Alias copiado", estado: estado)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 18)).foregroundStyle(Color.acento).frame(width: 44, height: 44)
                }
                .buttonStyle(Presionable(escala: 0.9))
                .accessibilityLabel("Copiar alias")
            }
            Separador()
            HStack {
                dato("CVU", estado.usuario.cvu)
                ShareLink(item: textoCompartir) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 18)).foregroundStyle(Color.acento).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Compartir CVU")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .caja()
    }

    private var textoCompartir: String {
        let u = estado.usuario
        return "Mis datos de Cuarzo\n" + u.nombreCompleto + "\nCUIT " + u.cuit + "\nCVU " + u.cvu + "\nAlias " + u.alias
    }

    private func dato(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(.geist(12, .medio)).foregroundStyle(Color.sec)
            Text(v).font(.mono(12.5)).tracking(0.25).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// El grupo de seguridad de la pantalla 14.
private struct GrupoSeguridad: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        @Bindable var e = estado
        VStack(spacing: 0) {
            FilaAjuste(simbolo: "faceid", titulo: "Face ID para entrar y pagar", tono: .rosa) {
                Interruptor(on: $e.faceIDActivo, etiqueta: "Face ID para entrar y pagar")
            }
            Separador(sangria: 48)
            Button { estado.ir(.dispositivos) } label: {
                FilaAjuste(simbolo: "iphone", titulo: "Dispositivos", detalle: dispositivos, tono: .rosa) { Flecha() }
            }
            .buttonStyle(.plain)
            Separador(sangria: 48)
            FilaAjuste(simbolo: "clock", titulo: "Espera para cuentas nuevas", detalle: "24 h y hasta $\u{00A0}100.000", tono: .rosa) {
                Interruptor(on: $e.esperaCuentasNuevas, etiqueta: "Espera para cuentas nuevas")
            }
            Separador(sangria: 48)
            Button { estado.ir(.limitesTransferencia) } label: {
                FilaAjuste(simbolo: "lock", titulo: "Límites de transferencia", tono: .rosa) { Flecha() }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .caja()
    }

    private var dispositivos: String {
        let este = estado.panel.dispositivos.first(where: \.esEste)?.nombre ?? "iPhone"
        let otros = estado.panel.dispositivos.count - 1
        return este + " · este" + (otros > 0 ? " y \(otros) más" : "")
    }
}

/// «Hablar con una persona», con el tiempo de respuesta.
struct PersonaCerca: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        Button { estado.abrir(.chat) } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left").font(.system(size: 20)).foregroundStyle(Color.acento)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hablar con una persona").font(.geist(15, .semi)).foregroundStyle(Color.texto)
                    Text("Chat o llamada, todos los días").font(.geist(12.5)).foregroundStyle(Color.sec)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(Color.ok).frame(width: 7, height: 7)
                    Text("4 min").font(.geist(12))
                }
                .foregroundStyle(Color.ok)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.acentoSuave.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.acento.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(Presionable(escala: 0.98))
        .accessibilityHint("Responde en unos 4 minutos")
    }
}

/// Fila navegable con ícono, título, detalle y flecha.
struct NavegaFila: View {
    var simbolo: String
    var titulo: String
    var detalle: String? = nil
    var tono: Tono = .rosa
    var accion: () -> Void
    var body: some View {
        Button {
            Haptico.tocar()
            accion()
        } label: {
            FilaAjuste(simbolo: simbolo, titulo: titulo, detalle: detalle, tono: tono) { Flecha() }
        }
        .buttonStyle(.plain)
    }
}

/// La leyenda del PSP y la letra chica de siempre.
struct LetraChicaPSP: View {
    var body: some View {
        VStack(spacing: 10) {
            LeyendaPSP()
            Text("Cuarzo es una marca de Grupo Vimo. No es un banco: la cuenta la provee [PSP socio], proveedor de servicios de pago inscripto en el BCRA. Los fondos no son depósitos en una entidad financiera ni cuentan con la garantía de los depósitos.")
                .font(.geist(11.5)).foregroundStyle(Color.ter).multilineTextAlignment(.center).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Versión " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") + " · maqueta con datos de muestra")
                .font(.mono(10)).tracking(0.6).foregroundStyle(Color.ter)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Datos de la cuenta

struct DatosCuentaPantalla: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Datos de la cuenta")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Titulo("Para que te transfieran.", tamano: 24).padding(.top, 8)
                        Text("Pasá el alias o el CVU. Llega al instante, desde cualquier banco o billetera.")
                            .parrafo(15).padding(.top, 8)
                        VStack(spacing: 0) {
                            fila("Titular", estado.usuario.nombreCompleto, mono: false)
                            Separador()
                            fila("CUIT", estado.usuario.cuit, mono: true)
                            Separador()
                            fila("Alias", estado.usuario.alias, mono: true)
                            Separador()
                            fila("CVU", Formato.cvu(estado.usuario.cvu), copia: estado.usuario.cvu, mono: true)
                            Separador()
                            fila("Tipo", "Cuenta de pago en pesos", mono: false, copiable: false)
                            Separador()
                            fila("Proveedor", "[PSP socio]", mono: false, copiable: false)
                        }
                        .padding(.horizontal, 16)
                        .caja()
                        .padding(.top, 20)
                        ShareLink(item: textoCompartir) {
                            Label("Compartir mis datos", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.principal)
                        .padding(.top, 20)
                        Text("Si te transfieren desde otra cuenta Cuarzo, no tiene costo ni hoy ni después.")
                            .font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var textoCompartir: String {
        let u = estado.usuario
        return "Mis datos de Cuarzo\n" + u.nombreCompleto + "\nCUIT " + u.cuit + "\nCVU " + u.cvu + "\nAlias " + u.alias
    }

    private func fila(_ k: String, _ v: String, copia: String? = nil, mono: Bool, copiable: Bool = true) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(k).font(.geist(12, .medio)).foregroundStyle(Color.sec)
                Text(v).font(mono ? .mono(13) : .geist(15, .medio)).foregroundStyle(Color.texto)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 4)
            if copiable {
                Button {
                    copiar(copia ?? v, aviso: k + " copiado", estado: estado)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 17)).foregroundStyle(Color.acento).frame(width: 44, height: 44)
                }
                .buttonStyle(Presionable(escala: 0.9))
                .accessibilityLabel("Copiar " + k)
            }
        }
        .frame(minHeight: 58)
    }
}

// MARK: - Apariencia

struct AparienciaPantalla: View {
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Apariencia")
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Titulo("¿Noche o nácar?", tamano: 24).padding(.top, 8)
                        Text("Cuarzo nació de noche, pero se lee bien de día.").parrafo(15)
                        HStack(spacing: 10) {
                            ForEach(Apariencia.allCases) { a in opcion(a) }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func opcion(_ a: Apariencia) -> some View {
        let on = apariencia == a.rawValue
        return Button {
            Haptico.seleccion()
            withAnimation(.easeInOut(duration: 0.3)) { apariencia = a.rawValue }
        } label: {
            VStack(spacing: 10) {
                MuestraApariencia(tipo: a).frame(height: 120)
                Text(a.titulo).font(.geist(14, .medio)).foregroundStyle(Color.texto)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(on ? Color.acento : Color.ter)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .caja(radio: 18, seleccionada: on)
        }
        .buttonStyle(Presionable())
        .accessibilityLabel(a.titulo)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Mini pantalla de muestra de cada apariencia.
private struct MuestraApariencia: View {
    let tipo: Apariencia
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                mitad(noche: tipo != .claro).frame(width: tipo == .sistema ? g.size.width / 2 : g.size.width)
                if tipo == .sistema { mitad(noche: false).frame(width: g.size.width / 2) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.linea, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func mitad(noche: Bool) -> some View {
        let fondo = noche ? Color.noche : Color.nacar
        let sup = noche ? Color(UIColor(hex: 0x1C1522)) : Color.white
        let tinta = noche ? Color.rosa : Color.rosaTinta
        return ZStack(alignment: .topLeading) {
            fondo
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6).fill(sup).frame(height: 40)
                    .overlay(alignment: .leading) { Capsule().fill(tinta).frame(width: 26, height: 6).padding(.leading, 8) }
                RoundedRectangle(cornerRadius: 4).fill(sup).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(sup).frame(height: 12)
                Capsule().fill(Color.rosa).frame(height: 14)
            }
            .padding(8)
        }
    }
}

// MARK: - Probar estados

/// Modo de prueba de la maqueta: ver la cuenta nueva, sin conexión, la frenada o rehacer el inicio.
struct ProbarEstadosPantalla: View {
    @Environment(Estado.self) private var estado
    @AppStorage("fase") private var fase = "lista"
    @State private var trabajando = false

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Probar estados")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Titulo("Mirá cada caso.", tamano: 24).padding(.top, 8)
                        Text("Es una maqueta: estos cambios no tocan plata de verdad.").parrafo(15).padding(.top, 8)
                        Text("La cuenta").rotulo().padding(.top, 22).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            accion("sparkles", "Cuenta recién abierta", "Saldo $ 0 y «Para arrancar»", activa: estado.cuentaNueva) {
                                await estado.reiniciar(cuentaNueva: true)
                                estado.avisar("Ahora sos Juan, con la cuenta nueva.", tipo: .info)
                            }
                            Separador(sangria: 48)
                            accion("person.crop.circle.badge.checkmark", "Cuenta con movimientos", "La de Carla, con todo cargado", activa: !estado.cuentaNueva) {
                                await estado.reiniciar(cuentaNueva: false)
                                estado.avisar("Volviste a la cuenta de Carla.", tipo: .info)
                            }
                        }
                        .padding(.horizontal, 16).caja()
                        Text("Lo que puede pasar").rotulo().padding(.top, 22).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            FilaAjuste(simbolo: "wifi.slash", titulo: "Sin conexión", detalle: "Todo lo que va al servidor falla", tono: .rosa) {
                                Interruptor(on: Binding(get: { !estado.conectado }, set: { v in
                                    Task { await estado.simularSinConexion(v) }
                                }), etiqueta: "Sin conexión")
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "pause.circle", titulo: "Transferencia frenada", detalle: "Qué, por qué y hasta cuándo") {
                                estado.abrir(.frenada(DatosDeMuestra.frenada))
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "faceid", titulo: "Face ID", detalle: "Cómo se ve al pagar") {
                                Task { _ = await estado.pedirFaceID("Para probar") }
                            }
                        }
                        .padding(.horizontal, 16).caja()
                        Text("El inicio").rotulo().padding(.top, 22).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            NavegaFila(simbolo: "arrow.counterclockwise", titulo: "Rehacer la bienvenida", detalle: "Las tres pantallas y el alta") {
                                UserDefaults.standard.set(false, forKey: "tourVisto")
                                estado.rutas = [:]
                                estado.pestana = .inicio
                                withAnimation(.easeInOut(duration: 0.4)) { fase = "onboarding" }
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "hand.point.up.left", titulo: "Ver el recorrido otra vez", detalle: "La guía de la primera vez") {
                                UserDefaults.standard.set(false, forKey: "tourVisto")
                                estado.rutas = [:]
                                estado.pestana = .inicio
                            }
                        }
                        .padding(.horizontal, 16).caja()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            if trabajando {
                ProgressView().controlSize(.large).tint(Color.acento)
                    .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func accion(_ s: String, _ t: String, _ d: String, activa: Bool, _ f: @escaping () async -> Void) -> some View {
        Button {
            Haptico.tocar()
            Task { @MainActor in
                trabajando = true
                await f()
                trabajando = false
            }
        } label: {
            FilaAjuste(simbolo: s, titulo: t, detalle: d, tono: .rosa) {
                if activa {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.acento)
                } else {
                    Flecha()
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(trabajando)
    }
}
