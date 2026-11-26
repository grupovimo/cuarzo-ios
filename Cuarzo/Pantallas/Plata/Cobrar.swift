import SwiftUI

/// Cobrar (pantalla 06): QR propio con monto o link de pago para compartir.
struct CobrarPantalla: View {
    var modo: ModoCobro = .qr
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cobroMonto") private var montoGuardado = 1_500_000
    @AppStorage("cobroConcepto") private var conceptoGuardado = "Corte y color"
    @State private var seleccion: ModoCobro = .qr
    @State private var editar = false
    @State private var verFijo = false
    @State private var verAyuda = false

    var body: some View {
        ZStack(alignment: .top) {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.45), tamanoBrillo: 420)
            VStack(spacing: 0) {
                Cabecera("Cobrar") {
                    Redondo("xmark", "Cerrar") { dismiss() }
                } derecha: {
                    Redondo("questionmark.circle", "Cómo cobrar") { verAyuda = true }
                }
                Segmentado(opciones: [(ModoCobro.qr, "Con QR", "qrcode"), (ModoCobro.link, "Con link", "link")], seleccion: $seleccion)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                ScrollView {
                    Group {
                        if seleccion == .qr {
                            CobroQR(monto: montoGuardado, concepto: conceptoGuardado, editar: { editar = true }, verFijo: { verFijo = true })
                                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
                        } else {
                            CobroLink(monto: montoGuardado, concepto: conceptoGuardado, editar: { editar = true })
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            seleccion = modo
            Task { await estado.marcarPaso(.qrNegocio) }
        }
        .sheet(isPresented: $editar) {
            EditarCobro(monto: $montoGuardado, concepto: $conceptoGuardado)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
        .sheet(isPresented: $verFijo) {
            QRFijoHoja()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
        .sheet(isPresented: $verAyuda) {
            AyudaCobrar()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.fondo)
        }
    }
}

/// Link de cobro con monto y concepto (lo que codifica el QR).
private func linkDeCobro(alias: String, monto: Centavos, concepto: String) -> String {
    var c = URLComponents(string: "https://cuarzo.ar/c/" + alias)
    var q: [URLQueryItem] = []
    if monto > 0 { q.append(URLQueryItem(name: "m", value: String(monto / 100))) }
    if !concepto.isEmpty { q.append(URLQueryItem(name: "c", value: concepto)) }
    c?.queryItems = q.isEmpty ? nil : q
    return c?.url?.absoluteString ?? "https://cuarzo.ar/c/" + alias
}

private func mensajeCobro(monto: Centavos, concepto: String, link: String) -> String {
    let cuanto = monto > 0 ? Formato.plata(monto) : "lo que quieras"
    let por = concepto.isEmpty ? "" : " por " + concepto
    return "Pagame " + cuanto + por + " con Cuarzo, sin comisión: " + link
}

// MARK: - Con QR

private struct CobroQR: View {
    let monto: Centavos
    let concepto: String
    let editar: () -> Void
    let verFijo: () -> Void
    @Environment(Estado.self) private var estado

    var body: some View {
        let link = linkDeCobro(alias: estado.usuario.alias, monto: monto, concepto: concepto)
        VStack(spacing: 0) {
            encabezadoMonto
            tarjetaQR(link)
            Esperando().padding(.top, 12)
            HStack(spacing: 10) {
                Button {
                    copiar(link, aviso: "Copiaste el link de cobro", estado: estado)
                } label: { Label("Copiar link", systemImage: "doc.on.doc") }
                    .buttonStyle(.cuarzo(.secundario, alto: 50))
                ShareLink(item: URL(string: link)!, subject: Text("Cobro de " + estado.usuario.negocio),
                          message: Text(mensajeCobro(monto: monto, concepto: concepto, link: link))) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.cuarzo(.principal, alto: 50))
            }
            .padding(.top, 16)
            Button(action: verFijo) {
                HStack(spacing: 12) {
                    Avatar(iniciales: "", tono: .rosa, simbolo: "storefront", tamano: 40, cuadrado: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("QR fijo del local").font(.geist(15, .medio)).foregroundStyle(Color.texto)
                        Text("Sin monto, para el mostrador").font(.geist(13)).foregroundStyle(Color.sec)
                    }
                    Spacer()
                    Flecha()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 68)
                .caja()
            }
            .buttonStyle(Presionable(escala: 0.98))
            .padding(.top, 12)
        }
    }

    private var encabezadoMonto: some View {
        VStack(spacing: 0) {
            Text("Le cobrás").rotulo()
            Button(action: editar) {
                if monto > 0 {
                    Monto(centavos: monto, tamano: 46)
                } else {
                    Text("Sin monto").font(.geistFijo(34, .semi)).tracking(-1.4).foregroundStyle(Color.texto)
                }
            }
            .buttonStyle(Presionable(escala: 0.97))
            .padding(.top, 6)
            .accessibilityHint("Cambiar el monto")
            Button(action: editar) {
                HStack(spacing: 4) {
                    Text(concepto.isEmpty ? "Sin concepto" : "Por").foregroundStyle(Color.sec)
                    if !concepto.isEmpty { Text(concepto).foregroundStyle(Color.texto).fontWeight(.medium) }
                    Text("·").foregroundStyle(Color.sec)
                    Text("Editar").foregroundStyle(Color.acento)
                }
                .font(.geist(14))
                .lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private func tarjetaQR(_ link: String) -> some View {
        VStack(spacing: 0) {
            QRCuarzo(contenido: link, tamano: 200)
                .id(link)
            Text(estado.usuario.negocio).font(.geist(16, .semi)).tracking(-0.32).foregroundStyle(Color.texto).padding(.top, 12)
            HStack(spacing: 4) {
                Text("Entra al bolsillo").foregroundStyle(Color.sec)
                Text("Negocio").foregroundStyle(Color.acento)
            }
            .font(.geist(13))
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(width: 262)
        .vidrio()
        .padding(.top, 18)
    }
}

/// «Esperando el pago…» con un punto que late.
private struct Esperando: View {
    @State private var late = false
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.ok).frame(width: 7, height: 7)
                .scaleEffect(late ? 1.4 : 0.8)
                .opacity(late ? 0.5 : 1)
            Text("Esperando el pago… te avisamos al toque").font(.geist(12.5)).foregroundStyle(Color.sec)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { late = true } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Con link

private struct CobroLink: View {
    let monto: Centavos
    let concepto: String
    let editar: () -> Void
    @Environment(Estado.self) private var estado
    @State private var creado: LinkDePago?
    @State private var creando = false
    @State private var error: String?
    @State private var conMonto = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let creado {
                LinkCreado(link: creado) { withAnimation(.spring(response: 0.4)) { self.creado = nil } }
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                formulario
            }
            ultimos.padding(.top, 26)
        }
        .padding(.top, 18)
    }

    private var formulario: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: editar) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Monto").rotulo()
                        Spacer()
                        Text("Cambiar").font(.geist(14, .medio)).foregroundStyle(Color.acento)
                    }
                    if conMonto && monto > 0 {
                        Monto(centavos: monto, tamano: 36)
                    } else {
                        Text("Lo pone quien paga").font(.geist(20, .semi)).foregroundStyle(Color.texto)
                    }
                    Separador()
                    HStack {
                        Text("Concepto").font(.geist(14)).foregroundStyle(Color.sec)
                        Spacer()
                        Text(concepto.isEmpty ? "Sin concepto" : concepto).font(.geist(15, .medio)).foregroundStyle(Color.texto)
                    }
                }
                .padding(18)
                .vidrio()
            }
            .buttonStyle(Presionable(escala: 0.98))
            HStack {
                Text("Pedir un monto fijo").font(.geist(15)).foregroundStyle(Color.texto)
                Spacer()
                Interruptor(on: $conMonto, etiqueta: "Pedir un monto fijo")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            if let error {
                Text(error).font(.geist(13)).foregroundStyle(Color.error).padding(.bottom, 8)
            }
            Button {
                crear()
            } label: {
                if creando { ProgressView().tint(Color.noche) } else { Label("Crear link de pago", systemImage: "link") }
            }
            .buttonStyle(.principal)
            .disabled(creando)
            Text("Lo pagan con cualquier billetera o banco. Te llega al instante, sin comisión.")
                .parrafo(12.5).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 10)
        }
    }

    private var ultimos: some View {
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Últimos links", accion: estado.panel.links.isEmpty ? nil : "Ver todos") {
                estado.ir(.links, en: .inicio)
            }
            if estado.panel.links.isEmpty {
                Text("Todavía no armaste links. El primero está a un toque.").font(.geist(14)).foregroundStyle(Color.sec).padding(.vertical, 8)
            }
            ForEach(Array(estado.panel.links.prefix(3).enumerated()), id: \.element.id) { i, l in
                if i > 0 { Separador() }
                FilaLink(link: l)
            }
        }
    }

    private func crear() {
        creando = true
        error = nil
        Task {
            do {
                let l = try await estado.crearLink(concepto: concepto, centavos: conMonto && monto > 0 ? monto : nil)
                Haptico.exito()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { creado = l }
            } catch {
                self.error = estado.mensaje(error)
                Haptico.error()
            }
            creando = false
        }
    }
}

private struct LinkCreado: View {
    let link: LinkDePago
    let otro: () -> Void
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(spacing: 0) {
            Icono3D(nombre: "ic-transferir", tamano: 72)
            Titulo("Tu link está listo.", tamano: 24, centrado: true).padding(.top, 8)
            Text(link.concepto + (link.centavos.map { " · " + Formato.plata($0) } ?? " · monto libre"))
                .font(.geist(14)).foregroundStyle(Color.sec).padding(.top, 6)
            Text(link.url)
                .font(.mono(13)).foregroundStyle(Color.texto)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 14).frame(height: 46).frame(maxWidth: .infinity)
                .caja(radio: 14)
                .padding(.top, 16)
            HStack(spacing: 10) {
                Button { copiar(link.url, aviso: "Copiaste el link", estado: estado) } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
                .buttonStyle(.cuarzo(.secundario, alto: 50))
                ShareLink(item: URL(string: link.url)!,
                          message: Text(mensajeCobro(monto: link.centavos ?? 0, concepto: link.concepto, link: link.url))) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.cuarzo(.principal, alto: 50))
            }
            .padding(.top, 12)
            Button("Armar otro link", action: otro).buttonStyle(.textoRosa).padding(.top, 4)
        }
        .padding(18)
        .vidrio()
    }
}

private struct FilaLink: View {
    let link: LinkDePago
    var body: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: "", tono: link.estado == .pagado ? .menta : .rosa, simbolo: "link", tamano: 40, cuadrado: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.concepto).font(.geist(15, .medio)).foregroundStyle(Color.texto).lineLimit(1)
                Text(link.pagadoPor.map { "Pagó " + $0 } ?? Fecha.encabezado(link.creado))
                    .font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(link.centavos.map { Formato.plata($0) } ?? "Libre").font(.geist(15, .medio)).monospacedDigit().foregroundStyle(Color.texto)
                Etiqueta(texto: nombre, tipo: link.estado == .pagado ? .ok : link.estado == .pendiente ? .rosa : .neutra)
            }
        }
        .frame(minHeight: 64)
        .accessibilityElement(children: .combine)
    }
    private var nombre: String {
        switch link.estado {
        case .pendiente: return "Pendiente"
        case .pagado: return "Pagado"
        case .vencido: return "Vencido"
        }
    }
}

// MARK: - Editar monto

private struct EditarCobro: View {
    @Binding var monto: Int
    @Binding var concepto: String
    @Environment(\.dismiss) private var dismiss
    @State private var entrada = EntradaMonto()
    @State private var texto = ""
    @FocusState private var foco: Bool
    private let sugeridos = ["Corte y color", "Seña", "Servicio", "Clase", "Producto"]

    var body: some View {
        VStack(spacing: 0) {
            Cabecera("¿Cuánto le cobrás?") {
                Redondo("xmark", "Cerrar") { dismiss() }
            }
            MontoTipeado(entrada: entrada, tamano: 52).padding(.top, 18).padding(.horizontal, 20)
            Text(entrada.vacio ? "Sin monto: lo pone quien paga" : "Le llega al bolsillo Negocio, sin comisión")
                .font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 8)
            TextField("", text: $texto, prompt: Text("Concepto (opcional)").foregroundStyle(Color.sec))
                .font(.geist(15)).foregroundStyle(Color.texto)
                .focused($foco)
                .submitLabel(.done)
                .padding(.horizontal, 14).frame(height: 46)
                .caja(radio: 14, seleccionada: foco)
                .padding(.horizontal, 20).padding(.top, 18)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sugeridos, id: \.self) { s in Chip(texto: s, on: texto == s) { texto = s } }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.top, 10)
            Spacer(minLength: 8)
            if !foco {
                TecladoNumerico(entrada: $entrada, alto: 50).padding(.horizontal, 12)
            }
            Button("Listo") {
                monto = entrada.centavos
                concepto = texto.trimmingCharacters(in: .whitespaces)
                Haptico.exito()
                dismiss()
            }
            .buttonStyle(.principal)
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
        }
        .onAppear {
            entrada = EntradaMonto(centavos: monto)
            texto = concepto
        }
    }
}

// MARK: - QR fijo

private struct QRFijoHoja: View {
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var imagenCartel: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            Cabecera("QR fijo del local") { Redondo("xmark", "Cerrar") { dismiss() } }
            ScrollView {
                VStack(spacing: 14) {
                    CartelQR(negocio: estado.usuario.negocio, link: linkDeCobro(alias: estado.usuario.alias, monto: 0, concepto: ""),
                             alias: estado.usuario.alias)
                    Text("Imprimilo y dejalo en el mostrador. Cada persona pone el monto y te llega al bolsillo Negocio.")
                        .parrafo(14).multilineTextAlignment(.center).padding(.horizontal, 12)
                }
                .padding(20)
            }
            Group {
                if let imagenCartel {
                    ShareLink(item: ImagenCompartible(imagen: imagenCartel, nombre: "QR " + estado.usuario.negocio),
                              preview: SharePreview("QR de " + estado.usuario.negocio, image: Image(uiImage: imagenCartel))) {
                        Label("Compartir o imprimir", systemImage: "printer")
                    }
                } else {
                    Button {} label: { ProgressView().tint(Color.noche) }.disabled(true)
                }
            }
            .buttonStyle(.principal)
            .padding(20)
        }
        .task {
            imagenCartel = imagen(de: CartelQR(negocio: estado.usuario.negocio,
                                               link: linkDeCobro(alias: estado.usuario.alias, monto: 0, concepto: ""),
                                               alias: estado.usuario.alias, animado: false), ancho: 360)
        }
    }
}

private struct CartelQR: View {
    let negocio: String
    let link: String
    let alias: String
    var animado = true

    var body: some View {
        VStack(spacing: 14) {
            Image("horizontal-claro").resizable().scaledToFit().frame(height: 24)
            Text("Pagá con QR, sin comisión").font(.geist(15, .medio)).foregroundStyle(Color.tintaSec)
            QRCuarzo(contenido: link, tamano: 230, animado: animado)
            Text(negocio).font(.geistFijo(22, .semi)).tracking(-0.8).foregroundStyle(Color.noche)
            Text(alias).font(.mono(13)).foregroundStyle(Color.rosaTinta)
            Text("Sirve con cualquier billetera o banco").font(.geist(12)).foregroundStyle(Color.tintaSec)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.nacar))
        .environment(\.colorScheme, .light)
    }
}

private struct AyudaCobrar: View {
    @Environment(\.dismiss) private var dismiss
    private let pasos: [(String, String, String)] = [
        ("qrcode", "Mostrá tu QR", "Lo escanean con cualquier billetera o la app del banco."),
        ("link", "O mandá un link", "Por WhatsApp o donde quieras. Pagan desde el celu."),
        ("bolt", "Te llega al instante", "Al bolsillo Negocio, sin comisión, con aviso al toque."),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Cabecera("Cómo cobrar") { Redondo("xmark", "Cerrar") { dismiss() } }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(pasos, id: \.0) { p in
                    FilaAjuste(simbolo: p.0, titulo: p.1, detalle: p.2, tono: .rosa) { EmptyView() }
                }
            }
            .padding(20)
            Spacer()
        }
    }
}
