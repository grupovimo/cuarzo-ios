import SwiftUI

/// Inicio (pantalla 05) y, con la cuenta recién abierta, «Para arrancar» (pantalla 15). Nunca queda vacío.
struct InicioPantalla: View {
    @Environment(Estado.self) private var estado
    @AppStorage("tourVisto") private var tourVisto = false
    @State private var pasoTour = 0

    var body: some View {
        ZStack(alignment: .top) {
            FondoCuarzo(brillo: CGPoint(x: 0.45, y: 0.22), tamanoBrillo: 440)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CabeceraInicio()
                    FranjaSinConexion()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    if estado.cuentaNueva {
                        InicioNuevo()
                    } else {
                        InicioCompleto()
                    }
                }
                .padding(.bottom, 28)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: estado.conectado)
            }
            .scrollIndicators(.hidden)
            .refreshable { await estado.cargar() }
        }
        .overlayPreferenceValue(AnclasTour.self) { anclas in
            if !tourVisto && !estado.cuentaNueva {
                TourInicio(anclas: anclas, paso: $pasoTour) {
                    withAnimation(.easeOut(duration: 0.25)) { tourVisto = true }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Cabecera

private struct CabeceraInicio: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: estado.usuario.iniciales, tono: .rosa, tamano: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text("Hola, " + estado.usuario.nombre)
                    .font(.geist(17, .semi, relativo: .headline)).tracking(-0.34)
                    .foregroundStyle(Color.texto)
                Text(estado.cuentaNueva ? "Tu cuenta ya está abierta" : estado.usuario.negocio + " · " + estado.usuario.barrio)
                    .font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer()
            if estado.cuentaNueva {
                Redondo("questionmark.circle", "Ayuda") { estado.ir(.ayuda) }
            } else {
                Redondo("bell", "Avisos", punto: estado.sinLeer > 0) { estado.ir(.notificaciones) }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }
}

// MARK: - Cuenta con movimiento (05)

private struct InicioCompleto: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TarjetaSaldo()
                .anchorPreference(key: AnclasTour.self, value: .bounds) { [0: $0] }
            AccionesInicio()
                .padding(.top, 18)
                .anchorPreference(key: AnclasTour.self, value: .bounds) { [1: $0] }
            ParaHacer()
            NegociosResumen()
                .padding(.top, 22)
            MovimientosDeHoy()
        }
        .padding(.horizontal, 20)
    }
}

/// El saldo en vidrio, los dos bolsillos y el rendimiento del día.
private struct TarjetaSaldo: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Saldo total").rotulo()
                Spacer()
                Button {
                    Haptico.seleccion()
                    withAnimation(.easeInOut(duration: 0.25)) { estado.saldoVisible.toggle() }
                } label: {
                    Image(systemName: estado.saldoVisible ? "eye" : "eye.slash")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.sec)
                        .frame(width: 44, height: 32, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(estado.saldoVisible ? "Ocultar saldo" : "Mostrar saldo")
            }
            Monto(centavos: estado.saldoTotal, tamano: 40, oculto: !estado.saldoVisible)
                .padding(.top, 4)
            LeyendaPSP().padding(.top, 8)
            Bolsillos().padding(.top, 16)
            FilaRendimiento().padding(.top, 12)
        }
        .padding(18)
        .padding(.bottom, -4)
        .vidrio()
    }
}

private struct Bolsillos: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        HStack(spacing: 8) {
            Button { estado.ir(.negocios) } label: {
                Bolsillo1(b: .negocio, detalle: "+" + Formato.nbsp + Formato.plata(estado.cobradoHoy, centavos: false) + " hoy")
            }
            .buttonStyle(Presionable(escala: 0.97))
            .accessibilityHint("Abre Cuarzo Negocios")
            Button { estado.pestana = .movimientos } label: {
                Bolsillo1(b: .personal, detalle: "Sueldo el " + Fecha.corta(Fecha.proximo(dia: 1)))
                    .padding(.leading, 0)
            }
            .buttonStyle(Presionable(escala: 0.97))
        }
        .overlay {
            Button { estado.abrir(.pasar(.negocio)) } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.noche)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.rosa))
                    .background(Circle().fill(Color.sup).padding(-4))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(Presionable(escala: 0.88))
            .accessibilityLabel("Pasar plata entre bolsillos")
        }
    }
}

private struct Bolsillo1: View {
    let b: Bolsillo
    let detalle: String
    @Environment(Estado.self) private var estado

    var body: some View {
        let negocio = b == .negocio
        VStack(alignment: .leading, spacing: 0) {
            Label(b.nombre, systemImage: b.simbolo)
                .font(.geist(13, .medio))
                .foregroundStyle(negocio ? Color.acento : Color.sec)
                .labelStyle(EstiloEtiquetaJunta())
            MontoChico(centavos: estado.saldo(b), tamano: 19, oculto: !estado.saldoVisible)
                .padding(.top, 8)
            Text(detalle)
                .font(.geist(12))
                .foregroundStyle(negocio ? Color.acento : Color.sec)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .padding(.leading, negocio ? 0 : 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.fondo.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

/// Ícono y texto juntos (6 pt), como el `.h` del diseño.
struct EstiloEtiquetaJunta: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 13))
            configuration.title
        }
    }
}

private struct FilaRendimiento: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        Button { estado.ir(.rendimiento) } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 13, weight: .semibold))
                Text("Tu plata rinde")
                    .foregroundStyle(Color.sec)
                Spacer()
                Text(estado.saldoVisible ? "+" + Formato.nbsp + Formato.plata(estado.panel.rendimiento.ganadoHoy, centavos: true) + " hoy" : "•••")
                    .monospacedDigit()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.ter)
            }
            .font(.geist(13, .medio))
            .foregroundStyle(Color.ok)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Color.linea).frame(height: 1) }
    }
}

/// Las cuatro acciones rápidas.
private struct AccionesInicio: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AccionInicio(simbolo: "qrcode", titulo: "Cobrar") { estado.abrir(.cobrar(.qr)) }
            AccionInicio(simbolo: "qrcode.viewfinder", titulo: "Pagar") { estado.abrir(.pagar) }
            AccionInicio(simbolo: "arrow.up.right", titulo: "Transferir") { estado.abrir(.transferir(nil)) }
            AccionInicio(simbolo: "lock", titulo: "Apartar") { estado.ir(.apartados) }
        }
    }
}

struct AccionInicio: View {
    let simbolo: String
    let titulo: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            VStack(spacing: 7) {
                Image(systemName: simbolo)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.acento)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.sup2)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.linea, lineWidth: 1))
                    )
                Text(titulo)
                    .font(.geist(12.5, .medio))
                    .foregroundStyle(Color.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(Presionable(escala: 0.92))
    }
}

// MARK: - Para hacer

private struct Tarea: Identifiable {
    let id: String
    let icono: String
    let titulo: String
    let texto: String
    let accion: String
    let alTocar: () -> Void
}

private struct ParaHacer: View {
    @Environment(Estado.self) private var estado
    @State private var verTodo = false

    var body: some View {
        let tareas = armarTareas()
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Para hacer", accion: tareas.count > 1 ? "Ver todo" : nil) { verTodo = true }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(tareas) { t in
                        TarjetaTarea(t: t).frame(width: 300)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
                .padding(.trailing, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .padding(.trailing, -20)
        }
        .sheet(isPresented: $verTodo) {
            TodasLasTareas(tareas: tareas)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
    }

    private func armarTareas() -> [Tarea] {
        var t: [Tarea] = []
        let pendientes = estado.panel.apartados.filter { !$0.listo }.sorted { ($0.vence ?? .distantFuture) < ($1.vence ?? .distantFuture) }
        for a in pendientes {
            let vence = a.vence.map { " vence el " + Fecha.corta($0) } ?? ""
            let titulo = a.nombre.hasPrefix("Alquiler") ? "El alquiler" + vence : a.nombre + (vence.isEmpty ? "" : ":" + vence)
            t.append(Tarea(id: a.id, icono: a.icono, titulo: titulo,
                           texto: "Faltan " + Formato.plata(a.falta, centavos: false) + " en el apartado.", accion: "Completar ahora") {
                estado.ir(.apartado(a.id))
            })
        }
        for a in estado.panel.apartados where a.listo {
            t.append(Tarea(id: a.id, icono: a.icono, titulo: a.nombre + (a.vence.map { " · vence el " + Fecha.corta($0) } ?? ""),
                           texto: "Ya tenés lo justo apartado.", accion: "Ver apartado") {
                estado.ir(.apartado(a.id))
            })
        }
        let sinPagar = estado.panel.links.filter { $0.estado == .pendiente }
        if let l = sinPagar.first {
            let monto = l.centavos.map { " · " + Formato.plata($0, centavos: false) } ?? ""
            t.append(Tarea(id: "links", icono: "ic-transferir",
                           titulo: sinPagar.count == 1 ? "Un link sin pagar" : "\(sinPagar.count) links sin pagar",
                           texto: l.concepto + monto, accion: "Ver links") { estado.ir(.links) })
        }
        if let f = estado.tarjetaFisica, f.estadoFisica == .sinPedir {
            t.append(Tarea(id: "fisica", icono: "ic-tarjeta", titulo: "Pedí tu tarjeta física",
                           texto: "Sin costo, con el diseño que elijas.", accion: "Pedirla") { estado.abrir(.pedirFisica) })
        }
        if t.isEmpty {
            t.append(Tarea(id: "apartar", icono: "ic-frasco", titulo: "Armá un apartado",
                           texto: "Para el alquiler, el aguinaldo o lo que quieras.", accion: "Crear") { estado.abrir(.nuevoApartado) })
        }
        return t
    }
}

private struct TarjetaTarea: View {
    let t: Tarea
    var body: some View {
        Button {
            Haptico.tocar()
            t.alTocar()
        } label: {
            HStack(spacing: 12) {
                Icono3D(nombre: t.icono, tamano: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.titulo).font(.geist(14.5, .semi)).tracking(-0.15).foregroundStyle(Color.texto).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t.texto).font(.geist(13)).foregroundStyle(Color.sec).lineLimit(2)
                    Text(t.accion).font(.geist(13, .semi)).foregroundStyle(Color.acento).padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(maxHeight: .infinity)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
    }
}

private struct TodasLasTareas: View {
    let tareas: [Tarea]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            Cabecera("Para hacer") { Redondo("xmark", "Cerrar") { dismiss() } }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(tareas) { t in
                        TarjetaTarea(t: Tarea(id: t.id, icono: t.icono, titulo: t.titulo, texto: t.texto, accion: t.accion) {
                            dismiss()
                            t.alTocar()
                        })
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Negocios y hoy

private struct NegociosResumen: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        let cobros = estado.movimientosDeHoy.filter { $0.bolsillo == .negocio && $0.tipo.esEntrada }
        Button { estado.ir(.negocios) } label: {
            HStack(spacing: 14) {
                Icono3D(nombre: "ic-celular", tamano: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cuarzo Negocios").rotulo(.acento)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Cobraste").font(.geist(14)).foregroundStyle(Color.sec)
                        MontoChico(centavos: estado.cobradoHoy, tamano: 18, oculto: !estado.saldoVisible, conCentavos: false)
                        Text("hoy").font(.geist(14)).foregroundStyle(Color.sec)
                    }
                    Text(cobros.isEmpty ? "Ventas, links y tocar para cobrar" : "\(cobros.count) " + (cobros.count == 1 ? "cobro" : "cobros") + " · ventas y liquidaciones")
                        .font(.geist(12.5)).foregroundStyle(Color.sec).lineLimit(1)
                }
                Spacer(minLength: 0)
                Flecha()
            }
            .padding(14)
            .padding(.leading, -4)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
    }
}

private struct MovimientosDeHoy: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        let hoy = estado.movimientosDeHoy
        let lista = hoy.isEmpty ? Array(estado.panel.movimientos.prefix(3)) : Array(hoy.prefix(4))
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: hoy.isEmpty ? "Últimos" : "Hoy", accion: "Movimientos") { estado.pestana = .movimientos }
            ForEach(Array(lista.enumerated()), id: \.element.id) { i, m in
                if i > 0 { Separador() }
                Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m) }
                    .buttonStyle(Presionable(escala: 0.98))
            }
        }
    }
}

// MARK: - Cuenta nueva (15)

private struct InicioNuevo: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaldoNuevo()
            ParaArrancar().padding(.top, 18)
            Text("Atajos").rotulo().padding(.top, 24).padding(.bottom, 10)
            AccionesInicio()
        }
        .padding(.horizontal, 20)
    }
}

private struct SaldoNuevo: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Saldo total").rotulo()
            Monto(centavos: estado.saldoTotal, tamano: 40).padding(.top, 8)
            LeyendaPSP().padding(.top, 8)
            HStack(spacing: 8) {
                Button { estado.abrir(.ingresar) } label: {
                    Label("Ingresar plata", systemImage: "arrow.down.left")
                }
                .buttonStyle(.cuarzo(.principal, alto: 46))
                Button {
                    copiar(estado.usuario.alias, aviso: "Copiaste tu alias", estado: estado)
                } label: {
                    Label("Mi alias", systemImage: "doc.on.doc")
                }
                .buttonStyle(.cuarzo(.secundario, alto: 46))
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vidrio()
    }
}

private struct ParaArrancar: View {
    @Environment(Estado.self) private var estado

    private struct Paso {
        let paso: PasoArranque
        let icono: String
        let titulo: String
        let texto: String
        let hecho: String
    }

    private let pasos: [Paso] = [
        Paso(paso: .identidad, icono: "ic-escudo", titulo: "Validar tu identidad", texto: "Con tu DNI y una selfie", hecho: "Listo, con RENAPER"),
        Paso(paso: .primeraPlata, icono: "ic-monedas", titulo: "Ingresá tu primera plata", texto: "Desde cualquier banco, a tu CVU", hecho: "Listo"),
        Paso(paso: .qrNegocio, icono: "ic-qr", titulo: "Armá el QR de tu negocio", texto: "Para cobrar desde hoy", hecho: "Listo, ya podés cobrar"),
        Paso(paso: .primerApartado, icono: "ic-frasco", titulo: "Creá tu primer apartado", texto: "Alquiler, aguinaldo o lo que quieras", hecho: "Listo"),
    ]

    var body: some View {
        let hechos = pasos.filter { estado.panel.pasosHechos.contains($0.paso) }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Para arrancar").rotulo()
                Spacer()
                Text("\(hechos) de \(pasos.count)").font(.mono(11)).tracking(1.1).foregroundStyle(Color.acento)
                    .contentTransition(.numericText())
            }
            ForEach(Array(pasos.enumerated()), id: \.offset) { i, p in
                fila(p, numero: i + 1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: hechos)
    }

    private func fila(_ p: Paso, numero: Int) -> some View {
        let hecho = estado.panel.pasosHechos.contains(p.paso)
        return Button { tocar(p.paso) } label: {
            HStack(spacing: 12) {
                Icono3D(nombre: p.icono, tamano: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.titulo)
                        .font(.geist(15, .semi)).tracking(-0.15)
                        .foregroundStyle(hecho ? Color.sec : Color.texto)
                        .strikethrough(hecho, color: Color.sec.opacity(0.6))
                    Text(hecho ? p.hecho : p.texto).font(.geist(13)).foregroundStyle(Color.sec)
                }
                Spacer(minLength: 0)
                ZStack {
                    if hecho {
                        Circle().fill(Color.rosa)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.noche)
                    } else {
                        Circle().strokeBorder(Color.linea2, lineWidth: 1.5)
                        Text("\(numero)").font(.mono(12)).foregroundStyle(Color.sec)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .padding(.vertical, 12)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
        .disabled(hecho)
        .accessibilityValue(hecho ? "Hecho" : "Pendiente")
    }

    private func tocar(_ p: PasoArranque) {
        switch p {
        case .identidad: break
        case .primeraPlata: estado.abrir(.ingresar)
        case .qrNegocio: estado.abrir(.cobrar(.qr))
        case .primerApartado: estado.abrir(.nuevoApartado)
        }
    }
}

// MARK: - Tour de la primera vez

struct AnclasTour: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Tres marcas: el saldo, las acciones y el botón de Cobrar de la barra.
private struct TourInicio: View {
    let anclas: [Int: Anchor<CGRect>]
    @Binding var paso: Int
    var alTerminar: () -> Void

    private let textos: [(String, String)] = [
        ("Tu plata, en dos bolsillos.", "El del negocio y el tuyo. Tocá el ojo para ocultar el saldo."),
        ("Todo a un toque.", "Cobrar, pagar con QR, transferir y apartar plata con nombre."),
        ("Cobrá sin comisión.", "Tu QR y tu link de pago, siempre a mano en el centro."),
    ]

    var body: some View {
        GeometryReader { g in
            let r = hueco(g)
            ZStack(alignment: .topLeading) {
                Velo(hueco: r)
                    .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture { siguiente() }
                RoundedRectangle(cornerRadius: paso == 2 ? r.width / 2 : 24, style: .continuous)
                    .strokeBorder(Color.rosa.opacity(0.8), lineWidth: 1.5)
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
                    .allowsHitTesting(false)
                globo
                    .frame(width: g.size.width - 40)
                    .offset(x: 20, y: r.minY > g.size.height * 0.5 ? r.minY - 190 : r.maxY + 14)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: paso)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var globo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(paso + 1) de 3").font(.mono(11)).tracking(1.1).foregroundStyle(Color.acento)
            Text(textos[paso].0).font(.geist(18, .semi)).tracking(-0.5).foregroundStyle(Color.texto)
            Text(textos[paso].1).parrafo(14)
            HStack {
                Button("Saltar") { alTerminar() }
                    .font(.geist(14, .medio)).foregroundStyle(Color.sec).buttonStyle(.plain)
                Spacer()
                Button(paso == 2 ? "Listo" : "Siguiente") { siguiente() }
                    .buttonStyle(.cuarzo(.principal, alto: 40))
                    .frame(width: 130)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .vidrio(radio: 20)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }

    private func siguiente() {
        Haptico.tocar()
        if paso < 2 { paso += 1 } else { alTerminar() }
    }

    private func hueco(_ g: GeometryProxy) -> CGRect {
        if paso < 2, let a = anclas[paso] { return g[a].insetBy(dx: -6, dy: -6) }
        // El botón de Cobrar vive en la barra, justo abajo de esta vista.
        return CGRect(x: g.size.width / 2 - 36, y: g.size.height - 24, width: 72, height: 72)
    }

    private struct Velo: Shape {
        var hueco: CGRect
        var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
            get { AnimatablePair(AnimatablePair(hueco.minX, hueco.minY), AnimatablePair(hueco.width, hueco.height)) }
            set { hueco = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
        }
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.addRect(r.insetBy(dx: -200, dy: -400))
            let radio = hueco.width == hueco.height ? hueco.width / 2 : 24
            p.addRoundedRect(in: hueco, cornerSize: CGSize(width: radio, height: radio), style: .continuous)
            return p
        }
    }
}
