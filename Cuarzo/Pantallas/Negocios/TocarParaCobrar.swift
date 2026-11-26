import SwiftUI

/// Tocar para cobrar: monto → acercá la tarjeta (ondas NFC) → procesando → aprobado → comprobante.
struct TocarParaCobrarFlujo: View {
    enum Paso: Int { case monto, acercar, procesando, aprobado, error }

    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso
    @State private var entrada: EntradaMonto
    @State private var concepto = ""
    @State private var movimiento: Movimiento?
    @State private var mensajeError = ""
    @State private var lectura: Task<Void, Never>?

    init(paso: Int = 0) {
        _paso = State(initialValue: Paso(rawValue: paso) ?? .monto)
        _entrada = State(initialValue: paso > 0 ? EntradaMonto(centavos: 1_850_000) : EntradaMonto())
    }

    private var comision: Centavos { entrada.centavos * 15 / 1000 }
    private var neto: Centavos { entrada.centavos - comision }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: paso == .monto ? 0.2 : 0.45), tamanoBrillo: 480)
            Group {
                switch paso {
                case .monto: pasoMonto
                case .acercar: pasoAcercar
                case .procesando: pasoProcesando
                case .aprobado: pasoAprobado
                case .error: pasoError
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .onDisappear { lectura?.cancel() }
    }

    private func ir(_ p: Paso) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { paso = p }
    }

    // MARK: Monto

    private var pasoMonto: some View {
        VStack(spacing: 0) {
            CabeceraCerrar("Tocar para cobrar")
            HStack(spacing: 8) {
                Etiqueta(texto: "Al bolsillo Negocio", simbolo: "briefcase")
                Etiqueta(texto: "Débito o crédito", tipo: .neutra)
            }
            .padding(.top, 6)
            MontoTipeado(entrada: entrada, tamano: 52).padding(.top, 20).padding(.horizontal, 20)
            TextField("Concepto (opcional)", text: $concepto)
                .font(.geist(15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.texto)
                .padding(.horizontal, 14).frame(height: 40)
                .background(Capsule().fill(Color.sup))
                .overlay(Capsule().strokeBorder(Color.linea, lineWidth: 1))
                .frame(maxWidth: 240)
                .padding(.top, 12)
            if !entrada.vacio {
                ticket.padding(.horizontal, 20).padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 6)
            TecladoNumerico(entrada: $entrada, alto: 48).padding(.horizontal, 12)
            Button("Cobrar " + Formato.plata(entrada.centavos)) { empezar() }
                .buttonStyle(.principal)
                .disabled(entrada.centavos < 10_000)
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: entrada.vacio)
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            RenglonTicket(etiqueta: "Comisión 1,5\u{00A0}% (muestra)", valor: "−\u{00A0}" + Formato.plata(comision))
            Separador()
            HStack {
                Text("Te entra").rotulo(.acento)
                Spacer()
                MontoChico(centavos: neto, tamano: 20)
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 16)
        .caja(radio: 16)
    }

    private func empezar() {
        Haptico.firme()
        ir(.acercar)
        lectura?.cancel()
        lectura = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            if Task.isCancelled || paso != .acercar { return }
            await leer()
        }
    }

    // MARK: Acercá la tarjeta

    private var pasoAcercar: some View {
        VStack(spacing: 0) {
            CabeceraCerrar("Tocar para cobrar", atras: {
                lectura?.cancel()
                ir(.monto)
            })
            Spacer()
            CelularNFC(monto: entrada.centavos)
            Titulo("Acercá la tarjeta.", tamano: 28, centrado: true).padding(.top, 26)
            Text("Que la apoyen arriba del celular. También anda con el celular o el reloj del cliente.")
                .parrafo(14).multilineTextAlignment(.center).padding(.horizontal, 36).padding(.top, 8)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 11))
                Text("Nunca ves ni guardamos los datos de la tarjeta.").font(.geist(12))
            }
            .foregroundStyle(Color.sec)
            .padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await leer() } }
        .accessibilityAction(named: "Simular tarjeta") { Task { await leer() } }
    }

    private func leer() async {
        guard paso == .acercar else { return }
        lectura?.cancel()
        Haptico.exito()
        ir(.procesando)
        do {
            let m = try await estado.cobrarConTarjeta(entrada.centavos, concepto: concepto.trimmingCharacters(in: .whitespaces))
            movimiento = m
            ir(.aprobado)
        } catch {
            Haptico.error()
            mensajeError = estado.mensaje(error)
            ir(.error)
        }
    }

    // MARK: Procesando

    private var pasoProcesando: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().controlSize(.large).tint(.acento)
            Text("Leímos la Visa débito ·· 4417").font(.geist(17, .semi)).foregroundStyle(Color.texto)
            Text("Confirmando con la red…").font(.geist(14)).foregroundStyle(Color.sec)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Aprobado

    private var pasoAprobado: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Redondo("xmark", "Cerrar") { dismiss() } }.padding(.horizontal, 14).frame(height: 52)
            CristalExito(tamano: 70)
            Titulo("Cobraste " + Formato.plata(entrada.centavos) + ".", tamano: 28, centrado: true).padding(.horizontal, 24)
            Text("Te entran " + Formato.plata(neto) + " hoy a las 18 h, al bolsillo Negocio.")
                .parrafo(15).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 8)
            VStack(spacing: 0) {
                RenglonTicket(etiqueta: "Tarjeta", valor: "Visa débito ·· 4417")
                RenglonTicket(etiqueta: "Concepto", valor: concepto.isEmpty ? "Cobro con tarjeta" : concepto)
                RenglonTicket(etiqueta: "Comisión", valor: "−\u{00A0}" + Formato.plata(comision))
                RenglonTicket(etiqueta: "Operación", valor: movimiento?.id ?? "—", mono: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .caja()
            .padding(.horizontal, 20).padding(.top, 20)
            Spacer()
            HStack(spacing: 10) {
                Button("Cobrar otro") {
                    entrada = EntradaMonto(); concepto = ""; movimiento = nil
                    ir(.monto)
                }
                .buttonStyle(.secundario)
                Button("Comprobante") {
                    if let m = movimiento { estado.abrir(.comprobante(m.id, celebrar: false)) }
                }
                .buttonStyle(.principal)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    private var pasoError: some View {
        VStack(spacing: 0) {
            CabeceraCerrar("Tocar para cobrar")
            Spacer()
            ErrorVista(titulo: "No pudimos cobrar.", texto: mensajeError + " No se le cobró nada al cliente.") { ir(.acercar); empezar() }
            Spacer()
        }
    }
}

/// El celular con el monto y las ondas NFC; una tarjeta se acerca de a poco.
private struct CelularNFC: View {
    let monto: Centavos
    @State private var ondas = false
    @State private var tarjeta = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.acento.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ondas ? 2.1 : 0.9)
                    .opacity(ondas ? 0 : 0.8)
                    .animation(.easeOut(duration: 2.1).repeatForever(autoreverses: false).delay(Double(i) * 0.7), value: ondas)
            }
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.sup)
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1.5))
                .frame(width: 128, height: 230)
                .overlay {
                    VStack(spacing: 10) {
                        Capsule().fill(Color.black).frame(width: 40, height: 12).padding(.top, 10)
                        Spacer()
                        Image(systemName: "wave.3.right").font(.system(size: 30, weight: .medium)).foregroundStyle(Color.acento)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text(Formato.plata(monto)).font(.geistFijo(17, .semi)).monospacedDigit().foregroundStyle(Color.texto)
                            .lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 8)
                        Spacer()
                        Image("simbolo-noche").resizable().scaledToFit().frame(width: 18).padding(.bottom, 14)
                    }
                }
                .shadow(color: .rosa.opacity(0.25), radius: 30)
            Image("tarjeta-rosa-frente")
                .resizable().aspectRatio(proporcionTarjeta, contentMode: .fit)
                .frame(width: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
                .rotationEffect(.degrees(-18))
                .offset(x: tarjeta ? 40 : 140, y: tarjeta ? -70 : -150)
                .opacity(tarjeta ? 0.95 : 0)
        }
        .frame(height: 300)
        .onAppear {
            ondas = true
            withAnimation(.easeInOut(duration: 1.6).delay(0.4)) { tarjeta = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Esperando la tarjeta del cliente")
    }
}
