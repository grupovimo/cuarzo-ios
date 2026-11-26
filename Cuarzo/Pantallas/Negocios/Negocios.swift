import SwiftUI
import Charts

/// Lo que entró al bolsillo Negocio (cobros), con ayudas para los gráficos.
@MainActor
private enum Ventas {
    static func cobros(_ e: Estado) -> [Movimiento] {
        e.panel.movimientos.filter { $0.bolsillo == .negocio && $0.tipo.esEntrada && $0.tipo != .rendimiento }
    }
    static func delDia(_ e: Estado, _ dias: Int) -> [Movimiento] {
        let d = Fecha.calendario.date(byAdding: .day, value: dias, to: .now) ?? .now
        return cobros(e).filter { Fecha.calendario.isDate($0.fecha, inSameDayAs: d) }
    }
    static func total(_ ms: [Movimiento]) -> Centavos { ms.reduce(0) { $0 + $1.centavos } }

    struct Barra: Identifiable { let id: Int; let etiqueta: String; let centavos: Centavos; let actual: Bool }

    /// Los últimos 7 días (hoy a la derecha).
    static func semana(_ e: Estado) -> [Barra] {
        (0..<7).map { i -> Barra in
            let n = i - 6
            let d = Fecha.calendario.date(byAdding: .day, value: n, to: .now) ?? .now
            let f = DateFormatter()
            f.locale = Fecha.locale
            f.dateFormat = "EEE"
            let dia = f.string(from: d).replacingOccurrences(of: ".", with: "").capitalizandoPrimera
            return Barra(id: i, etiqueta: n == 0 ? "Hoy" : dia, centavos: total(delDia(e, n)), actual: n == 0)
        }
    }

    /// Hoy, por hora (de 8 a 20).
    static func porHora(_ e: Estado) -> [Barra] {
        let hoy = delDia(e, 0)
        return (8...20).map { h -> Barra in
            let ms = hoy.filter { Fecha.calendario.component(.hour, from: $0.fecha) == h }
            return Barra(id: h, etiqueta: "\(h)", centavos: total(ms), actual: h == Fecha.calendario.component(.hour, from: .now))
        }
    }
}

/// Gráfico de barras rosas (Swift Charts).
private struct GraficoBarras: View {
    let barras: [Ventas.Barra]
    var alto: CGFloat = 130

    var body: some View {
        Chart(barras) { b in
            BarMark(x: .value("Cuándo", b.etiqueta), y: .value("Ventas", Double(b.centavos) / 100))
                .foregroundStyle(b.actual ? AnyShapeStyle(LinearGradient(colors: [.rosa2, .rosaOsc], startPoint: .top, endPoint: .bottom))
                                          : AnyShapeStyle(Color.acento.opacity(0.35)))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let s = v.as(String.self) { Text(s).font(.mono(9.5)).foregroundStyle(Color.sec) }
                }
            }
        }
        .frame(height: alto)
        .accessibilityLabel("Gráfico de ventas")
    }
}

/// Cuarzo Negocios: ventas del día, accesos para cobrar, cobros, liquidaciones y links.
struct NegociosPantalla: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.15), tamanoBrillo: 440)
            VStack(spacing: 0) {
                CabeceraAtras("Cuarzo Negocios") {
                    Redondo("questionmark.circle", "Ayuda") { estado.abrir(.chat) }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        if Ventas.cobros(estado).isEmpty {
                            NegocioVacio()
                        } else {
                            ResumenVentas()
                            AccesosCobro().padding(.top, 14)
                            CobrosDeHoy()
                            ProximaLiquidacion()
                            LinksPendientes()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .refreshable { await estado.cargar() }
            }
        }
    }
}

private struct ResumenVentas: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        let hoy = Ventas.total(Ventas.delDia(estado, 0))
        let ayer = Ventas.total(Ventas.delDia(estado, -1))
        let cant = Ventas.delDia(estado, 0).count
        Button { estado.ir(.ventas) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Ventas de hoy").rotulo()
                    Spacer()
                    Variacion(hoy: hoy, ayer: ayer)
                }
                Monto(centavos: hoy, tamano: 40, oculto: !estado.saldoVisible, conCentavos: nil).padding(.top, 8)
                Text("\(cant) \(cant == 1 ? "cobro" : "cobros") · sin comisión con QR y link")
                    .font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 6)
                GraficoBarras(barras: Ventas.semana(estado), alto: 110).padding(.top, 16)
            }
            .padding(18)
            .vidrio()
        }
        .buttonStyle(Presionable(escala: 0.98))
        .accessibilityHint("Ver las ventas")
    }
}

/// «+ 114 % vs. ayer».
private struct Variacion: View {
    let hoy: Centavos
    let ayer: Centavos
    var body: some View {
        if ayer > 0 {
            let v = Int((Double(hoy - ayer) / Double(ayer) * 100).rounded())
            Etiqueta(texto: (v >= 0 ? "+" : "−") + "\(abs(v))\u{00A0}% vs. ayer", simbolo: v >= 0 ? "arrow.up.right" : "arrow.down.right",
                     tipo: v >= 0 ? .ok : .alerta)
        }
    }
}

/// Los cuatro accesos para cobrar.
private struct AccesosCobro: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            acceso("qrcode", "Cobrar con QR", "Con monto") { estado.abrir(.cobrar(.qr)) }
            acceso("link", "Link de pago", "Por WhatsApp") { estado.abrir(.cobrar(.link)) }
            acceso("wave.3.right", "Tocar para cobrar", "Con tarjeta") { estado.abrir(.tocarParaCobrar) }
            acceso("storefront", "QR fijo", "Para el mostrador") { estado.abrir(.cobrar(.qr)) }
        }
    }

    private func acceso(_ s: String, _ t: String, _ d: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: s).font(.system(size: 20)).foregroundStyle(Color.acento)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.acentoSuave))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.geist(15, .semi)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.85)
                    Text(d).font(.geist(12.5)).foregroundStyle(Color.sec)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .caja(radio: 18)
        }
        .buttonStyle(Presionable())
    }
}

private struct CobrosDeHoy: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        let ms = Ventas.delDia(estado, 0)
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Cobros de hoy", accion: "Ver ventas") { estado.ir(.ventas) }
            if ms.isEmpty {
                Text("Todavía no cobraste hoy. Mostrá tu QR o mandá un link.").parrafo(14).padding(.vertical, 6)
            } else {
                ForEach(ms) { m in
                    Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m, conHora: true) }.buttonStyle(.plain)
                    if m.id != ms.last?.id { Separador() }
                }
            }
        }
    }
}

private struct ProximaLiquidacion: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        if let l = estado.panel.liquidaciones.first(where: { !$0.acreditada }) {
            VStack(alignment: .leading, spacing: 0) {
                EncabezadoSeccion(titulo: "Liquidaciones", accion: "Ver todas") { estado.ir(.liquidaciones) }
                Button { estado.ir(.liquidaciones) } label: {
                    HStack(spacing: 12) {
                        Icono3D(nombre: "ic-calendario", tamano: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hoy a las 18 h te entran").font(.geist(13)).foregroundStyle(Color.sec)
                            MontoChico(centavos: l.neto, tamano: 20, oculto: !estado.saldoVisible)
                            Text("\(l.operaciones) cobros con tarjeta").font(.geist(12)).foregroundStyle(Color.sec)
                        }
                        Spacer()
                        Flecha()
                    }
                    .padding(14)
                    .caja()
                }
                .buttonStyle(Presionable(escala: 0.98))
            }
        }
    }
}

private struct LinksPendientes: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        let ls = estado.panel.links.filter { $0.estado == .pendiente }
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Links de pago", accion: "Ver todos") { estado.ir(.links) }
            if ls.isEmpty {
                Button { estado.abrir(.cobrar(.link)) } label: {
                    FilaAjuste(simbolo: "link", titulo: "Mandá un link de pago", detalle: "Te pagan desde cualquier billetera", tono: .rosa) { Flecha() }
                        .padding(.horizontal, 14).caja()
                }
                .buttonStyle(Presionable(escala: 0.98))
            } else {
                VStack(spacing: 0) {
                    ForEach(ls) { l in
                        FilaLink(link: l)
                        if l.id != ls.last?.id { Separador(sangria: 52) }
                    }
                }
                .padding(.horizontal, 14).caja()
            }
        }
    }
}

/// Vacío útil para la cuenta nueva: tres maneras de cobrar la primera venta.
private struct NegocioVacio: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Icono3D(nombre: "ic-qr", tamano: 110).frame(maxWidth: .infinity).padding(.top, 20)
            Titulo("Cobrá tu primera venta.", tamano: 28, centrado: true).frame(maxWidth: .infinity).padding(.top, 10)
            Text("Sin comisión con QR y link. La plata entra al bolsillo Negocio al instante.")
                .parrafo(15).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 10)
            VStack(spacing: 10) {
                paso(1, "Mostrá tu QR", "En el mostrador o en el celular") { estado.abrir(.cobrar(.qr)) }
                paso(2, "Mandá un link", "Por WhatsApp, para señas y turnos") { estado.abrir(.cobrar(.link)) }
                paso(3, "Tocá para cobrar", "Con la tarjeta del cliente") { estado.abrir(.tocarParaCobrar) }
            }
            .padding(.top, 24)
        }
    }

    private func paso(_ n: Int, _ t: String, _ d: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 12) {
                Text("\(n)").font(.geist(15, .semi)).foregroundStyle(Color.acento)
                    .frame(width: 34, height: 34).background(Circle().fill(Color.acentoSuave))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.geist(15, .semi)).foregroundStyle(Color.texto)
                    Text(d).font(.geist(13)).foregroundStyle(Color.sec)
                }
                Spacer()
                Flecha()
            }
            .padding(14)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
    }
}

// MARK: - Ventas

/// Ventas por día (por hora) o por semana, con su lista.
struct VentasPantalla: View {
    enum Vista: Hashable { case dia, semana }
    @Environment(Estado.self) private var estado
    @State private var vista: Vista = .dia

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.4, y: 0.15), tamanoBrillo: 380)
            VStack(spacing: 0) {
                CabeceraAtras("Ventas")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Segmentado(opciones: [(Vista.dia, "Hoy", nil), (Vista.semana, "7 días", nil)], seleccion: $vista)
                        resumen.padding(.top, 14)
                        lista
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var movimientos: [Movimiento] {
        vista == .dia ? Ventas.delDia(estado, 0) : (0...6).flatMap { Ventas.delDia(estado, -$0) }
    }

    private var resumen: some View {
        let ms = movimientos
        return VStack(alignment: .leading, spacing: 0) {
            Text(vista == .dia ? "Vendiste hoy" : "Vendiste en 7 días").rotulo()
            Monto(centavos: Ventas.total(ms), tamano: 38, oculto: !estado.saldoVisible, conCentavos: nil).padding(.top, 8)
            HStack(spacing: 16) {
                dato("Cobros", "\(ms.count)")
                dato("Ticket promedio", ms.isEmpty ? "—" : Formato.plata(Ventas.total(ms) / ms.count, centavos: false))
            }
            .padding(.top, 10)
            GraficoBarras(barras: vista == .dia ? Ventas.porHora(estado) : Ventas.semana(estado), alto: 150).padding(.top, 16)
        }
        .padding(18)
        .vidrio()
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vista)
    }

    private func dato(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.geist(12)).foregroundStyle(Color.sec)
            Text(v).font(.geist(15, .semi)).monospacedDigit().foregroundStyle(Color.texto)
        }
    }

    private var lista: some View {
        let grupos = estado.porDia(movimientos)
        return VStack(alignment: .leading, spacing: 0) {
            if grupos.isEmpty {
                Vacio(icono: "ic-qr", titulo: "Sin ventas todavía.", texto: "Cuando cobres, las ves acá al instante.",
                      accion: "Cobrar con QR") { estado.abrir(.cobrar(.qr)) }
            }
            ForEach(grupos, id: \.dia) { g in
                EncabezadoSeccion(titulo: Fecha.encabezado(g.dia))
                ForEach(g.movimientos) { m in
                    Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m, conHora: true) }.buttonStyle(.plain)
                    if m.id != g.movimientos.last?.id { Separador() }
                }
            }
        }
    }
}

// MARK: - Links

/// Un link de pago: concepto, monto, estado y acciones.
private struct FilaLink: View {
    let link: LinkDePago
    @Environment(Estado.self) private var estado

    var body: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: "", tono: link.estado == .pagado ? .menta : link.estado == .vencido ? .neutro : .rosa,
                   simbolo: link.estado == .pagado ? "checkmark" : "link", tamano: 40, cuadrado: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.concepto).font(.geist(15, .medio)).foregroundStyle(Color.texto).lineLimit(1)
                Text(detalle).font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(link.centavos.map { Formato.plata($0) } ?? "Monto libre").font(.geist(15, .medio)).monospacedDigit()
                    .foregroundStyle(link.estado == .pagado ? Color.acento : Color.texto)
                if link.estado == .pendiente, let url = URL(string: link.url) {
                    HStack(spacing: 14) {
                        Button { copiar(link.url, aviso: "Copiamos el link", estado: estado) } label: {
                            Image(systemName: "doc.on.doc").font(.system(size: 14))
                        }
                        .accessibilityLabel("Copiar link")
                        ShareLink(item: url, message: Text(link.concepto + (link.centavos.map { " · " + Formato.plata($0) } ?? "") + ". Pagalo acá:")) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                        }
                        .accessibilityLabel("Compartir link")
                    }
                    .foregroundStyle(Color.acento)
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minHeight: 64)
    }

    private var detalle: String {
        switch link.estado {
        case .pendiente: return "Esperando el pago · " + Fecha.encabezado(link.creado)
        case .pagado: return "Pagó " + (link.pagadoPor ?? "alguien") + " · " + Fecha.encabezado(link.creado)
        case .vencido: return "Venció · " + Fecha.diaMes(link.creado)
        }
    }
}

/// Todos los links de pago, por estado.
struct LinksPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var filtro: LinkDePago.Estado? = nil

    private var links: [LinkDePago] { estado.panel.links.filter { filtro == nil || $0.estado == filtro } }

    var body: some View {
        ZStack(alignment: .bottom) {
            FondoCuarzo(brillo: CGPoint(x: 0.4, y: 0.1), tamanoBrillo: 360)
            VStack(spacing: 0) {
                CabeceraAtras("Links de pago")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Chip(texto: "Todos", on: filtro == nil) { filtro = nil }
                        Chip(texto: "Pendientes", on: filtro == .pendiente) { filtro = .pendiente }
                        Chip(texto: "Pagados", on: filtro == .pagado) { filtro = .pagado }
                        Chip(texto: "Vencidos", on: filtro == .vencido) { filtro = .vencido }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 8)
                ScrollView {
                    if links.isEmpty {
                        Vacio(icono: "ic-transferir", titulo: "No hay links acá.", texto: "Mandá uno por WhatsApp y te pagan desde cualquier billetera.",
                              accion: "Crear un link") { estado.abrir(.cobrar(.link)) }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(links) { l in
                                FilaLink(link: l)
                                if l.id != links.last?.id { Separador(sangria: 52) }
                            }
                        }
                        .padding(.horizontal, 14).caja()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                .scrollIndicators(.hidden)
                .animation(.easeInOut(duration: 0.2), value: filtro)
            }
            Button { estado.abrir(.cobrar(.link)) } label: { Label("Nuevo link", systemImage: "plus") }
                .buttonStyle(.principal)
                .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

// MARK: - Liquidaciones

/// Lo que se acredita de los cobros con tarjeta.
struct LiquidacionesPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var abierta: String?

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.4, y: 0.12), tamanoBrillo: 380)
            VStack(spacing: 0) {
                CabeceraAtras("Liquidaciones")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        cabecera
                        if estado.panel.liquidaciones.isEmpty {
                            Vacio(icono: "ic-calendario", titulo: "Sin liquidaciones.", texto: "Aparecen cuando cobrás con tarjeta.",
                                  accion: "Tocar para cobrar") { estado.abrir(.tocarParaCobrar) }
                        }
                        ForEach(estado.panel.liquidaciones) { l in
                            FilaLiquidacion(liquidacion: l, abierta: abierta == l.id) {
                                Haptico.tocar()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { abierta = abierta == l.id ? nil : l.id }
                            }
                            .padding(.top, 10)
                        }
                        Text("Con QR y link no hay comisión. Con tarjeta, 1,5\u{00A0}% por cobro (dato de muestra). Se acredita el mismo día a las 18 h.")
                            .parrafo(12).padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var cabecera: some View {
        let pendiente = estado.panel.liquidaciones.filter { !$0.acreditada }.reduce(0) { $0 + $1.neto }
        return VStack(alignment: .leading, spacing: 6) {
            Text("A acreditar hoy").rotulo()
            Monto(centavos: pendiente, tamano: 36, oculto: !estado.saldoVisible)
            Text("Entra al bolsillo Negocio a las 18 h.").font(.geist(13)).foregroundStyle(Color.sec)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .vidrio()
    }
}

private struct FilaLiquidacion: View {
    let liquidacion: Liquidacion
    let abierta: Bool
    let alTocar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: alTocar) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fecha.encabezado(liquidacion.fecha)).font(.geist(15, .medio)).foregroundStyle(Color.texto)
                        Text("\(liquidacion.operaciones) cobros con tarjeta").font(.geist(13)).foregroundStyle(Color.sec)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Formato.plata(liquidacion.neto)).font(.geist(15, .medio)).monospacedDigit().foregroundStyle(Color.texto)
                        Etiqueta(texto: liquidacion.acreditada ? "Acreditada" : "Hoy 18 h", tipo: liquidacion.acreditada ? .ok : .rosa)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ter)
                        .rotationEffect(.degrees(abierta ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if abierta {
                VStack(spacing: 0) {
                    Separador().padding(.vertical, 8)
                    RenglonTicket(etiqueta: "Cobraste", valor: Formato.plata(liquidacion.bruto))
                    RenglonTicket(etiqueta: "Comisión 1,5\u{00A0}%", valor: "−\u{00A0}" + Formato.plata(liquidacion.comision))
                    RenglonTicket(etiqueta: "Te entra", valor: Formato.plata(liquidacion.neto))
                    RenglonTicket(etiqueta: "Liquidación", valor: liquidacion.id, mono: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .caja()
        .clipped()
    }
}
