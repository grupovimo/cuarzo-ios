import SwiftUI

/// Pagar con QR: cámara simulada (07) → monto si el QR no trae → carrito «Hoy pagás» (08) → Face ID → comprobante.
struct PagarFlujo: View {
    private enum Paso: Equatable {
        case escanear
        case monto(Comercio)
        case confirmar(Comercio, Centavos)
        case listo(String)
    }

    @Environment(Estado.self) private var estado
    @State private var paso: Paso = .escanear

    var body: some View {
        ZStack {
            switch paso {
            case .escanear:
                Escaner { comercio in
                    ir(comercio.monto.map { .confirmar(comercio, $0) } ?? .monto(comercio))
                }
                .transition(.opacity)
            case .monto(let c):
                MontoComercio(comercio: c, atras: { ir(.escanear) }) { ir(.confirmar(c, $0)) }
                    .transition(.move(edge: .trailing))
            case .confirmar(let c, let monto):
                ConfirmarPago(comercio: c, monto: monto, atras: {
                    ir(c.monto == nil ? .monto(c) : .escanear)
                }) { ir(.listo($0)) }
                .transition(.move(edge: .trailing))
            case .listo(let id):
                ComprobanteVista(movimientoID: id, celebrar: true)
                    .transition(.opacity)
            }
        }
        .background(Color.fondo.ignoresSafeArea())
        .onAppear {
            if Arranque.pantalla == "pagar" && Arranque.paso == 1 {
                paso = .confirmar(DatosDeMuestra.comercios[0], DatosDeMuestra.comercios[0].monto ?? 0)
            }
        }
    }

    private func ir(_ p: Paso) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { paso = p }
    }
}

// MARK: - Escáner (07)

private struct Escaner: View {
    let detectado: (Comercio) -> Void
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var encontrado: Comercio?
    @State private var linea = false
    @State private var linterna = false

    var body: some View {
        GeometryReader { g in
            let lado = min(258, g.size.width - 100)
            let centro = CGPoint(x: g.size.width / 2, y: g.size.height * 0.47)
            let mira = CGRect(x: centro.x - lado / 2, y: centro.y - lado / 2, width: lado, height: lado)
            ZStack(alignment: .top) {
                camara
                VeloMira(hueco: mira)
                    .fill(Color(UIColor(hex: 0x050307)).opacity(0.62), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                if linterna {
                    RadialGradient(colors: [.white.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 340)
                        .ignoresSafeArea().allowsHitTesting(false)
                }
                Esquinas()
                    .stroke(Color.rosa, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: lado + 8, height: lado + 8)
                    .position(centro)
                lineaEscaneo(lado: lado)
                    .position(x: centro.x, y: mira.minY + lado * (linea ? 0.82 : 0.18))
                VStack(spacing: 0) {
                    cabecera
                    VStack(spacing: 6) {
                        Text("Escaneá el QR").font(.geist(24, .semi)).tracking(-0.84)
                        Text("Sirve el de cualquier billetera.").font(.geist(14.5)).foregroundStyle(Color(UIColor(hex: 0xD9CDDC)))
                    }
                    .foregroundStyle(Color(UIColor(hex: 0xFBF5F9)))
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 1)
                    .padding(.top, 24)
                }
                if let encontrado {
                    chipDetectado(encontrado)
                        .position(x: centro.x, y: mira.maxY + 52)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { hoja }
        .environment(\.colorScheme, .dark)
        .task {
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) { linea = true }
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { encontrado = DatosDeMuestra.comercios[0] }
            Haptico.firme()
        }
    }

    private var camara: some View {
        Image("camara-qr-v")
            .resizable()
            .scaledToFill()
            .scaleEffect(1.18)
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.08).ignoresSafeArea())
            .accessibilityHidden(true)
    }

    private var cabecera: some View {
        HStack {
            Redondo("xmark", "Cerrar") { dismiss() }
            Spacer()
            Redondo(linterna ? "bolt.fill" : "bolt", linterna ? "Apagar linterna" : "Prender linterna") {
                withAnimation(.easeInOut(duration: 0.2)) { linterna.toggle() }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    private func lineaEscaneo(lado: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [.clear, .rosa, .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: lado - 32, height: 2)
            .shadow(color: .rosa.opacity(0.7), radius: 10)
            .opacity(encontrado == nil ? 1 : 0.35)
            .allowsHitTesting(false)
    }

    private func chipDetectado(_ c: Comercio) -> some View {
        Button { detectado(c) } label: {
            HStack(spacing: 10) {
                Avatar(iniciales: "", tono: .cobre, simbolo: c.simbolo, tamano: 40, cuadrado: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.nombre).font(.geist(14.5, .semi)).foregroundStyle(Color.texto)
                    Text("QR detectado · tocá para seguir").font(.geist(12.5)).foregroundStyle(Color.sec)
                }
            }
            .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.sup2.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
        }
        .buttonStyle(Presionable())
        .accessibilityLabel("QR de " + c.nombre + " detectado. Tocá para seguir.")
    }

    private var hoja: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button { detectado(DatosDeMuestra.comercios[1]) } label: { Label("Desde fotos", systemImage: "photo") }
                    .buttonStyle(.cuarzo(.secundario, alto: 50))
                Button { estado.abrir(.cobrar(.qr)) } label: { Label("Mi QR", systemImage: "qrcode") }
                    .buttonStyle(.cuarzo(.secundario, alto: 50))
            }
            Text("Pagás con la plata de tu cuenta, al instante.").font(.geist(13)).foregroundStyle(Color.sec)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color.noche.opacity(0.92))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.rosa.opacity(0.25), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// Velo oscuro con el hueco de la mira.
private struct VeloMira: Shape {
    var hueco: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(r.insetBy(dx: -200, dy: -300))
        p.addRoundedRect(in: hueco, cornerSize: CGSize(width: 30, height: 30), style: .continuous)
        return p
    }
}

/// Las cuatro esquinas rosa de la mira.
private struct Esquinas: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 44, rad: CGFloat = 30
        // arriba izquierda
        p.move(to: CGPoint(x: r.minX, y: r.minY + l))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + rad, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        // arriba derecha
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rad, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + rad), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        // abajo derecha
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        // abajo izquierda
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

// MARK: - Monto (QR sin monto)

private struct MontoComercio: View {
    let comercio: Comercio
    let atras: () -> Void
    let seguir: (Centavos) -> Void
    @State private var entrada = EntradaMonto()

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.3))
            VStack(spacing: 0) {
                CabeceraCerrar("Pagar", atras: atras)
                CabeceraComercio(comercio: comercio).padding(.top, 6)
                Text("Este QR no trae monto. ¿Cuánto pagás?").font(.geist(14)).foregroundStyle(Color.sec).padding(.top, 18)
                MontoTipeado(entrada: entrada, tamano: 52).padding(.top, 10).padding(.horizontal, 20)
                Spacer(minLength: 8)
                TecladoNumerico(entrada: $entrada).padding(.horizontal, 12)
                Button("Seguir") { seguir(entrada.centavos) }
                    .buttonStyle(.principal)
                    .disabled(entrada.vacio)
                    .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
            }
        }
    }
}

private struct CabeceraComercio: View {
    let comercio: Comercio
    var body: some View {
        VStack(spacing: 0) {
            Avatar(iniciales: "", tono: .cobre, simbolo: comercio.simbolo, tamano: 60, cuadrado: true)
            HStack(spacing: 6) {
                Text(comercio.nombre).font(.geist(18, .semi)).tracking(-0.36).foregroundStyle(Color.texto)
                if comercio.verificado {
                    Image(systemName: "checkmark.shield").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.acento)
                        .accessibilityLabel("Comercio verificado")
                }
            }
            .padding(.top, 10)
            Text(comercio.direccion).font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Confirmar (08)

private struct ConfirmarPago: View {
    let comercio: Comercio
    let monto: Centavos
    let atras: () -> Void
    let pagado: (String) -> Void
    @Environment(Estado.self) private var estado
    @State private var desde: Bolsillo = .personal
    @State private var pagando = false
    @State private var error: String?
    @State private var pasar = false

    private var alcanza: Bool { estado.saldo(desde) >= monto }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraCerrar("Pagar", atras: atras)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        CabeceraComercio(comercio: comercio).padding(.top, 6)
                        Text("Pagás desde").rotulo().padding(.top, 22)
                        HStack(spacing: 10) {
                            opcion(.personal)
                            opcion(.negocio)
                        }
                        .padding(.top, 8)
                        if !alcanza { sinSaldo.padding(.top, 12) }
                        ticket.padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                pie
            }
        }
        .onAppear {
            if estado.saldo(.personal) < monto && estado.saldo(.negocio) >= monto { desde = .negocio }
        }
        .sheet(isPresented: $pasar) {
            PasarPantalla(desde: desde.otro, sugerido: monto - estado.saldo(desde))
                .presentationDetents([.large])
                .presentationBackground(Color.fondo)
        }
    }

    private func opcion(_ b: Bolsillo) -> some View {
        let on = desde == b
        return Button {
            Haptico.seleccion()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { desde = b; error = nil }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: b.simbolo).font(.system(size: 14)).foregroundStyle(on ? Color.acento : Color.sec)
                    Text(b.nombre).font(.geist(14, .medio)).foregroundStyle(Color.texto)
                }
                Text(Formato.plata(estado.saldo(b), centavos: true)).font(.geist(13)).monospacedDigit().foregroundStyle(Color.sec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(alignment: .topTrailing) { RadioPlata(on: on).padding(12) }
            .caja(radio: 16, seleccionada: on)
        }
        .buttonStyle(Presionable(escala: 0.97))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var sinSaldo: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 16))
            Text("No te alcanza en " + desde.nombre + ".").font(.geist(14, .medio))
            Spacer()
            Button("Pasar plata") { pasar = true }.font(.geist(14, .semi)).buttonStyle(.plain)
        }
        .foregroundStyle(Color.alerta)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.alertaSuave))
        .transition(.opacity)
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 8)
            Group {
                RenglonTicket(etiqueta: "Compra", valor: Formato.plata(monto, centavos: true))
                RenglonTicket(etiqueta: "Comisión", valor: Formato.plata(0))
                RenglonTicket(etiqueta: "Medio", valor: "Dinero en cuenta")
                RenglonTicket(etiqueta: "CUIT del comercio", valor: comercio.cuit)
            }
            .padding(.horizontal, 18)
            CorteTicket().padding(.vertical, 4)
            HStack(alignment: .lastTextBaseline) {
                Text("Hoy pagás").rotulo(.acento)
                Spacer()
                Monto(centavos: monto, tamano: 38)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
        .caja()
    }

    private var pie: some View {
        VStack(spacing: 10) {
            if let error {
                Text(error).font(.geist(13, .medio)).foregroundStyle(Color.error).multilineTextAlignment(.center)
            }
            Button { pagar() } label: {
                if pagando {
                    HStack(spacing: 8) { ProgressView().tint(Color.noche); Text("Pagando…") }
                } else {
                    Label("Pagar " + Formato.plata(monto), systemImage: "faceid")
                }
            }
            .buttonStyle(.principal)
            .disabled(pagando || !alcanza)
            Text("Te pedimos Face ID. El comercio lo recibe al instante.").font(.geist(12)).foregroundStyle(Color.sec)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func pagar() {
        error = nil
        Task {
            guard await estado.pedirFaceID("Para pagar " + Formato.plata(monto)) else { return }
            pagando = true
            do {
                let m = try await estado.pagar(comercio, centavos: monto, desde: desde)
                pagado(m.id)
            } catch ErrorCuarzo.frenada(let f) {
                estado.abrir(.frenada(f))
            } catch {
                self.error = estado.mensaje(error)
                Haptico.error()
            }
            pagando = false
        }
    }
}

/// Radio del selector de bolsillo.
struct RadioPlata: View {
    let on: Bool
    var body: some View {
        ZStack {
            if on {
                Circle().fill(Color.rosa)
                Circle().fill(Color.noche).frame(width: 8, height: 8)
            } else {
                Circle().strokeBorder(Color.linea2, lineWidth: 1.5)
            }
        }
        .frame(width: 20, height: 20)
        .animation(.spring(response: 0.3), value: on)
        .accessibilityHidden(true)
    }
}
