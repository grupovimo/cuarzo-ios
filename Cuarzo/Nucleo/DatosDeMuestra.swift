import Foundation

/// Datos de muestra en memoria (los de las pantallas del diseño). Simula la demora de la red, los errores
/// (sin saldo, CVU que no existe, transferencia frenada) y el modo sin conexión.
actor DatosDeMuestra: Datos {
    private var p: Panel
    private var secuencia = 0
    /// Lo prende el modo de prueba de Perfil: todo lo que va al servidor falla.
    var sinConexion = false
    /// Demora simulada de la red (los tests la ponen en 0).
    let demora: Double

    init(cuentaNueva: Bool = false, demora: Double = 0.7) {
        p = cuentaNueva ? Self.panelNuevo() : Self.panelCompleto()
        self.demora = demora
    }

    func ponerSinConexion(_ v: Bool) { sinConexion = v }

    // MARK: - Datos

    func panel() async throws -> Panel {
        try await red(0.4)
        return p
    }

    func buscarDestino(_ texto: String) async throws -> Contacto {
        try await red(0.6)
        let t = texto.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "")
        if let c = p.contactos.first(where: { $0.alias == t || $0.cvu == t }) { return c }
        if t.count == 22, t.allSatisfy(\.isNumber) {
            if t.hasPrefix("0000003") {
                return Contacto(id: "c-" + t.suffix(6), nombre: "Juan Pérez", alias: "juan.perez.cz", cvu: t, banco: "Cuarzo",
                                cuit: "20-28765432-1", favorito: false, tono: .violeta)
            }
            return Contacto(id: "c-" + t.suffix(6), nombre: "Juan Pérez", alias: "juan.perez.nacion", cvu: t, banco: "Banco Nación",
                            cuit: "20-28765432-1", favorito: false, tono: .violeta)
        }
        let valido = t.count >= 6 && t.count <= 20 && t.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        guard valido, !t.contains("noexiste"), !t.contains("no.existe") else { throw ErrorCuarzo.destinoNoEncontrado }
        let partes = t.split(separator: ".").prefix(2).map { String($0).capitalizandoPrimera }
        let nombre = partes.count == 2 ? partes.joined(separator: " ") : (partes.first ?? "Cuenta")
        let cuarzo = t.hasSuffix(".cz")
        return Contacto(id: "c-" + t, nombre: nombre, alias: t, cvu: cuarzo ? "0000003100055512340987" : "2850590940090418135201",
                        banco: cuarzo ? "Cuarzo" : "Banco Macro", cuit: "27-31234567-0", favorito: false, tono: .menta)
    }

    func transferir(a destino: Contacto, centavos: Centavos, desde: Bolsillo, motivo: String) async throws -> Movimiento {
        try await red(destino.esCuarzo ? 0.8 : 1.2)
        try alcanza(centavos, desde)
        if centavos >= 50_000_000 {
            let f = Frenada(id: nuevoID(), monto: centavos, destino: destino.nombre, bolsillo: desde, fecha: .now,
                            porQue: "Es más de lo que movés en un día y falta el dorso de tu DNI.",
                            hasta: "Sale apenas lo subas, hoy mismo.",
                            anulaEl: Fecha.calendario.date(byAdding: .day, value: 1, to: .now) ?? .now)
            p.frenadas.insert(f, at: 0)
            throw ErrorCuarzo.frenada(f)
        }
        p.saldos[desde, default: 0] -= centavos
        let m = Movimiento(id: nuevoID(), titulo: destino.nombre, detalle: motivo, centavos: -centavos, fecha: .now,
                           bolsillo: desde, tipo: .transferenciaEnviada, contraparteCuenta: destino.cvu,
                           contraparteCuit: destino.cuit, motivo: motivo, tono: destino.tono)
        p.movimientos.insert(m, at: 0)
        if !p.contactos.contains(where: { $0.id == destino.id }) { p.contactos.append(destino) }
        return m
    }

    func pagar(_ comercio: Comercio, centavos: Centavos, desde: Bolsillo) async throws -> Movimiento {
        try await red(0.9)
        try alcanza(centavos, desde)
        p.saldos[desde, default: 0] -= centavos
        let m = Movimiento(id: nuevoID(), titulo: comercio.nombre, detalle: "Pago con QR", centavos: -centavos, fecha: .now,
                           bolsillo: desde, tipo: .pagoQR, contraparteCuit: comercio.cuit, tono: .cobre, simbolo: comercio.simbolo)
        p.movimientos.insert(m, at: 0)
        return m
    }

    func pasar(_ centavos: Centavos, de origen: Bolsillo) async throws -> Movimiento {
        try await red(0.5)
        try alcanza(centavos, origen)
        p.saldos[origen, default: 0] -= centavos
        p.saldos[origen.otro, default: 0] += centavos
        let m = Movimiento(id: nuevoID(), titulo: "Te pasaste plata", detalle: origen.nombre + " → " + origen.otro.nombre,
                           centavos: centavos, fecha: .now, bolsillo: origen.otro, tipo: .pase, simbolo: "arrow.left.arrow.right")
        p.movimientos.insert(m, at: 0)
        return m
    }

    func crearLink(concepto: String, centavos: Centavos?) async throws -> LinkDePago {
        try await red(0.5)
        let l = LinkDePago(id: "L" + nuevoID().suffix(6).replacingOccurrences(of: "-", with: ""), concepto: concepto,
                           centavos: centavos, creado: .now, estado: .pendiente, pagadoPor: nil)
        p.links.insert(l, at: 0)
        return l
    }

    func cobrarConTarjeta(_ centavos: Centavos, concepto: String) async throws -> Movimiento {
        try await red(1.0)
        let comision = centavos * 15 / 1000
        p.saldos[.negocio, default: 0] += centavos - comision
        let m = Movimiento(id: nuevoID(), titulo: "Visa débito ·· 4417", detalle: concepto.isEmpty ? "Cobro con tarjeta" : concepto,
                           centavos: centavos - comision, fecha: .now, bolsillo: .negocio, tipo: .cobroTarjeta,
                           tono: .violeta, simbolo: "wave.3.right", comision: comision)
        p.movimientos.insert(m, at: 0)
        return m
    }

    func guardarApartado(_ a: Apartado) async throws {
        try await red(0.4)
        if let i = p.apartados.firstIndex(where: { $0.id == a.id }) { p.apartados[i] = a } else { p.apartados.append(a) }
        p.pasosHechos.insert(.primerApartado)
    }

    func borrarApartado(id: String) async throws {
        try await red(0.4)
        if let a = p.apartados.first(where: { $0.id == id }) { p.saldos[a.bolsillo, default: 0] += a.actual }
        p.apartados.removeAll { $0.id == id }
    }

    func mover(_ centavos: Centavos, apartado id: String) async throws -> Movimiento {
        try await red(0.5)
        guard let i = p.apartados.firstIndex(where: { $0.id == id }) else { throw ErrorCuarzo.rechazada("Ese apartado ya no existe.") }
        let b = p.apartados[i].bolsillo
        if centavos > 0 { try alcanza(centavos, b) }
        if centavos < 0 && -centavos > p.apartados[i].actual { throw ErrorCuarzo.sinSaldo }
        p.apartados[i].actual += centavos
        p.saldos[b, default: 0] -= centavos
        let m = Movimiento(id: nuevoID(), titulo: p.apartados[i].nombre, detalle: centavos > 0 ? "Guardaste" : "Sacaste",
                           centavos: -centavos, fecha: .now, bolsillo: b, tipo: .apartado, tono: .rosa, simbolo: "lock")
        p.movimientos.insert(m, at: 0)
        return m
    }

    func guardarTarjeta(_ t: Tarjeta) async throws {
        try await red(0.4)
        if let i = p.tarjetas.firstIndex(where: { $0.id == t.id }) { p.tarjetas[i] = t }
    }

    func pedirFisica(diseno: DisenoTarjeta, direccion: String) async throws -> Tarjeta {
        try await red(0.9)
        guard let i = p.tarjetas.firstIndex(where: { $0.tipo == .fisica }) else { throw ErrorCuarzo.rechazada("No pudimos pedirla.") }
        p.tarjetas[i].diseno = diseno
        p.tarjetas[i].estadoFisica = .enCamino(Fecha.calendario.date(byAdding: .day, value: 5, to: .now) ?? .now)
        return p.tarjetas[i]
    }

    func guardarContacto(_ c: Contacto) async throws {
        try await red(0.2)
        if let i = p.contactos.firstIndex(where: { $0.id == c.id }) { p.contactos[i] = c } else { p.contactos.append(c) }
    }

    func marcarPaso(_ paso: PasoArranque) async throws {
        try await red(0.2)
        p.pasosHechos.insert(paso)
    }

    // MARK: - Ayudas

    private func red(_ s: Double) async throws {
        if demora > 0 { try? await Task.sleep(for: .seconds(s * demora / 0.7)) }
        if sinConexion { throw ErrorCuarzo.sinConexion }
    }

    private func alcanza(_ c: Centavos, _ b: Bolsillo) throws {
        if c > p.saldos[b, default: 0] { throw ErrorCuarzo.sinSaldo }
    }

    private func nuevoID() -> String {
        secuencia += 1
        let abc = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        var s = UInt64(Date.now.timeIntervalSince1970 * 1000) &+ UInt64(secuencia * 7919)
        var out = ""
        for _ in 0..<8 { out.append(abc[Int(s % UInt64(abc.count))]); s /= UInt64(abc.count) }
        let a = Array(out)
        return "CZ-" + String(a[0..<4]) + "-" + String(a[4..<8]) + "-" + String(format: "%02d", secuencia % 100)
    }
}

// MARK: - El panel de muestra (Carla, Estudio Carla · Palermo)

extension DatosDeMuestra {
    static let usuario = Usuario(nombre: "Carla", apellido: "Benítez", negocio: "Estudio Carla", rubro: "Peluquería",
                                 barrio: "Palermo", cuit: "27-33456789-4", dni: "33.456.789", alias: "estudio.carla.cz",
                                 cvu: "0000003100012345678901", email: "carla@estudiocarla.com.ar", telefono: "+54 11 5555-0142",
                                 validado: true)

    static let contactos: [Contacto] = [
        Contacto(id: "c-martina", nombre: "Martina Ríos", alias: "martina.rios.cz", cvu: "0000003100098765432109", banco: "Cuarzo",
                 cuit: "27-38912345-6", favorito: true, tono: .rosa),
        Contacto(id: "c-lucas", nombre: "Lucas Ferreyra", alias: "lucas.ferreyra.cz", cvu: "0000003100045678123456", banco: "Cuarzo",
                 cuit: "20-35123456-7", favorito: true, tono: .violeta),
        Contacto(id: "c-inmo", nombre: "Inmobiliaria Sur", alias: "inmo.sur.alquileres", cvu: "0170099220000067812345", banco: "Banco Francés",
                 cuit: "30-70987654-3", favorito: true, tono: .cobre),
        Contacto(id: "c-graciela", nombre: "Graciela Benítez", alias: "graciela.mama", cvu: "0110599520000012345678", banco: "Banco Nación",
                 cuit: "27-14567890-1", favorito: true, tono: .menta),
        Contacto(id: "c-sofi", nombre: "Sofía Paz", alias: "sofi.paz.cz", cvu: "0000003100033322211100", banco: "Cuarzo",
                 cuit: "27-40123456-2", favorito: false, tono: .rosa),
        Contacto(id: "c-distri", nombre: "Distribuidora Belgrano", alias: "distri.belgrano", cvu: "0720123420000001234567", banco: "Banco Santander",
                 cuit: "30-71555666-9", favorito: false, tono: .cobre),
        Contacto(id: "c-nico", nombre: "Nicolás Romero", alias: "nico.romero.cz", cvu: "0000003100077788899900", banco: "Cuarzo",
                 cuit: "20-37444555-1", favorito: false, tono: .violeta),
    ]

    static let comercios: [Comercio] = [
        Comercio(id: "espiga", nombre: "Panadería La Espiga", direccion: "Av. Corrientes 4120 · CABA", cuit: "30-71234567-8",
                 verificado: true, monto: 480_000, simbolo: "bag"),
        Comercio(id: "tito", nombre: "Verdulería Don Tito", direccion: "Gorriti 4870 · CABA", cuit: "20-22345678-3",
                 verificado: true, monto: nil, simbolo: "basket"),
    ]

    static func movimientos(hoy: Date = .now) -> [Movimiento] {
        let h = { (hh: Int, mm: Int, d: Int) in Fecha.hoy(hh, mm, dias: d, hoy: hoy) }
        return [
            Movimiento(id: "CZ-9MR2-15KQ-01", titulo: "Martina Ríos", detalle: "Seña del turno", centavos: 1_500_000, fecha: h(9, 12, 0),
                       bolsillo: .negocio, tipo: .transferenciaRecibida, contraparteCuenta: "0000003100098765432109",
                       contraparteCuit: "27-38912345-6", motivo: "Seña del turno", tono: .rosa),
            Movimiento(id: "CZ-LF32-QR7X-02", titulo: "Lucas Ferreyra", detalle: "Cobro con QR", centavos: 3_200_000, fecha: h(8, 47, 0),
                       bolsillo: .negocio, tipo: .cobroQR, contraparteCuit: "20-35123456-7", tono: .violeta),
            Movimiento(id: "CZ-ESP4-8000-03", titulo: "Panadería La Espiga", detalle: "Pago con QR", centavos: -480_000, fecha: h(8, 5, 0),
                       bolsillo: .personal, tipo: .pagoQR, contraparteCuit: "30-71234567-8", tono: .cobre, simbolo: "bag"),
            Movimiento(id: "CZ-REND-0001-04", titulo: "Rendimiento del día", detalle: "Apartados", centavos: 53_120, fecha: h(0, 5, 0),
                       bolsillo: .personal, tipo: .rendimiento, tono: .menta, simbolo: "chart.line.uptrend.xyaxis"),
            Movimiento(id: "CZ-PASE-3500-05", titulo: "Te pasaste el sueldo", detalle: "Negocio → Personal", centavos: 35_000_000,
                       fecha: h(19, 30, -1), bolsillo: .personal, tipo: .pase, simbolo: "arrow.left.arrow.right"),
            Movimiento(id: "CZ-DIA3-8920-06", titulo: "Supermercado Día", detalle: "Tarjeta virtual", centavos: -3_892_040, fecha: h(18, 2, -1),
                       bolsillo: .personal, tipo: .compraTarjeta, tono: .menta, simbolo: "storefront"),
            Movimiento(id: "CZ-LINK-2200-07", titulo: "Valentina Gómez", detalle: "Corte y color · link", centavos: 2_200_000, fecha: h(16, 40, -1),
                       bolsillo: .negocio, tipo: .cobroLink, contraparteCuit: "27-41222333-4", tono: .violeta),
            Movimiento(id: "CZ-DIST-6500-08", titulo: "Distribuidora Belgrano", detalle: "Insumos", centavos: -6_500_000, fecha: h(11, 15, -1),
                       bolsillo: .negocio, tipo: .transferenciaEnviada, contraparteCuenta: "0720123420000001234567",
                       contraparteCuit: "30-71555666-9", motivo: "Insumos", tono: .cobre),
            Movimiento(id: "CZ-TARJ-1800-09", titulo: "Visa débito ·· 2231", detalle: "Cobro con tarjeta", centavos: 1_773_000, fecha: h(17, 20, -2),
                       bolsillo: .negocio, tipo: .cobroTarjeta, tono: .violeta, simbolo: "wave.3.right", comision: 27_000),
            Movimiento(id: "CZ-ALQ0-6300-10", titulo: "Alquiler de diciembre", detalle: "Guardaste", centavos: -6_300_000, fecha: h(10, 0, -2),
                       bolsillo: .personal, tipo: .apartado, tono: .rosa, simbolo: "lock"),
            Movimiento(id: "CZ-SOFI-9000-11", titulo: "Sofía Paz", detalle: "Cobro con QR", centavos: 900_000, fecha: h(15, 10, -3),
                       bolsillo: .negocio, tipo: .cobroQR, tono: .rosa),
            Movimiento(id: "CZ-GRAC-5000-12", titulo: "Graciela Benítez", detalle: "Varios", centavos: -5_000_000, fecha: h(20, 45, -4),
                       bolsillo: .personal, tipo: .transferenciaEnviada, contraparteCuenta: "0110599520000012345678",
                       contraparteCuit: "27-14567890-1", motivo: "Varios", tono: .menta),
            Movimiento(id: "CZ-NETF-4499-13", titulo: "Suscripción de streaming", detalle: "Tarjeta virtual", centavos: -449_900, fecha: h(7, 0, -5),
                       bolsillo: .personal, tipo: .compraTarjeta, tono: .neutro, simbolo: "play.rectangle"),
            Movimiento(id: "CZ-NICO-2800-14", titulo: "Nicolás Romero", detalle: "Corte", centavos: 1_200_000, fecha: h(12, 30, -6),
                       bolsillo: .negocio, tipo: .transferenciaRecibida, contraparteCuenta: "0000003100077788899900", tono: .violeta),
            Movimiento(id: "CZ-INGR-1000-15", titulo: "Ingreso desde Banco Galicia", detalle: "A tu CVU", centavos: 20_000_000, fecha: h(9, 0, -8),
                       bolsillo: .personal, tipo: .ingreso, tono: .neutro, simbolo: "building.columns"),
        ]
    }

    static func apartados(hoy: Date = .now) -> [Apartado] {
        [
            Apartado(id: "a-alquiler", nombre: "Alquiler de diciembre", icono: "ic-llaves", objetivo: 42_000_000, actual: 25_200_000,
                     vence: Fecha.proximo(dia: 1, hoy: hoy), regla: .porcentaje(15), bolsillo: .personal),
            Apartado(id: "a-aguinaldo", nombre: "Aguinaldo propio", icono: "ic-calendario", objetivo: 48_000_000, actual: 31_200_000,
                     vence: Fecha.proximo(dia: 18, hoy: hoy), regla: .fijo(4_000_000, "cada viernes"), bolsillo: .personal),
            Apartado(id: "a-monotributo", nombre: "Monotributo", icono: "ic-escudo", objetivo: 4_239_000, actual: 4_239_000,
                     vence: Fecha.proximo(dia: 20, hoy: hoy), regla: .manual, bolsillo: .negocio),
        ]
    }

    static func tarjetas() -> [Tarjeta] {
        [
            Tarjeta(id: "t-virtual", tipo: .virtual, numero: "4517382081642048", vence: "11/30", cvv: "731", titular: "CARLA BENITEZ",
                    diseno: .vidrio, bolsillo: .personal, congelada: false, comprasAfuera: false, comprasOnline: true,
                    limiteDia: 30_000_000, usadoDia: 3_892_000, limiteMes: 150_000_000, usadoMes: 41_230_000, estadoFisica: .activa),
            Tarjeta(id: "t-fisica", tipo: .fisica, numero: "4517382055109917", vence: "11/31", cvv: "208", titular: "CARLA BENITEZ",
                    diseno: .vidrio, bolsillo: .personal, congelada: false, comprasAfuera: false, comprasOnline: true,
                    limiteDia: 30_000_000, usadoDia: 0, limiteMes: 150_000_000, usadoMes: 0, estadoFisica: .sinPedir),
        ]
    }

    static func panelCompleto(hoy: Date = .now) -> Panel {
        let h = { (hh: Int, mm: Int, d: Int) in Fecha.hoy(hh, mm, dias: d, hoy: hoy) }
        return Panel(
            usuario: usuario,
            saldos: [.negocio: 84_215_000, .personal: 21_348_050],
            movimientos: movimientos(hoy: hoy),
            contactos: contactos,
            apartados: apartados(hoy: hoy),
            tarjetas: tarjetas(),
            links: [
                LinkDePago(id: "LK7Q2M", concepto: "Corte y color", centavos: 1_500_000, creado: h(9, 30, 0), estado: .pendiente, pagadoPor: nil),
                LinkDePago(id: "LV8G3T", concepto: "Corte y color", centavos: 2_200_000, creado: h(14, 0, -1), estado: .pagado, pagadoPor: "Valentina Gómez"),
                LinkDePago(id: "LB4N9P", concepto: "Seña de turno", centavos: 500_000, creado: h(10, 0, -9), estado: .vencido, pagadoPor: nil),
            ],
            liquidaciones: [
                Liquidacion(id: "LQ-1126", fecha: h(18, 0, 0), operaciones: 3, bruto: 4_150_000, comision: 62_250, acreditada: false),
                Liquidacion(id: "LQ-1125", fecha: h(18, 0, -1), operaciones: 5, bruto: 7_320_000, comision: 109_800, acreditada: true),
                Liquidacion(id: "LQ-1124", fecha: h(18, 0, -2), operaciones: 2, bruto: 1_800_000, comision: 27_000, acreditada: true),
                Liquidacion(id: "LQ-1123", fecha: h(18, 0, -3), operaciones: 4, bruto: 5_640_000, comision: 84_600, acreditada: true),
            ],
            notificaciones: [
                Notificacion(id: "n1", titulo: "Te entró $ 15.000", texto: "Seña de Martina Ríos, al bolsillo Negocio.", fecha: h(9, 12, 0),
                             leida: false, simbolo: "arrow.down.left"),
                Notificacion(id: "n2", titulo: "El alquiler vence el 1/12", texto: "Faltan $ 168.000 en el apartado.", fecha: h(8, 0, 0),
                             leida: false, simbolo: "key"),
                Notificacion(id: "n3", titulo: "Tu plata rindió $ 531,20", texto: "Lo de tus apartados, ayer.", fecha: h(0, 5, 0),
                             leida: true, simbolo: "chart.line.uptrend.xyaxis"),
                Notificacion(id: "n4", titulo: "Nuevo ingreso desde un iPad", texto: "Si no fuiste vos, cerrá la sesión desde Seguridad.",
                             fecha: h(21, 10, -2), leida: true, simbolo: "ipad"),
            ],
            rendimiento: Rendimiento(tna: 0.32, ganadoHoy: 53_120, ganadoMes: 1_284_550,
                                     historial: [41_200, 43_900, 44_100, 45_800, 47_020, 46_300, 48_800, 49_100, 50_400, 49_900, 51_700, 52_300, 52_950, 53_120]),
            dispositivos: [
                Dispositivo(id: "d1", nombre: "iPhone 15", detalle: "Este · Buenos Aires", esEste: true),
                Dispositivo(id: "d2", nombre: "iPad", detalle: "Hace 2 días · Buenos Aires", esEste: false),
            ],
            pasosHechos: Set(PasoArranque.allCases),
            frenadas: []
        )
    }

    /// La cuenta recién abierta (Juan, saldo $ 0): pantalla 15.
    static func panelNuevo(hoy: Date = .now) -> Panel {
        var u = usuario
        u.nombre = "Juan"; u.apellido = "Paredes"; u.negocio = "Juan Paredes"; u.rubro = "Electricista"; u.barrio = "Caballito"
        u.alias = "juan.paredes.cz"; u.cvu = "0000003100067812340012"; u.cuit = "20-36123456-5"; u.dni = "36.123.456"
        u.email = "juan.paredes@correo.com.ar"
        var t = tarjetas()
        t[0].titular = "JUAN PAREDES"; t[0].usadoDia = 0; t[0].usadoMes = 0; t[1].titular = "JUAN PAREDES"
        return Panel(usuario: u, saldos: [.negocio: 0, .personal: 0], movimientos: [], contactos: [], apartados: [], tarjetas: t,
                     links: [], liquidaciones: [], notificaciones: [
                        Notificacion(id: "n0", titulo: "Tu cuenta ya está abierta", texto: "Validamos tu identidad con RENAPER.",
                                     fecha: .now, leida: false, simbolo: "checkmark.shield"),
                     ],
                     rendimiento: Rendimiento(tna: 0.32, ganadoHoy: 0, ganadoMes: 0, historial: Array(repeating: 0, count: 14)),
                     dispositivos: [Dispositivo(id: "d1", nombre: "iPhone 15", detalle: "Este · Buenos Aires", esEste: true)],
                     pasosHechos: [.identidad], frenadas: [])
    }

    /// La frenada de muestra (pantalla 16).
    static let frenada = Frenada(id: "CZ-FREN-2800-00", monto: 28_000_000, destino: "Inmobiliaria Sur", bolsillo: .negocio,
                                 fecha: Fecha.hoy(9, 38), porQue: "Es más de lo que movés en un día y falta el dorso de tu DNI.",
                                 hasta: "Sale apenas lo subas, hoy mismo.",
                                 anulaEl: Fecha.calendario.date(byAdding: .day, value: 1, to: .now) ?? .now)
}
