import SwiftUI

/// Seguridad: Face ID, código, espera para cuentas nuevas, dispositivos, límites y bloqueo de emergencia.
struct SeguridadPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var bloquear = false
    @State private var bloqueada = false

    var body: some View {
        @Bindable var e = estado
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Seguridad")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 14) {
                            Icono3D(nombre: "ic-escudo", tamano: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Titulo("Tu plata, cuidada.", tamano: 22)
                                Text("Todo lo que mueve plata te pide Face ID.").font(.geist(14)).foregroundStyle(Color.sec)
                            }
                        }
                        .padding(.top, 8)
                        Text("Entrar y pagar").rotulo().padding(.top, 22).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            FilaAjuste(simbolo: "faceid", titulo: "Face ID para entrar y pagar", tono: .rosa) {
                                Interruptor(on: $e.faceIDActivo, etiqueta: "Face ID")
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "circle.grid.3x3", titulo: "Cambiar código", detalle: "6 dígitos, para cuando no hay Face ID") {
                                Task {
                                    if await estado.pedirFaceID("Para cambiar tu código") {
                                        estado.avisar("Te mandamos un SMS para elegir el código nuevo.", tipo: .info)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16).caja()
                        Text("Transferencias").rotulo().padding(.top, 22).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            FilaAjuste(simbolo: "clock", titulo: "Espera para cuentas nuevas",
                                       detalle: "A cuentas que nunca usaste: 24 h y hasta $\u{00A0}100.000 por vez.", tono: .rosa) {
                                Interruptor(on: $e.esperaCuentasNuevas, etiqueta: "Espera para cuentas nuevas")
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "lock", titulo: "Límites de transferencia", detalle: "Por día y por mes") {
                                estado.ir(.limitesTransferencia)
                            }
                            Separador(sangria: 48)
                            NavegaFila(simbolo: "iphone", titulo: "Dispositivos", detalle: "\(estado.panel.dispositivos.count) con tu cuenta abierta") {
                                estado.ir(.dispositivos)
                            }
                        }
                        .padding(.horizontal, 16).caja()
                        Text("Si te roban el teléfono").rotulo().padding(.top, 22).padding(.bottom, 8)
                        Button {
                            bloquear = true
                        } label: {
                            Label(bloqueada ? "Cuenta bloqueada" : "Bloquear la cuenta ya", systemImage: bloqueada ? "lock.fill" : "hand.raised")
                        }
                        .buttonStyle(.cuarzo(.peligro, alto: 50))
                        .disabled(bloqueada)
                        Text("Frena todo al instante: pagos, transferencias y tarjetas. Para volver, hablás con una persona.")
                            .font(.geist(13)).foregroundStyle(Color.sec).padding(.top, 10)
                            .fixedSize(horizontal: false, vertical: true)
                        PersonaCerca().padding(.top, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .confirmationDialog("¿Bloquear la cuenta?", isPresented: $bloquear, titleVisibility: .visible) {
            Button("Bloquear todo", role: .destructive) {
                Haptico.aviso()
                withAnimation { bloqueada = true }
                estado.avisar("Bloqueamos la cuenta. Tu plata está a salvo.", tipo: .info)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se va a poder mover plata hasta que hables con el equipo.")
        }
    }
}

// MARK: - Límites

struct LimitesTransferenciaPantalla: View {
    @Environment(Estado.self) private var estado
    @AppStorage("limiteDia") private var limiteDia = 100_000_000
    @AppStorage("limiteMes") private var limiteMes = 500_000_000
    @State private var editando: Int?
    @State private var borrador: Double = 0

    private let topeDia: Centavos = 500_000_000
    private let topeMes: Centavos = 2_000_000_000

    /// Lo que salió hoy y este mes en transferencias.
    private func usado(mes: Bool) -> Centavos {
        let cal = Fecha.calendario
        return estado.panel.movimientos
            .filter { $0.tipo == .transferenciaEnviada }
            .filter { mes ? cal.isDate($0.fecha, equalTo: .now, toGranularity: .month) : cal.isDateInToday($0.fecha) }
            .reduce(0) { $0 + abs($1.centavos) }
    }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Límites")
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Titulo("Cuánto podés transferir.", tamano: 24).padding(.top, 8)
                        Text("Bajarlo es al instante. Subirlo tarda 24 h, por si no fuiste vos.").parrafo(15)
                        tarjeta(titulo: "Por día", usado: usado(mes: false), limite: limiteDia, tope: topeDia, indice: 0)
                        tarjeta(titulo: "Por mes", usado: usado(mes: true), limite: limiteMes, tope: topeMes, indice: 1)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Color.acento)
                            Text("Pagar con QR y la tarjeta tienen sus propios límites, en la pestaña Tarjeta.")
                                .font(.geist(13)).foregroundStyle(Color.sec).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func tarjeta(titulo: String, usado: Centavos, limite: Int, tope: Centavos, indice: Int) -> some View {
        let abierta = editando == indice
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.geist(15, .semi)).foregroundStyle(Color.texto)
                Spacer()
                Text(Formato.plata(usado) + " de " + Formato.plata(limite))
                    .font(.geist(13)).monospacedDigit().foregroundStyle(Color.sec)
            }
            BarraProgreso(valor: Double(usado) / Double(max(limite, 1)))
            Text("Te quedan " + Formato.plata(max(0, limite - usado)))
                .font(.geist(13)).foregroundStyle(Color.sec)
            if abierta {
                VStack(alignment: .leading, spacing: 10) {
                    MontoChico(centavos: Int(borrador), tamano: 24, conCentavos: false)
                    Slider(value: $borrador, in: Double(tope / 20)...Double(tope), step: Double(tope / 40))
                        .tint(.rosa)
                        .onChange(of: borrador) { _, _ in Haptico.seleccion() }
                        .accessibilityLabel("Límite " + titulo.lowercased())
                    HStack(spacing: 10) {
                        Button("Cancelar") { withAnimation { editando = nil } }
                            .buttonStyle(.cuarzo(.secundario, alto: 46))
                        Button("Guardar") { guardar(indice) }
                            .buttonStyle(.cuarzo(.principal, alto: 46))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button("Cambiar límite") {
                    Haptico.tocar()
                    borrador = Double(limite)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { editando = indice }
                }
                .font(.geist(14, .semi)).foregroundStyle(Color.acento).buttonStyle(.plain)
                .frame(minHeight: 32)
            }
        }
        .padding(16)
        .caja()
    }

    private func guardar(_ indice: Int) {
        let nuevo = Int(borrador)
        let antes = indice == 0 ? limiteDia : limiteMes
        Task {
            guard await estado.pedirFaceID("Para cambiar tu límite") else { return }
            withAnimation {
                if indice == 0 { limiteDia = nuevo } else { limiteMes = nuevo }
                editando = nil
            }
            estado.avisar(nuevo > antes ? "Listo. El aumento se activa en 24 h." : "Listo, ya rige el límite nuevo.")
        }
    }
}

// MARK: - Dispositivos

struct DispositivosPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var cerrar: Dispositivo?

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Dispositivos")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Titulo("Dónde está abierta tu cuenta.", tamano: 24).padding(.top, 8)
                        Text("Si no reconocés alguno, cerrale la sesión.").parrafo(15).padding(.top, 8)
                        VStack(spacing: 0) {
                            ForEach(Array(estado.panel.dispositivos.enumerated()), id: \.element.id) { i, d in
                                if i > 0 { Separador(sangria: 48) }
                                fila(d)
                            }
                        }
                        .padding(.horizontal, 16)
                        .caja()
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .confirmationDialog("¿Cerrar la sesión en \(cerrar?.nombre ?? "")?", isPresented: Binding(get: { cerrar != nil }, set: { if !$0 { cerrar = nil } }),
                            titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                if let d = cerrar {
                    withAnimation { estado.panel.dispositivos.removeAll { $0.id == d.id } }
                    estado.avisar("Cerramos la sesión en " + d.nombre + ".")
                }
                cerrar = nil
            }
            Button("Cancelar", role: .cancel) { cerrar = nil }
        }
    }

    private func fila(_ d: Dispositivo) -> some View {
        FilaAjuste(simbolo: d.nombre.lowercased().contains("ipad") ? "ipad" : "iphone", titulo: d.nombre, detalle: d.detalle, tono: d.esEste ? .rosa : .neutro) {
            if d.esEste {
                Etiqueta(texto: "Este", tipo: .ok)
            } else {
                Button("Cerrar") { Haptico.tocar(); cerrar = d }
                    .font(.geist(14, .semi)).foregroundStyle(Color.error).buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Cerrar la sesión en " + d.nombre)
            }
        }
    }
}
