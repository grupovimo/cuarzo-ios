import SwiftUI

/// La animación del cristal (comprobante, alta lista, tarjeta pedida): la C de vidrio cae girando, refracta un
/// destello y se asienta en el círculo rosa con el tilde. Termina en ~1,4 s.
struct CristalExito: View {
    var tamano: CGFloat = 68
    var animar = true
    @State private var fase = 0
    @State private var destello = false

    var body: some View {
        ZStack {
            // Halo
            Circle()
                .fill(Color.rosa.opacity(0.12))
                .frame(width: tamano + 16, height: tamano + 16)
                .scaleEffect(fase >= 2 ? 1 : 0.6)
                .opacity(fase >= 2 ? 1 : 0)
            Circle()
                .fill(RadialGradient(colors: [Color(UIColor(hex: 0xFFE8F4)), .rosa], center: UnitPoint(x: 0.5, y: 0.35),
                                     startRadius: 0, endRadius: tamano * 0.6))
                .frame(width: tamano, height: tamano)
                .shadow(color: .rosa.opacity(0.45), radius: 25)
                .scaleEffect(fase >= 2 ? 1 : 0.2)
                .opacity(fase >= 2 ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: tamano * 0.42, weight: .bold))
                .foregroundStyle(Color.noche)
                .scaleEffect(fase >= 3 ? 1 : 0.3)
                .opacity(fase >= 3 ? 1 : 0)
            // El cristal
            Image("simbolo-vidrio")
                .resizable().scaledToFit()
                .frame(width: tamano * 1.5)
                .rotation3DEffect(.degrees(fase >= 1 ? 0 : 120), axis: (x: 0.3, y: 1, z: 0.1), perspective: 0.6)
                .rotationEffect(.degrees(fase >= 1 ? 0 : -25))
                .scaleEffect(fase >= 2 ? 0.2 : (fase >= 1 ? 1 : 0.6))
                .offset(y: fase >= 1 ? 0 : -60)
                .opacity(fase == 0 ? 0 : (fase >= 2 ? 0 : 1))
                .overlay {
                    // Destello que cruza el vidrio
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: tamano * 0.5)
                        .rotationEffect(.degrees(20))
                        .offset(x: destello ? tamano : -tamano)
                        .blendMode(.plusLighter)
                        .mask(Image("simbolo-vidrio").resizable().scaledToFit().frame(width: tamano * 1.5))
                        .opacity(fase == 1 ? 1 : 0)
                }
            // Esquirlas
            ForEach(0..<6, id: \.self) { i in
                Image(i % 2 == 0 ? "cristal-a" : "cristal-b")
                    .resizable().scaledToFit()
                    .frame(width: tamano * 0.16)
                    .rotationEffect(.degrees(Double(i) * 47))
                    .offset(x: cos(Double(i) * .pi / 3) * (fase >= 3 ? tamano * 0.95 : tamano * 0.3),
                            y: sin(Double(i) * .pi / 3) * (fase >= 3 ? tamano * 0.95 : tamano * 0.3))
                    .opacity(fase == 3 ? 0.9 : 0)
                    .scaleEffect(fase >= 3 ? 1 : 0.4)
            }
        }
        .frame(width: tamano * 2.2, height: tamano * 1.9)
        .accessibilityElement()
        .accessibilityLabel("Listo")
        .task {
            guard animar else { fase = 4; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { fase = 1 }
            withAnimation(.easeInOut(duration: 0.5).delay(0.15)) { destello = true }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { fase = 2 }
            try? await Task.sleep(for: .milliseconds(180))
            Haptico.exito()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { fase = 3 }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.5)) { fase = 4 }
        }
    }
}

/// Papel de comprobante: nácar, esquinas de arriba redondeadas y el borde de abajo dentado.
struct PapelDentado: Shape {
    var radio: CGFloat = 18
    var diente: CGFloat = 7

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.maxY))
        p.addLine(to: CGPoint(x: 0, y: radio))
        p.addQuadCurve(to: CGPoint(x: radio, y: 0), control: .zero)
        p.addLine(to: CGPoint(x: r.maxX - radio, y: 0))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: radio), control: CGPoint(x: r.maxX, y: 0))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        let n = max(1, Int(r.width / (diente * 2)))
        let paso = r.width / CGFloat(n)
        var x = r.maxX
        for _ in 0..<n {
            p.addLine(to: CGPoint(x: x - paso / 2, y: r.maxY + diente))
            p.addLine(to: CGPoint(x: x - paso, y: r.maxY))
            x -= paso
        }
        p.closeSubpath()
        return p
    }
}

/// Ticket con el corte troquelado («Hoy pagás»): la línea punteada con dos medias lunas a los lados.
struct CorteTicket: View {
    var body: some View {
        ZStack {
            Line()
                .stroke(Color.linea2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 1)
                .padding(.horizontal, 18)
            HStack {
                Circle().fill(Color.fondo).frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(Color.linea, lineWidth: 1))
                    .offset(x: -10)
                Spacer()
                Circle().fill(Color.fondo).frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(Color.linea, lineWidth: 1))
                    .offset(x: 10)
            }
        }
        .frame(height: 20)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
    }
}

/// Renglón «Compra ........ $ 4.800,00» de los tickets y comprobantes.
struct RenglonTicket: View {
    let etiqueta: String
    let valor: String
    var sub: String? = nil
    var mono = false
    /// Sobre el papel nácar del comprobante, la tinta es noche.
    var papel = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(etiqueta)
                .font(.geist(papel ? 13.5 : 14))
                .foregroundStyle(papel ? Color.tintaSec : Color.sec)
                .fixedSize()
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(valor)
                    .font(mono ? .mono(12.5) : .geist(papel ? 13.5 : 14, .medio))
                    .monospacedDigit()
                    .foregroundStyle(papel ? Color.noche : Color.texto)
                    .multilineTextAlignment(.trailing)
                if let sub {
                    Text(sub).font(.mono(11)).tracking(0.2).foregroundStyle(papel ? Color.tintaSec : Color.sec)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, papel ? 7 : 9)
        .accessibilityElement(children: .combine)
    }
}
