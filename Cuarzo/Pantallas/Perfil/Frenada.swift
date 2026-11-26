import SwiftUI

/// Transferencia frenada (pantalla 16): qué, por qué y hasta cuándo, con la salida a mano.
/// Al subir el dorso del DNI, la transferencia sale.
struct FrenadaPantalla: View {
    let frenada: Frenada
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var camara = false
    @State private var resuelta = false

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.12), tamanoBrillo: 320)
            VStack(spacing: 0) {
                HStack {
                    Redondo("xmark", "Cerrar") { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                ScrollView {
                    VStack(spacing: 0) {
                        simbolo.padding(.top, 4)
                        Titulo(resuelta ? "Listo, la soltamos." : "Frenamos esta transferencia.", tamano: 30, centrado: true)
                            .padding(.top, 18)
                            .padding(.horizontal, 16)
                        Text(resuelta ? "Le llegó a " + frenada.destino + "." : "Tu plata está a salvo en tu cuenta.")
                            .font(.geist(15)).foregroundStyle(Color.sec).multilineTextAlignment(.center)
                            .padding(.top, 8)
                        detalle.padding(.top, 26)
                        if !resuelta { tarjetaDNI.padding(.top, 12) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                pie
            }
        }
        .sheet(isPresented: $camara) {
            CamaraDorso {
                camara = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { resuelta = true }
                    Haptico.exito()
                }
            }
            .presentationDetents([.large])
            .presentationBackground(Color.fondo)
        }
    }

    private var simbolo: some View {
        ZStack {
            if resuelta {
                CristalExito(tamano: 68)
            } else {
                Circle()
                    .fill(RadialGradient(colors: [Color.alerta.opacity(0.22), Color.alerta.opacity(0.06)],
                                         center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 56))
                    .overlay(Circle().strokeBorder(Color.alerta.opacity(0.35), lineWidth: 1))
                    .frame(width: 96, height: 96)
                Image(systemName: "pause.fill").font(.system(size: 34)).foregroundStyle(Color.alerta)
            }
        }
        .frame(height: resuelta ? 130 : 96)
        .accessibilityHidden(true)
    }

    private var detalle: some View {
        VStack(spacing: 0) {
            renglon("Qué", Formato.plata(frenada.monto) + " a " + frenada.destino,
                    sub: "Desde " + frenada.bolsillo.nombre + " · " + Fecha.corta(frenada.fecha) + " · " + Fecha.hora(frenada.fecha))
            Separador()
            if resuelta {
                renglon("Estado", "Enviada. Llegó al instante.", sub: "Subiste el dorso del DNI.")
            } else {
                renglon("Por qué", frenada.porQue)
                Separador()
                renglon("Hasta", frenada.hasta, sub: "Si no, la anulamos el " + Fecha.corta(frenada.anulaEl) + " y no perdés nada.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .caja()
    }

    private func renglon(_ k: String, _ v: String, sub: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(k).font(.mono(11)).tracking(1.3).textCase(.uppercase).foregroundStyle(Color.sec)
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(v).font(.geist(15)).foregroundStyle(Color.texto).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                if let sub { Text(sub).font(.geist(13)).foregroundStyle(Color.sec).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var tarjetaDNI: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: "", tono: .rosa, simbolo: "person.text.rectangle", tamano: 44, cuadrado: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dorso del DNI").font(.geist(15, .medio)).foregroundStyle(Color.texto)
                Text("Una foto con buena luz").font(.geist(13)).foregroundStyle(Color.sec)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Rayado().clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.linea2, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var pie: some View {
        VStack(spacing: 10) {
            if resuelta {
                Button("Listo") { Haptico.tocar(); dismiss() }.buttonStyle(.principal)
            } else {
                Button { Haptico.firme(); camara = true } label: { Label("Subir el dorso", systemImage: "camera") }
                    .buttonStyle(.principal)
                Button { estado.abrir(.chat) } label: { Label("Hablar con una persona", systemImage: "bubble.left") }
                    .buttonStyle(.secundario)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// Rayas diagonales tenues (la ficha del DNI que falta).
private struct Rayado: View {
    var body: some View {
        Canvas { c, s in
            var p = Path()
            var x: CGFloat = -s.height
            while x < s.width {
                p.move(to: CGPoint(x: x, y: s.height)); p.addLine(to: CGPoint(x: x + s.height, y: 0))
                x += 16
            }
            c.stroke(p, with: .color(Color.acento.opacity(0.06)), lineWidth: 8)
        }
    }
}

/// Cámara simulada para el dorso del DNI.
private struct CamaraDorso: View {
    var listo: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fase = 0
    @State private var barrido = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Redondo("xmark", "Cerrar") { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 14)
                Spacer()
                Text(fase == 3 ? "Listo, lo leímos." : "Encuadrá el dorso del DNI.")
                    .font(.geist(20, .semi)).foregroundStyle(.white)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(UIColor(hex: 0xDCE6EE)), Color(UIColor(hex: 0xC4D2DF))], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 260, height: 164)
                        .overlay(alignment: .top) {
                            HStack(spacing: 1.5) {
                                ForEach(0..<48, id: \.self) { i in
                                    Rectangle().fill(Color(UIColor(hex: 0x3B4652))).frame(width: i % 3 == 0 ? 2.5 : 1.2, height: 34)
                                }
                            }
                            .padding(.top, 16)
                        }
                    MarcoEsquinas()
                        .stroke(fase == 3 ? Color.ok : Color.rosa, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 284, height: 188)
                    if fase < 3 {
                        LinearGradient(colors: [.clear, .rosa, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 250, height: 2)
                            .shadow(color: .rosa.opacity(0.7), radius: 8)
                            .offset(y: barrido ? 74 : -74)
                    }
                    if fase == 1 { Color.white.opacity(0.85).frame(width: 300, height: 200) }
                    if fase == 3 {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 46)).foregroundStyle(Color.ok)
                            .background(Circle().fill(.black).padding(4))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 220)
                Spacer()
                Button {
                    sacar()
                } label: {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 74, height: 74)
                        .overlay(Circle().fill(.white).padding(8))
                }
                .buttonStyle(Presionable(escala: 0.9))
                .disabled(fase != 0)
                .accessibilityLabel("Sacar la foto")
                .padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { barrido = true } }
    }

    private func sacar() {
        Haptico.firme()
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.08)) { fase = 1 }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation { fase = 2 }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { fase = 3 }
            Haptico.exito()
            try? await Task.sleep(for: .milliseconds(700))
            listo()
        }
    }
}
