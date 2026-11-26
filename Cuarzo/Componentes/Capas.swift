import SwiftUI

extension View {
    /// Las capas que van arriba de todo: el aviso flotante y el Face ID simulado.
    /// Va en la raíz y en cada flujo modal (las cubiertas tapan la raíz).
    func capas() -> some View { modifier(CapasCuarzo()) }
}

struct CapasCuarzo: ViewModifier {
    @Environment(Estado.self) private var estado
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let a = estado.aviso {
                    AvisoFlotante(aviso: a)
                        .padding(.top, 6)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { estado.aviso = nil } }
                        .zIndex(100)
                }
            }
            .overlay {
                if let f = estado.faceID {
                    CapaFaceID(paso: f)
                        .transition(.opacity)
                        .zIndex(200)
                }
            }
    }
}

struct AvisoFlotante: View {
    let aviso: Aviso
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: aviso.tipo == .error ? "exclamationmark.circle.fill" : aviso.tipo == .info ? "info.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(aviso.tipo == .error ? Color.error : Color.acento)
            Text(aviso.texto).font(.geist(14, .medio)).foregroundStyle(Color.texto).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.sup2.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Face ID simulado: el marco de la cara se dibuja, gira el escaneo y aparece el tilde.
struct CapaFaceID: View {
    let paso: FaceIDPaso
    @State private var giro = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    if paso.fase == .escaneando {
                        Image(systemName: "faceid")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(Color.texto)
                            .symbolEffect(.pulse, options: .repeating)
                        Circle()
                            .trim(from: 0, to: 0.22)
                            .stroke(Color.rosa, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(giro ? 360 : 0))
                            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: giro)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .regular))
                            .foregroundStyle(Color.rosa)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .frame(width: 104, height: 104)
                Text(paso.fase == .escaneando ? "Face ID" : "Listo")
                    .font(.geist(17, .semi)).foregroundStyle(Color.texto)
                Text(paso.motivo).font(.geist(13)).foregroundStyle(Color.sec).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28).padding(.vertical, 26)
            .frame(width: 220)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.sup.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.acentoBorde, lineWidth: 1))
        }
        .onAppear { giro = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(paso.fase == .escaneando ? "Verificando con Face ID" : "Face ID aprobado")
    }
}
