import SwiftUI

private struct Pregunta: Identifiable {
    let id: Int
    let tema: String
    let pregunta: String
    let respuesta: String
}

private let preguntas: [Pregunta] = [
    Pregunta(id: 1, tema: "Cobrar", pregunta: "¿Cuánto cuesta cobrar con QR o link?",
             respuesta: "Entre cuentas Cuarzo, nada: ni hoy ni después. Si te paga alguien con otra billetera, también es $ 0. Con tarjeta (tocar para cobrar) se descuenta 1,5 %, y lo ves antes de cobrar."),
    Pregunta(id: 2, tema: "Cobrar", pregunta: "¿Cuándo tengo la plata?",
             respuesta: "Los cobros con QR, link y transferencia entran al instante al bolsillo Negocio. Los de tarjeta se liquidan el mismo día a las 18."),
    Pregunta(id: 3, tema: "Transferir", pregunta: "¿Por qué frenaron mi transferencia?",
             respuesta: "Pasa cuando algo no cierra: un monto fuera de lo habitual o un dato que falta. Te decimos por qué, qué falta y hasta cuándo. Tu plata no se mueve de tu cuenta."),
    Pregunta(id: 4, tema: "Transferir", pregunta: "¿A qué cuentas puedo transferir?",
             respuesta: "A cualquier CBU o CVU del país, con el número o el alias. Llega al instante y no tiene costo."),
    Pregunta(id: 5, tema: "Bolsillos", pregunta: "¿Para qué son los dos bolsillos?",
             respuesta: "Negocio recibe lo que cobrás; Personal es lo tuyo. Pasar plata de uno al otro es gratis y al instante, así sabés cuánto ganó el negocio y cuánto te pagaste."),
    Pregunta(id: 6, tema: "Apartados", pregunta: "¿Mis apartados rinden?",
             respuesta: "Sí: lo que tenés apartado rinde todos los días en un fondo del proveedor de la cuenta. El rendimiento no está garantizado y lo ves en el inicio."),
    Pregunta(id: 7, tema: "Tarjeta", pregunta: "¿Cuánto cuesta la tarjeta física?",
             respuesta: "Pedirla y usarla es gratis. Llega en unos 5 días hábiles a la dirección que elijas."),
    Pregunta(id: 8, tema: "Seguridad", pregunta: "Me robaron el teléfono, ¿qué hago?",
             respuesta: "Desde otro teléfono, escribinos o entrá a cuarzo.ar/bloquear. Si tenés la app a mano: Perfil › Seguridad › Bloquear la cuenta ya."),
    Pregunta(id: 9, tema: "La cuenta", pregunta: "¿Cuarzo es un banco?",
             respuesta: "No. Es una cuenta de pago que provee [PSP socio], inscripto en el BCRA. Tu plata está a tu nombre y la podés sacar cuando quieras."),
]

/// Ayuda: preguntas frecuentes que se buscan y se despliegan, y una persona a mano.
struct AyudaPantalla: View {
    @Environment(Estado.self) private var estado
    @State private var buscar = ""
    @State private var abierta: Int?

    private var filtradas: [Pregunta] {
        let q = buscar.paraBuscar.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return preguntas }
        return preguntas.filter { ($0.pregunta + " " + $0.respuesta + " " + $0.tema).paraBuscar.contains(q) }
    }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.8, y: 0.05), tamanoBrillo: 340)
            VStack(spacing: 0) {
                CabeceraAtras("Ayuda")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Titulo("¿En qué te damos una mano?", tamano: 24).padding(.top, 8)
                        campoBuscar.padding(.top, 16)
                        PersonaCerca().padding(.top, 12)
                        Text(buscar.isEmpty ? "Lo que más nos preguntan" : "Resultados").rotulo().padding(.top, 22).padding(.bottom, 8)
                        if filtradas.isEmpty {
                            Vacio(icono: "ic-escudo", titulo: "No encontramos eso.", texto: "Preguntale a una persona: contesta en unos minutos.",
                                  accion: "Hablar con una persona") { estado.abrir(.chat) }
                                .caja()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filtradas.enumerated()), id: \.element.id) { i, p in
                                    if i > 0 { Separador() }
                                    fila(p)
                                }
                            }
                            .padding(.horizontal, 16)
                            .caja()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var campoBuscar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.sec)
            TextField("Buscá: frenada, QR, tarjeta…", text: $buscar)
                .font(.geist(15))
                .submitLabel(.search)
            if !buscar.isEmpty {
                Button { buscar = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ter) }
                    .buttonStyle(.plain).accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .caja(radio: 14)
    }

    private func fila(_ p: Pregunta) -> some View {
        let on = abierta == p.id
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptico.seleccion()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { abierta = on ? nil : p.id }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.tema).rotulo(.acento, tamano: 10)
                        Text(p.pregunta).font(.geist(15, .medio)).foregroundStyle(Color.texto).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ter)
                        .rotationEffect(.degrees(on ? 180 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(on ? "Ocultar respuesta" : "Ver respuesta")
            if on {
                Text(p.respuesta).parrafo(14).padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }
}

// MARK: - Charla con el equipo

private struct Mensaje: Identifiable, Equatable {
    let id = UUID()
    let propio: Bool
    let texto: String
    let hora: Date
}

/// Charla con una persona del equipo (respuestas simuladas).
struct ChatPantalla: View {
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var mensajes: [Mensaje] = [
        Mensaje(propio: false, texto: "Hola, soy Vero, del equipo de Cuarzo. ¿En qué te ayudo?", hora: .now.addingTimeInterval(-60)),
    ]
    @State private var texto = ""
    @State private var escribiendo = false
    @FocusState private var foco: Bool

    private let rapidas = ["No me llegó una transferencia", "¿Por qué la frenaron?", "Cómo cobro con QR"]

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                Cabecera("") {
                    Redondo("xmark", "Cerrar") { dismiss() }
                } derecha: {
                    Redondo("phone", "Llamar") { estado.avisar("Te llamamos en unos minutos al celular de la cuenta.", tipo: .info) }
                }
                .overlay { encabezado }
                Separador()
                charla
                if mensajes.count == 1 { atajos }
                compositor
            }
        }
    }

    private var encabezado: some View {
        VStack(spacing: 2) {
            Text("Equipo de Cuarzo").font(.geist(16, .semi)).foregroundStyle(Color.texto)
            HStack(spacing: 5) {
                Circle().fill(Color.ok).frame(width: 7, height: 7)
                Text(escribiendo ? "escribiendo…" : "Responde en 4 min").font(.geist(12)).foregroundStyle(Color.sec)
                    .contentTransition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private var charla: some View {
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("Hoy").rotulo().frame(maxWidth: .infinity).padding(.vertical, 6)
                    ForEach(mensajes) { m in
                        burbuja(m).id(m.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if escribiendo {
                        Puntitos().id("escribiendo").transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: mensajes.count) { _, _ in
                withAnimation { lector.scrollTo(mensajes.last?.id, anchor: .bottom) }
            }
            .onChange(of: escribiendo) { _, v in
                if v { withAnimation { lector.scrollTo("escribiendo", anchor: .bottom) } }
            }
        }
    }

    private func burbuja(_ m: Mensaje) -> some View {
        HStack {
            if m.propio { Spacer(minLength: 56) }
            VStack(alignment: m.propio ? .trailing : .leading, spacing: 4) {
                Text(m.texto)
                    .font(.geist(15, m.propio ? .medio : .regular))
                    .foregroundStyle(m.propio ? Color.noche : Color.texto)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(BurbujaForma(propia: m.propio).fill(m.propio ? Color.rosa : Color.sup2))
                    .overlay(BurbujaForma(propia: m.propio).stroke(m.propio ? Color.clear : Color.linea, lineWidth: 1))
                Text(Fecha.hora(m.hora)).font(.geist(11)).foregroundStyle(Color.ter)
            }
            if !m.propio { Spacer(minLength: 56) }
        }
        .accessibilityElement(children: .combine)
    }

    private var atajos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rapidas, id: \.self) { r in Chip(texto: r) { mandar(r) } }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var compositor: some View {
        HStack(spacing: 10) {
            TextField("Escribí tu consulta", text: $texto, axis: .vertical)
                .font(.geist(15))
                .lineLimit(1...4)
                .focused($foco)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .caja(radio: 20, seleccionada: foco)
            Button {
                mandar(texto)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.noche)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(LinearGradient.botonRosa))
            }
            .buttonStyle(Presionable(escala: 0.9))
            .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Mandar")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.fondo.opacity(0.9))
    }

    private func mandar(_ t: String) {
        let limpio = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        Haptico.tocar()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            mensajes.append(Mensaje(propio: true, texto: limpio, hora: .now))
        }
        texto = ""
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation { escribiendo = true }
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                escribiendo = false
                mensajes.append(Mensaje(propio: false, texto: respuesta(limpio), hora: .now))
            }
            Haptico.suaveRecibido()
        }
    }

    private func respuesta(_ t: String) -> String {
        let q = t.paraBuscar
        if q.contains("frena") || q.contains("dni") || q.contains("dorso") {
            return "La frenamos porque falta el dorso de tu DNI. Subilo desde el aviso y sale hoy mismo. Tu plata no se movió."
        }
        if q.contains("lleg") || q.contains("transfer") {
            return "Veo la cuenta: las transferencias de hoy salieron bien. Si es una que te tienen que mandar, pasales tu alias " + estado.usuario.alias + "."
        }
        if q.contains("qr") || q.contains("cobr") {
            return "Tocá Cobrar, en el medio de la barra. Ponés el monto y te paga con cualquier billetera, sin comisión."
        }
        return "Gracias. Ya lo estoy mirando; te escribo acá en un ratito."
    }
}

/// Los tres puntos de «escribiendo…».
private struct Puntitos: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color.sec).frame(width: 7, height: 7)
                    .opacity(on ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: on)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(BurbujaForma(propia: false).fill(Color.sup2))
        .onAppear { on = true }
        .accessibilityLabel("Escribiendo")
    }
}

private extension Haptico {
    static func suaveRecibido() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
