import Foundation

/// La plata va siempre en centavos (Int): nada de Double para montos.
typealias Centavos = Int

enum Formato {
    static let nbsp = "\u{00A0}"

    /// «1.055.630» (miles con punto, es-AR).
    static func miles(_ n: Int) -> String {
        let s = String(abs(n))
        var out = ""
        for (i, c) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(c)
        }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }

    /// Parte entera y centavos por separado: («1.055.630», «,50»).
    static func partes(_ c: Centavos) -> (entero: String, centavos: String) {
        let a = abs(c)
        return (miles(a / 100), "," + String(format: "%02d", a % 100))
    }

    /// «$ 1.055.630,50». Con `centavos: false` y monto redondo, «$ 15.000».
    static func plata(_ c: Centavos, centavos: Bool? = nil) -> String {
        let p = partes(c)
        let mostrar = centavos ?? (abs(c) % 100 != 0)
        return "$" + nbsp + p.entero + (mostrar ? p.centavos : "")
    }

    /// «+ $ 15.000» / «− $ 4.800».
    static func conSigno(_ c: Centavos, centavos: Bool? = nil) -> String {
        (c >= 0 ? "+" : "−") + nbsp + plata(abs(c), centavos: centavos)
    }

    /// Texto del teclado («25000,5») a centavos.
    static func centavos(deTexto t: String) -> Centavos {
        let partes = t.split(separator: ",", omittingEmptySubsequences: false)
        let entero = Int(partes.first.map(String.init) ?? "") ?? 0
        var dec = partes.count > 1 ? String(partes[1]) : ""
        while dec.count < 2 { dec += "0" }
        let cent: Int = Int(String(dec.prefix(2))) ?? 0
        let base: Int = entero * 100
        return base + cent
    }

    /// CVU en bloques legibles: «0000003 1000 1234 5678 901».
    static func cvu(_ s: String) -> String {
        guard s.count == 22 else { return s }
        let a = Array(s)
        let cortes: [Range<Int>] = [0..<7, 7..<11, 11..<15, 15..<19, 19..<22]
        let bloques: [String] = cortes.map { String(a[$0]) }
        return bloques.joined(separator: " ")
    }

    static func iniciales(_ nombre: String) -> String {
        let p = nombre.split(separator: " ").filter { $0.first?.isLetter == true }
        let i = p.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return i.joined()
    }

    static func lista(_ xs: [String]) -> String {
        guard xs.count > 1 else { return xs.first ?? "" }
        return xs.dropLast().joined(separator: ", ") + " y " + xs.last!
    }
}

enum Fecha {
    static let locale = Locale(identifier: "es_AR")
    static var calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires") ?? .current
        return c
    }()

    private static func f(_ formato: String) -> DateFormatter {
        let d = DateFormatter()
        d.locale = locale
        d.timeZone = calendario.timeZone
        d.dateFormat = formato
        return d
    }
    private static let fHora = f("H:mm")
    private static let fCorta = f("d/M")
    private static let fComprobante = f("dd/MM/yyyy")
    private static let fDiaMes = f("d MMM")
    private static let fLarga = f("EEEE d 'de' MMMM")
    private static let fMes = f("MMMM")
    private static let fMesCorto = f("MMM")

    static func hora(_ d: Date) -> String { fHora.string(from: d) }
    /// «1/12»
    static func corta(_ d: Date) -> String { fCorta.string(from: d) }
    /// «26/11/2026 · 9:41»
    static func comprobante(_ d: Date) -> String { fComprobante.string(from: d) + " · " + hora(d) }
    /// «25 nov.»
    static func diaMes(_ d: Date) -> String {
        var s = fDiaMes.string(from: d)
        if !s.hasSuffix(".") { s += "." }
        return s
    }
    /// «Martes 24 de noviembre»
    static func larga(_ d: Date) -> String { fLarga.string(from: d).capitalizandoPrimera }
    /// «noviembre»
    static func mes(_ d: Date) -> String { fMes.string(from: d) }
    /// «nov.»
    static func mesCorto(_ d: Date) -> String {
        var s = fMesCorto.string(from: d)
        if !s.hasSuffix(".") { s += "." }
        return s
    }

    /// Encabezado de un día en la lista: «Hoy», «Ayer · 25 nov.», «Lunes 24 · nov.».
    static func encabezado(_ d: Date, hoy: Date = .now) -> String {
        if calendario.isDate(d, inSameDayAs: hoy) { return "Hoy" }
        if let ayer = calendario.date(byAdding: .day, value: -1, to: hoy), calendario.isDate(d, inSameDayAs: ayer) {
            return "Ayer · " + diaMes(d)
        }
        return diaMes(d)
    }

    static func dias(desde a: Date, hasta b: Date) -> Int {
        calendario.dateComponents([.day], from: calendario.startOfDay(for: a), to: calendario.startOfDay(for: b)).day ?? 0
    }

    /// Hoy a una hora fija (los datos de muestra caen siempre a la misma hora).
    static func hoy(_ h: Int, _ m: Int, dias: Int = 0, hoy: Date = .now) -> Date {
        let base = calendario.date(byAdding: .day, value: dias, to: hoy) ?? hoy
        return calendario.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
    }

    /// El día `n` del mes que viene (o de este, si todavía no pasó).
    static func proximo(dia n: Int, hoy: Date = .now) -> Date {
        let c = calendario.dateComponents([.year, .month, .day], from: hoy)
        var comp = DateComponents(year: c.year, month: c.month, day: n, hour: 9)
        if (c.day ?? 1) >= n { comp.month = (c.month ?? 1) + 1 }
        return calendario.date(from: comp) ?? hoy
    }
}

extension String {
    var capitalizandoPrimera: String { prefix(1).uppercased() + dropFirst() }
    /// Sin tildes ni mayúsculas, para buscar.
    var paraBuscar: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Fecha.locale) }
}
