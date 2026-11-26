import SwiftUI

// MARK: - Fondo

/// Fondo de cada pantalla: noche (o nácar), la trama de 39 pt y un brillo rosa opcional.
struct FondoCuarzo: View {
    var brillo: CGPoint? = CGPoint(x: 0.4, y: 0.18)
    var tamanoBrillo: CGFloat = 420
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        ZStack {
            Color.fondo
            Trama().opacity(esquema == .dark ? 1 : 0.7)
            if let b = brillo {
                GeometryReader { g in
                    Brillo(tamano: tamanoBrillo)
                        .position(x: g.size.width * b.x, y: g.size.height * b.y)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// La grilla tenue del sistema (rosa al 2,5 %).
struct Trama: View {
    var paso: CGFloat = 39
    var body: some View {
        Canvas { c, s in
            var p = Path()
            var x: CGFloat = 0
            while x < s.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: s.height)); x += paso }
            var y: CGFloat = 0
            while y < s.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: s.width, y: y)); y += paso }
            c.stroke(p, with: .color(Color.acento.opacity(0.03)), lineWidth: 1)
        }
    }
}

/// Resplandor rosa difuso.
struct Brillo: View {
    var tamano: CGFloat = 420
    var intensidad: Double = 1
    @Environment(\.colorScheme) private var esquema
    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.rosa.opacity(0.24 * intensidad * (esquema == .dark ? 1 : 0.7)),
                                          Color.ciruela.opacity(0.08 * intensidad), .clear],
                                 center: .center, startRadius: 0, endRadius: tamano / 2))
            .frame(width: tamano, height: tamano * 0.75)
            .blur(radius: 10)
            .allowsHitTesting(false)
    }
}

// MARK: - Superficies

extension View {
    /// Vidrio: degradé rosa sobre la superficie, borde de luz arriba y filo rosa (22 pt).
    func vidrio(radio: CGFloat = 22) -> some View { modifier(Vidrio(radio: radio)) }

    /// Caja: superficie con filo (20 pt).
    func caja(radio: CGFloat = 20, seleccionada: Bool = false) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radio, style: .continuous)
                .fill(seleccionada ? Color.acentoSuave : Color.sup)
                .overlay(RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(seleccionada ? Color.acento : Color.linea, lineWidth: seleccionada ? 1.5 : 1))
        )
    }
}

struct Vidrio: ViewModifier {
    var radio: CGFloat
    @Environment(\.colorScheme) private var esquema
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: radio, style: .continuous)
        content
            .background(
                forma.fill(Color.sup)
                    .overlay(forma.fill(LinearGradient(colors: [Color.acento.opacity(esquema == .dark ? 0.10 : 0.06),
                                                                Color.acento.opacity(0.02)], startPoint: .top, endPoint: .bottom)))
                    .overlay(forma.strokeBorder(Color.acentoBorde, lineWidth: 1))
                    .overlay(forma.strokeBorder(LinearGradient(colors: [Color.acento.opacity(0.32), .clear],
                                                               startPoint: .top, endPoint: .center), lineWidth: 1))
                    .shadow(color: .black.opacity(esquema == .dark ? 0 : 0.06), radius: 16, y: 6)
            )
            .clipShape(forma)
    }
}

// MARK: - Botones

/// Escala un poco al apretar (todo lo tocable).
struct Presionable: ButtonStyle {
    var escala: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? escala : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Botón del sistema: principal (rosa), secundario (filo), texto (rosa sin fondo).
struct BotonCuarzo: ButtonStyle {
    enum Tipo { case principal, secundario, texto, peligro }
    var tipo: Tipo = .principal
    var alto: CGFloat = 54
    @Environment(\.isEnabled) private var habilitado

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.geist(alto < 52 ? 15 : 17, .semi, relativo: .headline))
            .tracking(-0.25)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: tipo == .texto ? 44 : alto)
            .foregroundStyle(frente)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: tipo == .principal && habilitado ? Color.rosa.opacity(0.45) : .clear, radius: 14, y: 8)
            .opacity(habilitado ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }

    private var frente: Color {
        switch tipo {
        case .principal: return .noche
        case .secundario: return .texto
        case .texto: return .acento
        case .peligro: return .error
        }
    }

    @ViewBuilder private var fondo: some View {
        switch tipo {
        case .principal:
            ZStack {
                LinearGradient.botonRosa
                LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.06))
            }
        case .secundario, .peligro:
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.linea2, lineWidth: 1)
        case .texto:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == BotonCuarzo {
    static var principal: BotonCuarzo { BotonCuarzo(tipo: .principal) }
    static var secundario: BotonCuarzo { BotonCuarzo(tipo: .secundario) }
    static var textoRosa: BotonCuarzo { BotonCuarzo(tipo: .texto) }
    static func cuarzo(_ t: BotonCuarzo.Tipo, alto: CGFloat = 54) -> BotonCuarzo { BotonCuarzo(tipo: t, alto: alto) }
}

/// Botón redondo de 40 pt (atrás, cerrar, ayuda, filtros).
struct Redondo: View {
    let simbolo: String
    var etiqueta: String
    var punto = false
    var accion: () -> Void

    init(_ simbolo: String, _ etiqueta: String, punto: Bool = false, accion: @escaping () -> Void) {
        self.simbolo = simbolo; self.etiqueta = etiqueta; self.punto = punto; self.accion = accion
    }

    var body: some View {
        Button {
            Haptico.tocar()
            accion()
        } label: {
            Image(systemName: simbolo)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.texto)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.sup2).overlay(Circle().strokeBorder(Color.linea, lineWidth: 1)))
                .overlay(alignment: .topTrailing) {
                    if punto {
                        Circle().fill(Color.acento).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.sup2, lineWidth: 2))
                            .offset(x: -9, y: 9)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(Presionable(escala: 0.9))
        .accessibilityLabel(etiqueta)
    }
}

/// Encabezado de 52 pt: botón a la izquierda, título centrado, botón a la derecha.
struct Cabecera<Izq: View, Der: View>: View {
    var titulo: String
    @ViewBuilder var izquierda: () -> Izq
    @ViewBuilder var derecha: () -> Der

    init(_ titulo: String, @ViewBuilder izquierda: @escaping () -> Izq, @ViewBuilder derecha: @escaping () -> Der) {
        self.titulo = titulo; self.izquierda = izquierda; self.derecha = derecha
    }

    var body: some View {
        ZStack {
            Text(titulo)
                .font(.geist(17, .semi, relativo: .headline))
                .tracking(-0.34)
                .foregroundStyle(Color.texto)
                .lineLimit(1)
                .padding(.horizontal, 56)
                .accessibilityAddTraits(.isHeader)
            HStack {
                izquierda().frame(minWidth: 44, alignment: .leading)
                Spacer()
                derecha().frame(minWidth: 44, alignment: .trailing)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 14)
    }
}

extension Cabecera where Der == EmptyView {
    init(_ titulo: String, @ViewBuilder izquierda: @escaping () -> Izq) {
        self.init(titulo, izquierda: izquierda, derecha: { EmptyView() })
    }
}

/// Encabezado de pantalla apilada: atrás + título (+ acción opcional).
struct CabeceraAtras<Der: View>: View {
    var titulo: String
    @ViewBuilder var derecha: () -> Der
    @Environment(\.dismiss) private var dismiss

    init(_ titulo: String, @ViewBuilder derecha: @escaping () -> Der) {
        self.titulo = titulo; self.derecha = derecha
    }

    var body: some View {
        Cabecera(titulo) {
            Redondo("chevron.left", "Volver") { dismiss() }
        } derecha: {
            derecha()
        }
    }
}

extension CabeceraAtras where Der == EmptyView {
    init(_ titulo: String) { self.init(titulo, derecha: { EmptyView() }) }
}

/// Encabezado de flujo modal: cerrar + título (+ acción).
struct CabeceraCerrar<Der: View>: View {
    var titulo: String
    var atras: (() -> Void)?
    @ViewBuilder var derecha: () -> Der
    @Environment(\.dismiss) private var dismiss

    init(_ titulo: String, atras: (() -> Void)? = nil, @ViewBuilder derecha: @escaping () -> Der) {
        self.titulo = titulo; self.atras = atras; self.derecha = derecha
    }

    var body: some View {
        Cabecera(titulo) {
            if let atras {
                Redondo("chevron.left", "Volver", accion: atras)
            } else {
                Redondo("xmark", "Cerrar") { dismiss() }
            }
        } derecha: {
            derecha()
        }
    }
}

extension CabeceraCerrar where Der == EmptyView {
    init(_ titulo: String, atras: (() -> Void)? = nil) { self.init(titulo, atras: atras, derecha: { EmptyView() }) }
}

/// Título grande de pestaña («Movimientos», «Tarjeta») con acciones a la derecha.
struct TituloPestana<Der: View>: View {
    var titulo: String
    @ViewBuilder var derecha: () -> Der
    init(_ titulo: String, @ViewBuilder derecha: @escaping () -> Der) { self.titulo = titulo; self.derecha = derecha }
    var body: some View {
        HStack(spacing: 8) {
            Text(titulo)
                .font(.geistFijo(32, .semi))
                .tracking(-1.4)
                .foregroundStyle(Color.texto)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            derecha()
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .frame(height: 52)
    }
}

// MARK: - Piezas

/// Avatar con iniciales (o un ícono) sobre su tono.
struct Avatar: View {
    var iniciales: String
    var tono: Tono = .neutro
    var simbolo: String? = nil
    var tamano: CGFloat = 40
    var cuadrado = false

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: cuadrado ? tamano * 0.3 : tamano / 2, style: .continuous)
        ZStack {
            forma.fill(tono.fondo)
            if let simbolo {
                Image(systemName: simbolo).font(.system(size: tamano * 0.45, weight: .regular))
            } else {
                Text(iniciales).font(.geistFijo(tamano * 0.35, .semi)).tracking(-0.2)
            }
        }
        .foregroundStyle(tono.frente)
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
    }
}

/// Avatar de un movimiento: ícono para comercios y pases, iniciales para personas.
struct AvatarMovimiento: View {
    let m: Movimiento
    var tamano: CGFloat = 40
    var body: some View {
        Avatar(iniciales: m.iniciales, tono: m.tono, simbolo: m.simbolo, tamano: tamano, cuadrado: m.simbolo != nil && m.tipo != .pase)
    }
}

/// Fila de movimiento (min 62 pt): avatar, nombre, detalle y monto (rosa si entra).
struct FilaMovimiento: View {
    let m: Movimiento
    var conHora = false
    @Environment(Estado.self) private var estado

    var body: some View {
        HStack(spacing: 12) {
            AvatarMovimiento(m: m)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.titulo).font(.geist(15, .medio)).tracking(-0.15).foregroundStyle(Color.texto).lineLimit(1)
                Text(conHora ? m.subtitulo + " · " + Fecha.hora(m.fecha) : m.subtitulo)
                    .font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                MontoFila(centavos: m.centavos, pase: m.tipo == .pase, oculto: !estado.saldoVisible)
                if m.estado != .listo {
                    Text(m.estado.nombre).font(.geist(12)).foregroundStyle(m.estado == .frenado ? Color.alerta : Color.sec)
                }
            }
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Monto de una fila: «+ $ 15.000» en rosa si entra, «− $ 4.800» si sale; centavos chicos abajo si los hay.
struct MontoFila: View {
    let centavos: Centavos
    var pase = false
    var oculto = false
    var body: some View {
        let p = Formato.partes(centavos)
        let signo = pase ? "" : (centavos >= 0 ? "+" + Formato.nbsp : "−" + Formato.nbsp)
        let texto = oculto ? "$" + Formato.nbsp + "•••" : signo + "$" + Formato.nbsp + p.entero
        VStack(alignment: .trailing, spacing: 1) {
            Text(texto)
                .font(.geist(15, .medio)).monospacedDigit().tracking(-0.15)
                .foregroundStyle(centavos > 0 && !pase && !oculto ? Color.acento : Color.texto)
                .lineLimit(1)
            if !oculto && abs(centavos) % 100 != 0 {
                Text(p.centavos).font(.geist(12)).foregroundStyle(Color.sec)
            }
        }
    }
}

/// Separador de 1 pt.
struct Separador: View {
    var sangria: CGFloat = 0
    var body: some View { Rectangle().fill(Color.linea).frame(height: 1).padding(.leading, sangria) }
}

/// Encabezado de sección: rótulo a la izquierda y un enlace rosa a la derecha.
struct EncabezadoSeccion: View {
    var titulo: String
    var accion: String? = nil
    var alTocar: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo).rotulo()
            Spacer()
            if let accion, let alTocar {
                Button(accion) { Haptico.tocar(); alTocar() }
                    .font(.geist(14, .medio))
                    .foregroundStyle(Color.acento)
                    .buttonStyle(.plain)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

/// Píldora seleccionable (34 pt).
struct Chip: View {
    let texto: String
    var simbolo: String? = nil
    var on = false
    var accion: () -> Void
    var body: some View {
        Button {
            Haptico.seleccion()
            accion()
        } label: {
            HStack(spacing: 6) {
                if let simbolo { Image(systemName: simbolo).font(.system(size: 13, weight: .medium)) }
                Text(texto).font(.geist(14, .medio)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(on ? Color.noche : Color.texto)
            .background(Capsule().fill(on ? Color.rosa : Color.sup2))
            .overlay(Capsule().strokeBorder(on ? .clear : Color.linea, lineWidth: 1))
        }
        .buttonStyle(Presionable())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Etiqueta mono chica («CUENTA CUARZO», «LLEGA AL INSTANTE · $ 0»).
struct Etiqueta: View {
    enum Tipo { case rosa, neutra, ok, alerta, error }
    let texto: String
    var simbolo: String? = nil
    var tipo: Tipo = .rosa
    var girando = false

    var body: some View {
        HStack(spacing: 5) {
            if girando {
                ProgressView().controlSize(.mini).tint(frente)
            } else if let simbolo {
                Image(systemName: simbolo).font(.system(size: 10, weight: .semibold))
            }
            Text(texto).font(.mono(10.5)).tracking(1.26).textCase(.uppercase).lineLimit(1)
        }
        .foregroundStyle(frente)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fondo))
    }

    private var frente: Color {
        switch tipo {
        case .rosa: return .acento
        case .neutra: return .sec
        case .ok: return .ok
        case .alerta: return .alerta
        case .error: return .error
        }
    }
    private var fondo: Color {
        switch tipo {
        case .rosa: return .acentoSuave
        case .neutra: return .sup3
        case .ok: return .okSuave
        case .alerta: return .alertaSuave
        case .error: return .errorSuave
        }
    }
}

/// «Cuenta provista por [PSP socio]», discreto, junto al saldo.
struct LeyendaPSP: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield").font(.system(size: 11))
            Text("Cuenta provista por [PSP socio]").font(.geist(12))
        }
        .foregroundStyle(Color.sec)
        .accessibilityElement(children: .combine)
    }
}

/// Barra de progreso (8 pt) con degradé rosa.
struct BarraProgreso: View {
    var valor: Double
    var alto: CGFloat = 8
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.sup3)
                Capsule().fill(LinearGradient.barraRosa)
                    .frame(width: max(alto, g.size.width * min(1, max(0, valor))))
                    .opacity(valor > 0 ? 1 : 0)
            }
        }
        .frame(height: alto)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: valor)
        .accessibilityElement()
        .accessibilityValue("\(Int((valor * 100).rounded())) %")
    }
}

/// Puntos de paginado (el activo, una píldora de 22 pt).
struct Puntos: View {
    var total: Int
    var actual: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i == actual ? Color.acento : Color.linea2)
                    .frame(width: i == actual ? 22 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: actual)
        .accessibilityElement()
        .accessibilityLabel("Paso \(actual + 1) de \(total)")
    }
}

/// Segmentado de dos o más opciones (Con QR / Con link, Virtual / Física).
struct Segmentado<T: Hashable>: View {
    let opciones: [(valor: T, titulo: String, simbolo: String?)]
    @Binding var seleccion: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(opciones.indices, id: \.self) { i in
                let o = opciones[i]
                let on = o.valor == seleccion
                Button {
                    Haptico.seleccion()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { seleccion = o.valor }
                } label: {
                    HStack(spacing: 6) {
                        if let s = o.simbolo { Image(systemName: s).font(.system(size: 15)) }
                        Text(o.titulo).font(.geist(15, .medio)).lineLimit(1)
                    }
                    .foregroundStyle(on ? Color.texto : Color.sec)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.sup3)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(LinearGradient(colors: [Color.acento.opacity(0.25), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                                .matchedGeometryEffect(id: "seg", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .caja(radio: 14)
    }
}

/// Interruptor rosa.
struct Interruptor: View {
    @Binding var on: Bool
    var etiqueta: String
    var body: some View {
        Toggle(etiqueta, isOn: Binding(get: { on }, set: { Haptico.seleccion(); on = $0 }))
            .labelsHidden()
            .tint(.rosa)
    }
}

/// Ícono 3D de vidrio (los de recursos: ic-llaves, ic-frasco…).
struct Icono3D: View {
    let nombre: String
    var tamano: CGFloat = 58
    var body: some View {
        Image(nombre).resizable().interpolation(.high).scaledToFit()
            .frame(width: tamano, height: tamano)
            .accessibilityHidden(true)
    }
}

/// Fila de ajustes: ícono en cuadro, título, detalle y algo a la derecha (flecha, interruptor, valor).
struct FilaAjuste<Der: View>: View {
    var simbolo: String
    var titulo: String
    var detalle: String? = nil
    var tono: Tono = .neutro
    @ViewBuilder var derecha: () -> Der

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: simbolo)
                .font(.system(size: 16))
                .foregroundStyle(tono == .neutro ? Color.sec : tono.frente)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tono == .neutro ? Color.sup2 : tono.fondo))
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.geist(15, .medio)).foregroundStyle(Color.texto)
                if let detalle { Text(detalle).font(.geist(13)).foregroundStyle(Color.sec).lineLimit(2) }
            }
            Spacer(minLength: 8)
            derecha()
        }
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

/// Flecha gris de las filas navegables.
struct Flecha: View {
    var body: some View { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ter) }
}

// MARK: - Estados

/// Vacío con una acción clara (nunca una pantalla muerta).
struct Vacio: View {
    var icono: String = "ic-frasco"
    var titulo: String
    var texto: String
    var accion: String? = nil
    var alTocar: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Icono3D(nombre: icono, tamano: 96)
            Titulo(titulo, tamano: 20, centrado: true)
            Text(texto).parrafo(14).multilineTextAlignment(.center)
            if let accion, let alTocar {
                Button(accion, action: alTocar).buttonStyle(.cuarzo(.principal, alto: 48)).frame(maxWidth: 240).padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

/// Error con reintento (la plata siempre «a salvo»).
struct ErrorVista: View {
    var titulo = "No pudimos cargar esto."
    var texto = "Tu plata está a salvo. Revisá la conexión y probá de nuevo."
    var reintentar: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(Color.alerta)
                .frame(width: 72, height: 72).background(Circle().fill(Color.alertaSuave))
            Titulo(titulo, tamano: 20, centrado: true)
            Text(texto).parrafo(14).multilineTextAlignment(.center)
            Button("Probar de nuevo", action: reintentar).buttonStyle(.cuarzo(.secundario, alto: 48)).frame(maxWidth: 220)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// Franja «Sin conexión» arriba del inicio y de movimientos.
struct FranjaSinConexion: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        if !estado.conectado {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash").font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sin conexión").font(.geist(14, .semi))
                    Text("Te mostramos lo último que cargamos" + (estado.ultimaCarga.map { " (" + Fecha.hora($0) + ")" } ?? "") + ".")
                        .font(.geist(12)).opacity(0.85)
                }
                Spacer()
                Button("Reintentar") { Task { await estado.cargar() } }
                    .font(.geist(13, .semi)).buttonStyle(.plain)
            }
            .foregroundStyle(Color.alerta)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.alertaSuave))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Esqueleto de carga (barras que titilan).
struct Esqueleto: View {
    var alto: CGFloat = 14
    var ancho: CGFloat? = nil
    @State private var on = false
    var body: some View {
        RoundedRectangle(cornerRadius: alto / 2, style: .continuous)
            .fill(Color.sup3)
            .frame(width: ancho, height: alto)
            .opacity(on ? 0.5 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { on = true } }
            .accessibilityHidden(true)
    }
}
