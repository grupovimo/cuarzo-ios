import SwiftUI

/// Comprobante de una operación (pantalla 10). Con `celebrar`, entra con la animación del cristal.
struct ComprobanteVista: View {
    let movimientoID: String
    var celebrar = false
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var imagenLista: UIImage?
    @State private var pdfListo: URL?
    @State private var aparecer = false

    private var m: Movimiento? { estado.movimiento(movimientoID) }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.12), tamanoBrillo: 380)
            VStack(spacing: 0) {
                Cabecera("") {
                    Color.clear.frame(width: 44, height: 44)
                } derecha: {
                    Redondo("xmark", "Cerrar") { cerrar() }
                }
                if let m {
                    contenido(m)
                } else {
                    Spacer()
                    ErrorVista(titulo: "No encontramos este comprobante.",
                               texto: "Puede que todavía se esté procesando. Tu plata está a salvo.") { cerrar() }
                    Spacer()
                }
            }
        }
        .task(id: movimientoID) { await prepararArchivos() }
    }

    private func cerrar() {
        dismiss()
        estado.cerrarModales()
    }

    @ViewBuilder
    private func contenido(_ m: Movimiento) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                encabezado(m)
                PapelComprobante(m: m, usuario: estado.usuario)
                    .padding(.top, 20)
                    .offset(y: aparecer ? 0 : 40)
                    .opacity(aparecer ? 1 : 0)
                Button {
                    estado.abrir(.chat)
                } label: {
                    Label("¿Algo no cierra? Te contesta una persona.", systemImage: "bubble.left")
                        .font(.geist(14, .medio))
                        .foregroundStyle(Color.acento)
                }
                .buttonStyle(.plain)
                .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { pie(m) }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(celebrar ? 0.9 : 0.05)) { aparecer = true }
        }
    }

    private func encabezado(_ m: Movimiento) -> some View {
        VStack(spacing: 0) {
            CristalExito(tamano: 68, animar: celebrar)
                .frame(height: 96)
            Titulo(ComprobanteVista.titulo(m), tamano: 26, centrado: true)
                .padding(.top, 10)
            Monto(centavos: abs(m.centavos), tamano: 40)
                .padding(.top, 8)
            if m.estado != .listo {
                Etiqueta(texto: m.estado.nombre, simbolo: "clock", tipo: .alerta).padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pie(_ m: Movimiento) -> some View {
        HStack(spacing: 10) {
            if let pdfListo {
                ShareLink(item: pdfListo) {
                    Label("PDF", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.cuarzo(.secundario, alto: 50))
            } else {
                Button {} label: { Label("PDF", systemImage: "arrow.down.to.line") }
                    .buttonStyle(.cuarzo(.secundario, alto: 50)).disabled(true)
            }
            if let imagenLista {
                ShareLink(item: ImagenCompartible(imagen: imagenLista, nombre: "Comprobante " + m.id),
                          preview: SharePreview("Comprobante de Cuarzo", image: Image(uiImage: imagenLista))) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.cuarzo(.principal, alto: 50))
            } else {
                Button {} label: { Label("Compartir", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.cuarzo(.principal, alto: 50)).disabled(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.fondo.opacity(0.92).ignoresSafeArea())
    }

    private func prepararArchivos() async {
        guard let m else { return }
        let hoja = ComprobanteCompartible(m: m, usuario: estado.usuario, titulo: ComprobanteVista.titulo(m))
        imagenLista = imagen(de: hoja, ancho: 390)
        pdfListo = pdf(de: hoja, nombre: "Comprobante " + m.id)
    }

    /// «Le llegó a Martina.», «Pagaste en Panadería La Espiga.», «Te entró plata.»
    static func titulo(_ m: Movimiento) -> String {
        let primero = m.titulo.split(separator: " ").first.map(String.init) ?? m.titulo
        switch m.tipo {
        case .transferenciaEnviada: return "Le llegó a " + primero + "."
        case .pagoQR, .compraTarjeta: return "Pagaste en " + m.titulo + "."
        case .pase: return "Pasaste plata a " + m.bolsillo.nombre + "."
        case .apartado: return m.centavos <= 0 ? "Guardado en " + m.titulo + "." : "Volvió a " + m.bolsillo.nombre + "."
        case .cobroTarjeta: return "Cobraste con tarjeta."
        case .rendimiento: return "Tu plata rindió."
        case .ingreso: return "Ingresó tu plata."
        case .cobroQR, .cobroLink, .transferenciaRecibida: return "Te pagó " + primero + "."
        }
    }
}

/// El papel nácar del comprobante, con el borde dentado. Lo usan el comprobante y el detalle del movimiento.
struct PapelComprobante: View {
    let m: Movimiento
    let usuario: Usuario

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("horizontal-claro").resizable().scaledToFit().frame(height: 18)
                    .accessibilityLabel("Cuarzo")
                Spacer()
                Text("Comprobante").font(.mono(10.5)).tracking(1.26).textCase(.uppercase).foregroundStyle(Color.rosaTinta)
            }
            .padding(.bottom, 10)
            ForEach(Array(renglones.enumerated()), id: \.offset) { _, r in
                Rectangle().fill(Color.lineaPapel).frame(height: 1)
                RenglonTicket(etiqueta: r.0, valor: r.1, sub: r.2, mono: r.3, papel: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(PapelDentado().fill(Color.nacar).shadow(color: .black.opacity(0.10), radius: 14, y: 6))
        .padding(.bottom, 7)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Comprobante")
    }

    /// (etiqueta, valor, debajo, mono)
    private var renglones: [(String, String, String?, Bool)] {
        let yo = usuario.nombreCompleto + " · " + m.bolsillo.nombre
        var r: [(String, String, String?, Bool)] = []
        switch m.tipo {
        case .transferenciaEnviada:
            r.append(("Para", m.titulo, m.contraparteCuenta.map { "CVU " + $0 }, false))
            r.append(("Desde", yo, "CUIT " + usuario.cuit, false))
        case .pagoQR, .compraTarjeta:
            r.append(("Comercio", m.titulo, m.contraparteCuit.map { "CUIT " + $0 }, false))
            r.append(("Desde", yo, m.tipo == .compraTarjeta ? "Tarjeta virtual" : "Dinero en cuenta", false))
        case .cobroQR, .cobroLink, .transferenciaRecibida, .cobroTarjeta, .ingreso:
            r.append(("De", m.titulo, m.contraparteCuit.map { "CUIT " + $0 } ?? m.contraparteCuenta.map { "CVU " + $0 }, false))
            r.append(("Para", yo, "CVU " + usuario.cvu, false))
        case .pase, .apartado, .rendimiento:
            r.append(("Cuenta", yo, "CVU " + usuario.cvu, false))
        }
        if let motivo = m.motivo, !motivo.isEmpty {
            r.append(("Motivo", motivo, nil, false))
        } else if !m.detalle.isEmpty {
            r.append(("Concepto", m.detalle, nil, false))
        }
        r.append(("Fecha", Fecha.comprobante(m.fecha), nil, false))
        r.append(("Operación", m.id, nil, true))
        r.append(("Comisión", Formato.plata(m.comision), nil, false))
        return r
    }
}

/// Lo que se comparte (imagen o PDF): el monto arriba y el papel, sobre nácar.
private struct ComprobanteCompartible: View {
    let m: Movimiento
    let usuario: Usuario
    let titulo: String

    var body: some View {
        VStack(spacing: 10) {
            Text(titulo).font(.geistFijo(22, .semi)).tracking(-0.8).foregroundStyle(Color.noche)
                .multilineTextAlignment(.center)
            Monto(centavos: abs(m.centavos), tamano: 36, color: .noche)
            PapelComprobante(m: m, usuario: usuario).padding(.top, 8)
            Text("Cuenta provista por [PSP socio]").font(.geist(11)).foregroundStyle(Color.tintaSec)
        }
        .padding(24)
        .background(Color(UIColor(hex: 0xF1E8EE)))
        .environment(\.colorScheme, .light)
    }
}
