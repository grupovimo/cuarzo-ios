import SwiftUI

/// Entrada a la cuenta: Face ID automático (simulado) o el código de 6 dígitos.
struct Bloqueo: View {
    /// Con `false` (al cerrar sesión) espera que toques el Face ID en vez de escanear solo.
    var automatico = true
    var alEntrar: () -> Void
    @Environment(Estado.self) private var estado
    @State private var modo: Modo = .faceID
    @State private var fase: FaseFace = .esperando
    @State private var pin = ""
    @State private var sacudir = 0
    @State private var aparece = false

    enum Modo { case faceID, codigo }
    enum FaseFace { case esperando, escaneando, listo }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.32), tamanoBrillo: 460)
            VStack(spacing: 0) {
                LogoCuarzo(alto: 26).padding(.top, 18)
                Spacer(minLength: 16)
                saludo
                Spacer(minLength: 16)
                if modo == .faceID { caraID.transition(.opacity) } else { codigo.transition(.opacity) }
                Spacer(minLength: 12)
                pie
            }
            .padding(.horizontal, 20)
            .opacity(aparece ? 1 : 0)
        }
        .task {
            withAnimation(.easeOut(duration: 0.4)) { aparece = true }
            if !estado.faceIDActivo { modo = .codigo } else if automatico { await escanear() }
        }
    }

    private var saludo: some View {
        VStack(spacing: 10) {
            Avatar(iniciales: estado.usuario.iniciales, tono: .rosa, tamano: 64)
            Titulo("Hola, " + estado.usuario.nombre + ".", tamano: 28, centrado: true)
            Text(modo == .faceID ? "Mirá el teléfono para entrar." : "Ingresá tu código de 6 dígitos.")
                .font(.geist(15)).foregroundStyle(Color.sec)
                .contentTransition(.opacity)
        }
    }

    private var caraID: some View {
        Button {
            Task { await escanear() }
        } label: {
            ZStack {
                Circle().fill(Color.acentoSuave).frame(width: 112, height: 112)
                    .overlay(Circle().strokeBorder(Color.acentoBorde, lineWidth: 1))
                Image(systemName: fase == .listo ? "checkmark" : "faceid")
                    .font(.system(size: fase == .listo ? 40 : 52, weight: fase == .listo ? .semibold : .light))
                    .foregroundStyle(fase == .listo ? Color.ok : Color.acento)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: fase == .escaneando)
                if fase == .escaneando { Giro() }
            }
            .frame(width: 128, height: 128)
        }
        .buttonStyle(Presionable())
        .disabled(fase != .esperando)
        .accessibilityLabel(fase == .listo ? "Listo" : "Entrar con Face ID")
    }

    private var codigo: some View {
        VStack(spacing: 26) {
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.acento : Color.clear)
                        .overlay(Circle().strokeBorder(i < pin.count ? Color.clear : Color.linea2, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                        .scaleEffect(i == pin.count - 1 ? 1.15 : 1)
                }
            }
            .modifier(Sacudida(veces: CGFloat(sacudir)))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pin)
            .accessibilityElement()
            .accessibilityLabel("\(pin.count) de 6 dígitos")
            TecladoPIN(pin: $pin) { completo() }
        }
    }

    private var pie: some View {
        VStack(spacing: 4) {
            if modo == .faceID {
                Button("Usar código") {
                    Haptico.tocar()
                    withAnimation(.easeInOut(duration: 0.25)) { modo = .codigo }
                }
                .buttonStyle(.textoRosa)
            } else {
                HStack {
                    if estado.faceIDActivo {
                        Button("Usar Face ID") {
                            withAnimation(.easeInOut(duration: 0.25)) { modo = .faceID; fase = .esperando }
                        }
                    }
                    Spacer()
                    Button("Olvidé el código") { estado.avisar("Te mandamos un SMS para crear uno nuevo.", tipo: .info) }
                }
                .font(.geist(15, .medio))
                .foregroundStyle(Color.acento)
                .buttonStyle(.plain)
                .frame(height: 44)
            }
            LeyendaPSP().padding(.top, 6)
        }
        .padding(.bottom, 10)
    }

    private func escanear() async {
        guard fase == .esperando else { return }
        try? await Task.sleep(for: .milliseconds(automatico ? 450 : 50))
        withAnimation(.easeOut(duration: 0.2)) { fase = .escaneando }
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { fase = .listo }
        Haptico.exito()
        try? await Task.sleep(for: .milliseconds(450))
        alEntrar()
    }

    private func completo() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            // Maqueta: cualquier código entra, menos 000000 (para ver el error).
            if pin == "000000" {
                Haptico.error()
                withAnimation(.linear(duration: 0.4)) { sacudir += 1 }
                try? await Task.sleep(for: .milliseconds(400))
                pin = ""
            } else {
                Haptico.exito()
                alEntrar()
            }
        }
    }
}

/// El arco que gira alrededor del Face ID.
private struct Giro: View {
    @State private var g = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(Color.acento, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 124, height: 124)
            .rotationEffect(.degrees(g ? 360 : 0))
            .onAppear { withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { g = true } }
    }
}

/// Teclado del código (sin coma).
private struct TecladoPIN: View {
    @Binding var pin: String
    var alCompletar: () -> Void

    private let filas: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "<"]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(filas.indices, id: \.self) { f in
                HStack(spacing: 0) {
                    ForEach(filas[f], id: \.self) { t in tecla(t) }
                }
            }
        }
    }

    @ViewBuilder private func tecla(_ t: String) -> some View {
        if t.isEmpty {
            Color.clear.frame(maxWidth: .infinity).frame(height: 58)
        } else {
            Button {
                if t == "<" {
                    guard !pin.isEmpty else { return }
                    pin.removeLast()
                    Haptico.tocar()
                } else if pin.count < 6 {
                    pin.append(t)
                    Haptico.tocar()
                    if pin.count == 6 { alCompletar() }
                }
            } label: {
                Group {
                    if t == "<" { Image(systemName: "delete.left").font(.system(size: 22)) } else { Text(t).font(.geistFijo(28, .medio)) }
                }
                .foregroundStyle(Color.texto)
                .frame(width: 72, height: 58)
                .background(Circle().fill(t == "<" ? Color.clear : Color.sup2).frame(width: 64, height: 64))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(Presionable(escala: 0.9))
            .accessibilityLabel(t == "<" ? "Borrar" : t)
        }
    }
}

/// Sacudida horizontal (código incorrecto).
struct Sacudida: GeometryEffect {
    var veces: CGFloat
    var animatableData: CGFloat {
        get { veces }
        set { veces = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(veces * .pi * 4), y: 0))
    }
}
