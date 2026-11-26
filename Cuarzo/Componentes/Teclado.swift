import SwiftUI

/// Lo que se va tipeando en un teclado de montos («25000», «1500,5»).
struct EntradaMonto: Equatable {
    var texto: String = ""
    var tope: Centavos = 9_999_999_999

    var centavos: Centavos { Formato.centavos(deTexto: texto) }
    var vacio: Bool { centavos == 0 }

    /// Lo que se ve: «25.000», «1.500,5», «0».
    var visible: String {
        guard !texto.isEmpty else { return "0" }
        let partes = texto.split(separator: ",", omittingEmptySubsequences: false)
        let entero = Formato.miles(Int(partes[0]) ?? 0)
        return partes.count > 1 ? entero + "," + partes[1] : entero
    }

    init(texto: String = "", tope: Centavos = 9_999_999_999) { self.texto = texto; self.tope = tope }
    init(centavos: Centavos) {
        texto = centavos == 0 ? "" : String(centavos / 100) + (centavos % 100 == 0 ? "" : "," + String(format: "%02d", centavos % 100))
    }

    /// Devuelve false si la tecla no entra (para el háptico de error).
    @discardableResult
    mutating func tocar(_ t: TeclaMonto) -> Bool {
        switch t {
        case .borrar:
            guard !texto.isEmpty else { return false }
            texto.removeLast()
            if texto == "0" { texto = "" }
        case .coma:
            guard !texto.contains(",") else { return false }
            texto = (texto.isEmpty ? "0" : texto) + ","
        case .digito(let d):
            if let c = texto.firstIndex(of: ","), texto.distance(from: c, to: texto.endIndex) > 2 { return false }
            if texto.isEmpty && d == 0 { return false }
            let nuevo = texto + String(d)
            guard Formato.centavos(deTexto: nuevo) <= tope else { return false }
            texto = nuevo
        }
        return true
    }
}

enum TeclaMonto: Hashable { case digito(Int), coma, borrar }

/// Teclado numérico del diseño (3 × 4, 52 pt por fila).
struct TecladoNumerico: View {
    @Binding var entrada: EntradaMonto
    var alto: CGFloat = 52

    private let filas: [[TeclaMonto]] = [
        [.digito(1), .digito(2), .digito(3)],
        [.digito(4), .digito(5), .digito(6)],
        [.digito(7), .digito(8), .digito(9)],
        [.coma, .digito(0), .borrar],
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(filas.indices, id: \.self) { f in
                HStack(spacing: 0) {
                    ForEach(filas[f], id: \.self) { t in tecla(t) }
                }
            }
        }
    }

    private func tecla(_ t: TeclaMonto) -> some View {
        Button {
            if entrada.tocar(t) { Haptico.tocar() } else { Haptico.aviso() }
        } label: {
            Group {
                switch t {
                case .digito(let d): Text(String(d))
                case .coma: Text(",")
                case .borrar: Image(systemName: "delete.left").font(.system(size: 22))
                }
            }
            .font(.geistFijo(26, .medio))
            .tracking(-0.5)
            .foregroundStyle(Color.texto)
            .frame(maxWidth: .infinity)
            .frame(height: alto)
            .contentShape(Rectangle())
        }
        .buttonStyle(TeclaEstilo())
        .accessibilityLabel(etiqueta(t))
    }

    private func etiqueta(_ t: TeclaMonto) -> String {
        switch t {
        case .digito(let d): return String(d)
        case .coma: return "Coma"
        case .borrar: return "Borrar"
        }
    }
}

private struct TeclaEstilo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(Color.sup3).frame(width: 64, height: 64).opacity(configuration.isPressed ? 1 : 0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// El monto que se está tipeando, con el cursor rosa titilando (pantalla 09).
struct MontoTipeado: View {
    let entrada: EntradaMonto
    var tamano: CGFloat = 56
    @State private var cursor = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("$")
                .font(.geistFijo(tamano * 0.55, .medio))
                .foregroundStyle(Color.sec)
                .baselineOffset(tamano * 0.34)
                .padding(.trailing, tamano * 0.06)
            Text(entrada.visible)
                .font(.geistFijo(tamano, .semi))
                .monospacedDigit()
                .tracking(-tamano * 0.045)
                .foregroundStyle(entrada.vacio ? Color.ter : Color.texto)
                .contentTransition(.numericText())
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.acento)
                .frame(width: 3, height: tamano * 0.78)
                .padding(.leading, 4)
                .opacity(cursor ? 1 : 0)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - tamano * 0.04 }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.45)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: entrada.texto)
        .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever()) { cursor = false } }
        .accessibilityElement()
        .accessibilityLabel(Formato.plata(entrada.centavos).replacingOccurrences(of: Formato.nbsp, with: " "))
    }
}
