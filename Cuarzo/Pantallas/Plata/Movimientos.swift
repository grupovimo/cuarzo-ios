import SwiftUI

/// Filtro rápido de chips (pantalla 11).
private enum FiltroRapido: String, CaseIterable, Identifiable {
    case todo = "Todo", negocio = "Negocio", personal = "Personal", entradas = "Entradas", salidas = "Salidas"
    var id: String { rawValue }
}

/// Filtros de la hoja (tipo, período y montos).
struct FiltrosMovimientos: Equatable {
    enum Grupo: String, CaseIterable, Identifiable {
        case cobros = "Cobros", pagos = "Pagos", transferencias = "Transferencias", tarjeta = "Tarjeta", pases = "Pases y apartados"
        var id: String { rawValue }
        func incluye(_ t: TipoMovimiento) -> Bool {
            switch self {
            case .cobros: return [.cobroQR, .cobroLink, .cobroTarjeta, .ingreso, .rendimiento].contains(t)
            case .pagos: return t == .pagoQR
            case .transferencias: return [.transferenciaEnviada, .transferenciaRecibida].contains(t)
            case .tarjeta: return t == .compraTarjeta
            case .pases: return [.pase, .apartado].contains(t)
            }
        }
    }
    enum Periodo: String, CaseIterable, Identifiable {
        case todo = "Todo", semana = "Últimos 7 días", mes = "Este mes", anterior = "Mes pasado"
        var id: String { rawValue }
        func incluye(_ d: Date, hoy: Date = .now) -> Bool {
            let c = Fecha.calendario
            switch self {
            case .todo: return true
            case .semana: return Fecha.dias(desde: d, hasta: hoy) < 7
            case .mes: return c.isDate(d, equalTo: hoy, toGranularity: .month)
            case .anterior:
                guard let a = c.date(byAdding: .month, value: -1, to: hoy) else { return false }
                return c.isDate(d, equalTo: a, toGranularity: .month)
            }
        }
    }

    var grupos: Set<Grupo> = []
    var periodo: Periodo = .todo
    var minimo: Centavos = 0
    var maximo: Centavos = 0

    var activos: Int {
        (grupos.isEmpty ? 0 : 1) + (periodo == .todo ? 0 : 1) + (minimo > 0 || maximo > 0 ? 1 : 0)
    }

    func incluye(_ m: Movimiento) -> Bool {
        if !grupos.isEmpty && !grupos.contains(where: { $0.incluye(m.tipo) }) { return false }
        if !periodo.incluye(m.fecha) { return false }
        let a = abs(m.centavos)
        if minimo > 0 && a < minimo { return false }
        if maximo > 0 && a > maximo { return false }
        return true
    }
}

/// Movimientos (pantalla 11): búsqueda, chips, resumen del mes y la lista por día.
struct MovimientosPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var busqueda = ""
    @State private var rapido: FiltroRapido = .todo
    @State private var filtros = FiltrosMovimientos()
    @State private var verFiltros = false
    @State private var verExportar = false

    var body: some View {
        ZStack(alignment: .top) {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                TituloPestana("Movimientos") {
                    Redondo("arrow.down.to.line", "Descargar resumen") { verExportar = true }
                        .disabled(estado.panel.movimientos.isEmpty)
                    Redondo("line.3.horizontal.decrease", "Filtros", punto: filtros.activos > 0) { verFiltros = true }
                }
                .padding(.top, 4)
                if estado.panel.movimientos.isEmpty {
                    sinMovimientos
                } else {
                    lista
                }
            }
        }
        .sheet(isPresented: $verFiltros) {
            HojaFiltros(filtros: $filtros, cuenta: { f in estado.panel.movimientos.filter(f.incluye).count })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
        .sheet(isPresented: $verExportar) {
            HojaExportar()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
    }

    private var sinMovimientos: some View {
        ScrollView {
            FranjaSinConexion().padding(.horizontal, 20)
            Vacio(icono: "ic-monedas", titulo: "Todavía no hay movimientos.",
                  texto: "Cuando te entre o salga plata, la vas a ver acá, ordenada por día.", accion: "Ingresar plata") {
                estado.abrir(.ingresar)
            }
            .padding(.top, 40)
        }
        .refreshable { await estado.cargar() }
    }

    private var lista: some View {
        let filtrados = filtrar()
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                Buscador(texto: $busqueda)
                chips
                FranjaSinConexion().padding(.top, 12)
                ResumenMes().padding(.top, 14)
                if filtrados.isEmpty {
                    Vacio(icono: "ic-comprobante", titulo: "No encontramos nada.",
                          texto: "Probá con otro nombre, monto o CUIT.", accion: "Limpiar la búsqueda") {
                        withAnimation {
                            busqueda = ""
                            rapido = .todo
                            filtros = FiltrosMovimientos()
                        }
                    }
                } else {
                    ForEach(estado.porDia(filtrados), id: \.dia) { grupo in
                        GrupoDia(dia: grupo.dia, movimientos: grupo.movimientos)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: filtrados.map(\.id))
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await estado.cargar() }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FiltroRapido.allCases) { f in
                    Chip(texto: f.rawValue, on: rapido == f) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { rapido = f }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .padding(.top, 12)
    }

    private func filtrar() -> [Movimiento] {
        let q = busqueda.trimmingCharacters(in: .whitespaces).paraBuscar
        let digitos = q.filter(\.isNumber)
        return estado.panel.movimientos.filter { m in
            switch rapido {
            case .todo: break
            case .negocio: if m.bolsillo != .negocio { return false }
            case .personal: if m.bolsillo != .personal { return false }
            case .entradas: if m.centavos <= 0 || m.tipo == .pase { return false }
            case .salidas: if m.centavos >= 0 { return false }
            }
            if !filtros.incluye(m) { return false }
            guard !q.isEmpty else { return true }
            if m.titulo.paraBuscar.contains(q) || m.detalle.paraBuscar.contains(q) || m.id.paraBuscar.contains(q) { return true }
            if !digitos.isEmpty {
                let monto = String(abs(m.centavos) / 100)
                let cuit = (m.contraparteCuit ?? "").filter(\.isNumber)
                if monto.hasPrefix(digitos) || cuit.contains(digitos) { return true }
            }
            return false
        }
    }
}

private struct Buscador: View {
    @Binding var texto: String
    @FocusState private var foco: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.sec)
            TextField("", text: $texto, prompt: Text("Buscá por nombre, monto o CUIT").foregroundStyle(Color.sec))
                .font(.geist(15))
                .foregroundStyle(Color.texto)
                .focused($foco)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ter)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .caja(radio: 14, seleccionada: foco)
        .padding(.top, 10)
    }
}

/// «Entró en nov.» / «Salió en nov.» con las minibarras de los últimos 7 días.
private struct ResumenMes: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        let hoy = Date.now
        let delMes = estado.panel.movimientos.filter { Fecha.calendario.isDate($0.fecha, equalTo: hoy, toGranularity: .month) && $0.tipo != .pase }
        let entro = delMes.filter { $0.centavos > 0 }.reduce(0) { $0 + $1.centavos }
        let salio = delMes.filter { $0.centavos < 0 }.reduce(0) { $0 - $1.centavos }
        HStack(spacing: 10) {
            Cuadro(titulo: "Entró en " + Fecha.mesCorto(hoy), centavos: entro, barras: barras(entrada: true), entrada: true)
            Cuadro(titulo: "Salió en " + Fecha.mesCorto(hoy), centavos: salio, barras: barras(entrada: false), entrada: false)
        }
    }

    private func barras(entrada: Bool) -> [Double] {
        let c = Fecha.calendario
        let valores: [Centavos] = (0..<7).reversed().map { d in
            guard let dia = c.date(byAdding: .day, value: -d, to: .now) else { return 0 }
            return estado.panel.movimientos
                .filter { c.isDate($0.fecha, inSameDayAs: dia) && $0.tipo != .pase && (entrada ? $0.centavos > 0 : $0.centavos < 0) }
                .reduce(0) { $0 + abs($1.centavos) }
        }
        let tope = max(1, valores.max() ?? 1)
        return valores.map { max(0.12, Double($0) / Double(tope)) }
    }

    private struct Cuadro: View {
        let titulo: String
        let centavos: Centavos
        let barras: [Double]
        let entrada: Bool
        @Environment(Estado.self) private var estado

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(titulo).rotulo()
                MontoChico(centavos: centavos, tamano: 18, color: entrada ? .acento : .texto,
                           oculto: !estado.saldoVisible, conCentavos: false)
                    .padding(.top, 6)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(barras.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(ultima: i == barras.count - 1))
                            .frame(height: 18 * barras[i])
                    }
                }
                .frame(height: 18, alignment: .bottom)
                .padding(.top, 8)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .caja(radio: 16)
        }

        private func color(ultima: Bool) -> Color {
            if entrada { return ultima ? .acento : Color.acento.opacity(0.35) }
            return ultima ? .sec : .linea2
        }
    }
}

private struct GrupoDia: View {
    let dia: Date
    let movimientos: [Movimiento]
    @Environment(Estado.self) private var estado

    var body: some View {
        let neto = movimientos.filter { $0.tipo != .pase }.reduce(0) { $0 + $1.centavos }
        let esHoy = Fecha.calendario.isDateInToday(dia)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(Fecha.encabezado(dia)).rotulo(esHoy ? .acento : .sec)
                Spacer()
                Text(estado.saldoVisible ? Formato.conSigno(neto) : "•••")
                    .font(.mono(11)).tracking(0.9).foregroundStyle(Color.sec)
            }
            .padding(.top, 18)
            .padding(.bottom, 2)
            ForEach(Array(movimientos.enumerated()), id: \.element.id) { i, m in
                if i > 0 { Separador() }
                Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m, conHora: esHoy) }
                    .buttonStyle(Presionable(escala: 0.98))
            }
        }
    }
}

// MARK: - Hoja de filtros

private struct HojaFiltros: View {
    @Binding var filtros: FiltrosMovimientos
    let cuenta: (FiltrosMovimientos) -> Int
    @State private var borrador = FiltrosMovimientos()
    @State private var minimo = ""
    @State private var maximo = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Cabecera("Filtros") {
                Redondo("xmark", "Cerrar") { dismiss() }
            } derecha: {
                Button("Limpiar") {
                    Haptico.seleccion()
                    borrador = FiltrosMovimientos(); minimo = ""; maximo = ""
                }
                .font(.geist(15, .medio)).foregroundStyle(Color.acento).buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tipo").rotulo().padding(.top, 8)
                    ChipsEnFlujo(items: FiltrosMovimientos.Grupo.allCases.map(\.rawValue),
                               on: { t in borrador.grupos.contains { $0.rawValue == t } }) { t in
                        if let g = FiltrosMovimientos.Grupo(rawValue: t) {
                            if borrador.grupos.contains(g) { borrador.grupos.remove(g) } else { borrador.grupos.insert(g) }
                        }
                    }
                    .padding(.top, 10)
                    Text("Período").rotulo().padding(.top, 24)
                    ChipsEnFlujo(items: FiltrosMovimientos.Periodo.allCases.map(\.rawValue),
                               on: { $0 == borrador.periodo.rawValue }) { t in
                        borrador.periodo = FiltrosMovimientos.Periodo(rawValue: t) ?? .todo
                    }
                    .padding(.top, 10)
                    Text("Monto").rotulo().padding(.top, 24)
                    HStack(spacing: 10) {
                        CampoMonto(titulo: "Desde", texto: $minimo)
                        CampoMonto(titulo: "Hasta", texto: $maximo)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
            }
            Button("Ver \(cuenta(armado)) movimientos") {
                filtros = armado
                dismiss()
            }
            .buttonStyle(.principal)
            .padding(20)
        }
        .onAppear {
            borrador = filtros
            minimo = filtros.minimo > 0 ? String(filtros.minimo / 100) : ""
            maximo = filtros.maximo > 0 ? String(filtros.maximo / 100) : ""
        }
    }

    private var armado: FiltrosMovimientos {
        var f = borrador
        f.minimo = (Int(minimo.filter(\.isNumber)) ?? 0) * 100
        f.maximo = (Int(maximo.filter(\.isNumber)) ?? 0) * 100
        return f
    }
}

private struct CampoMonto: View {
    let titulo: String
    @Binding var texto: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.geist(12)).foregroundStyle(Color.sec)
            HStack(spacing: 4) {
                Text("$").font(.geist(16, .medio)).foregroundStyle(Color.sec)
                TextField("0", text: $texto).keyboardType(.numberPad).font(.geist(16, .medio)).foregroundStyle(Color.texto)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .caja(radio: 14)
    }
}

/// Chips que bajan de renglón cuando no entran.
struct ChipsEnFlujo: View {
    let items: [String]
    let on: (String) -> Bool
    let tocar: (String) -> Void

    var body: some View {
        DisposicionFlujo(espacio: 8) {
            ForEach(items, id: \.self) { t in
                Chip(texto: t, on: on(t)) { withAnimation(.spring(response: 0.3)) { tocar(t) } }
            }
        }
    }
}

struct DisposicionFlujo: Layout {
    var espacio: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? 375
        var x: CGFloat = 0, y: CGFloat = 0, fila: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > ancho && x > 0 { x = 0; y += fila + espacio; fila = 0 }
            x += t.width + espacio
            fila = max(fila, t.height)
        }
        return CGSize(width: ancho, height: y + fila)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, fila: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > b.maxX && x > b.minX { x = b.minX; y += fila + espacio; fila = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espacio
            fila = max(fila, t.height)
        }
    }
}

// MARK: - Exportar

private struct HojaExportar: View {
    enum Formato2: String, CaseIterable { case pdf = "PDF", csv = "CSV (Excel)" }
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var periodo: FiltrosMovimientos.Periodo = .mes
    @State private var formato: Formato2 = .pdf
    @State private var archivo: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Cabecera("Descargar resumen") { Redondo("xmark", "Cerrar") { dismiss() } }
            VStack(alignment: .leading, spacing: 0) {
                Text("Período").rotulo()
                ChipsEnFlujo(items: [FiltrosMovimientos.Periodo.mes, .anterior, .todo].map(\.rawValue),
                           on: { $0 == periodo.rawValue }) { periodo = FiltrosMovimientos.Periodo(rawValue: $0) ?? .mes }
                    .padding(.top, 10)
                Text("Formato").rotulo().padding(.top, 22)
                Segmentado(opciones: [(Formato2.pdf, "PDF", "doc.richtext"), (Formato2.csv, "CSV", "tablecells")], seleccion: $formato)
                    .padding(.top, 10)
                Text("\(lista.count) movimientos · " + nombre).font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 14)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 16)
            Group {
                if let archivo {
                    ShareLink(item: archivo) { Label("Descargar " + formato.rawValue.components(separatedBy: " ")[0], systemImage: "arrow.down.to.line") }
                        .buttonStyle(.principal)
                } else {
                    Button {} label: { ProgressView().tint(Color.noche) }.buttonStyle(.principal).disabled(true)
                }
            }
            .padding(20)
        }
        .task(id: "\(periodo.rawValue)-\(formato.rawValue)") { generar() }
    }

    private var lista: [Movimiento] { estado.panel.movimientos.filter { periodo.incluye($0.fecha) } }
    private var nombre: String { "Cuarzo " + periodo.rawValue.lowercased() }

    private func generar() {
        archivo = nil
        let movs = lista
        if formato == .csv {
            var t = "Fecha;Hora;Detalle;Concepto;Bolsillo;Monto;Operación\n"
            for m in movs {
                let monto = String(format: "%.2f", Double(m.centavos) / 100).replacingOccurrences(of: ".", with: ",")
                t += [Fecha.corta(m.fecha) + "/" + String(Fecha.calendario.component(.year, from: m.fecha)), Fecha.hora(m.fecha), m.titulo,
                      m.detalle, m.bolsillo.nombre, monto, m.id].joined(separator: ";") + "\n"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre + ".csv")
            try? t.write(to: url, atomically: true, encoding: .utf8)
            archivo = url
        } else {
            archivo = pdf(de: ResumenPDF(movimientos: movs, usuario: estado.usuario, titulo: periodo.rawValue), nombre: nombre, ancho: 595)
        }
    }
}

/// El resumen en PDF (claro, para imprimir).
private struct ResumenPDF: View {
    let movimientos: [Movimiento]
    let usuario: Usuario
    let titulo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image("horizontal-claro").resizable().scaledToFit().frame(height: 22)
                Spacer()
                Text("Resumen · " + titulo).font(.mono(10)).tracking(1.2).textCase(.uppercase).foregroundStyle(Color.rosaTinta)
            }
            Text(usuario.nombreCompleto + " · CUIT " + usuario.cuit).font(.geist(12)).foregroundStyle(Color.tintaSec).padding(.top, 12)
            Text("CVU " + usuario.cvu + " · " + usuario.alias).font(.mono(10)).foregroundStyle(Color.tintaSec).padding(.top, 2)
            Rectangle().fill(Color.lineaPapel).frame(height: 1).padding(.vertical, 14)
            ForEach(movimientos) { m in
                HStack(alignment: .firstTextBaseline) {
                    Text(Fecha.corta(m.fecha) + " " + Fecha.hora(m.fecha)).font(.mono(10)).foregroundStyle(Color.tintaSec).frame(width: 74, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.titulo).font(.geist(12, .medio))
                        Text(m.subtitulo).font(.geist(10)).foregroundStyle(Color.tintaSec)
                    }
                    Spacer()
                    Text(m.tipo == .pase ? Formato.plata(m.centavos, centavos: true) : Formato.conSigno(m.centavos, centavos: true))
                        .font(.geist(12, .medio)).monospacedDigit()
                }
                .foregroundStyle(Color.noche)
                .padding(.vertical, 5)
            }
            Text("Cuenta provista por [PSP socio].").font(.geist(10)).foregroundStyle(Color.tintaSec).padding(.top, 18)
        }
        .padding(36)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Detalle

/// El detalle de un movimiento: el papel del comprobante y qué se puede hacer con él.
struct DetalleMovimiento: View {
    let id: String
    @Environment(Estado.self) private var estado
    @State private var compartible: UIImage?

    var body: some View {
        ZStack(alignment: .top) {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.1), tamanoBrillo: 340)
            VStack(spacing: 0) {
                CabeceraAtras("Movimiento") {
                    if let compartible, let m = estado.movimiento(id) {
                        ShareLink(item: ImagenCompartible(imagen: compartible, nombre: "Comprobante " + m.id),
                                  preview: SharePreview("Comprobante de Cuarzo", image: Image(uiImage: compartible))) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.texto)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.sup2).overlay(Circle().strokeBorder(Color.linea, lineWidth: 1)))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Compartir comprobante")
                    }
                }
                if let m = estado.movimiento(id) {
                    contenido(m)
                } else {
                    Vacio(icono: "ic-comprobante", titulo: "No encontramos este movimiento.",
                          texto: "Puede que se esté procesando. Tu plata está a salvo.")
                    Spacer()
                }
            }
        }
        .task(id: id) {
            guard let m = estado.movimiento(id) else { return }
            compartible = imagen(de: PapelComprobante(m: m, usuario: estado.usuario).padding(20).background(Color.nacar))
        }
    }

    private func contenido(_ m: Movimiento) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                AvatarMovimiento(m: m, tamano: 56)
                Text(m.titulo).font(.geist(18, .semi)).tracking(-0.4).foregroundStyle(Color.texto)
                    .multilineTextAlignment(.center).padding(.top, 12)
                Text(m.tipo.nombre + " · " + m.bolsillo.nombre).font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 2)
                Monto(centavos: m.centavos, tamano: 40, color: m.centavos > 0 && m.tipo != .pase ? .acento : .texto,
                      oculto: !estado.saldoVisible, signo: m.tipo != .pase)
                    .padding(.top, 12)
                Etiqueta(texto: m.estado.nombre, simbolo: m.estado == .listo ? "checkmark" : "clock",
                         tipo: m.estado == .listo ? .ok : .alerta)
                    .padding(.top, 10)
                PapelComprobante(m: m, usuario: estado.usuario).padding(.top, 22)
                acciones(m).padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func acciones(_ m: Movimiento) -> some View {
        let contacto = estado.panel.contactos.first { $0.cvu == m.contraparteCuenta || $0.nombre == m.titulo }
        VStack(spacing: 0) {
            if let contacto, m.tipo == .transferenciaEnviada || m.tipo == .transferenciaRecibida {
                Button { estado.abrir(.transferir(contacto)) } label: {
                    FilaAjuste(simbolo: "arrow.up.right", titulo: m.tipo == .transferenciaEnviada ? "Transferirle de nuevo" : "Transferirle",
                               detalle: contacto.alias, tono: .rosa) { Flecha() }
                }
                .buttonStyle(Presionable(escala: 0.98))
                Separador(sangria: 48)
            }
            if m.tipo == .pagoQR {
                Button { estado.abrir(.pagar) } label: {
                    FilaAjuste(simbolo: "qrcode.viewfinder", titulo: "Pagar otra vez con QR", tono: .rosa) { Flecha() }
                }
                .buttonStyle(Presionable(escala: 0.98))
                Separador(sangria: 48)
            }
            Button {
                copiar(m.id, aviso: "Copiaste el número de operación", estado: estado)
            } label: {
                FilaAjuste(simbolo: "number", titulo: "Copiar número de operación", detalle: m.id) {
                    Image(systemName: "doc.on.doc").foregroundStyle(Color.ter)
                }
            }
            .buttonStyle(Presionable(escala: 0.98))
            Separador(sangria: 48)
            Button { estado.abrir(.chat) } label: {
                FilaAjuste(simbolo: "exclamationmark.bubble", titulo: "No reconozco este movimiento",
                           detalle: "Te contesta una persona, en minutos.", tono: .cobre) { Flecha() }
            }
            .buttonStyle(Presionable(escala: 0.98))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .caja()
    }
}
