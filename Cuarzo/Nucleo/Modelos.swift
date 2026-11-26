import Foundation

/// Los dos bolsillos de la cuenta: el del laburo y el tuyo.
enum Bolsillo: String, Codable, CaseIterable, Identifiable, Hashable {
    case negocio, personal
    var id: String { rawValue }
    var nombre: String { self == .negocio ? "Negocio" : "Personal" }
    /// SF Symbol (maletín / billetera del diseño).
    var simbolo: String { self == .negocio ? "briefcase" : "wallet.bifold" }
    var otro: Bolsillo { self == .negocio ? .personal : .negocio }
}

struct Usuario: Codable, Hashable {
    var nombre: String
    var apellido: String
    var negocio: String
    var rubro: String
    var barrio: String
    var cuit: String
    var dni: String
    var alias: String
    var cvu: String
    var email: String
    var telefono: String
    var validado: Bool

    var nombreCompleto: String { nombre + " " + apellido }
    var iniciales: String { Formato.iniciales(nombreCompleto) }
}

/// Alguien a quien le mandás plata (o que te manda).
struct Contacto: Identifiable, Codable, Hashable {
    var id: String
    var nombre: String
    var alias: String
    var cvu: String
    var banco: String
    var cuit: String
    var favorito: Bool
    var tono: Tono
    /// Las cuentas Cuarzo reciben al instante y sin costo.
    var esCuarzo: Bool { banco == "Cuarzo" }
    var iniciales: String { Formato.iniciales(nombre) }
}

/// Un comercio que muestra un QR (con monto o sin monto).
struct Comercio: Identifiable, Codable, Hashable {
    var id: String
    var nombre: String
    var direccion: String
    var cuit: String
    var verificado: Bool
    /// nil: QR sin monto (lo cargás vos).
    var monto: Centavos?
    var simbolo: String
}

enum TipoMovimiento: String, Codable, Hashable {
    case cobroQR, cobroLink, cobroTarjeta, transferenciaRecibida, transferenciaEnviada,
         pagoQR, compraTarjeta, pase, apartado, rendimiento, ingreso

    var nombre: String {
        switch self {
        case .cobroQR: return "Cobro con QR"
        case .cobroLink: return "Cobro con link"
        case .cobroTarjeta: return "Cobro con tarjeta"
        case .transferenciaRecibida: return "Transferencia recibida"
        case .transferenciaEnviada: return "Transferencia"
        case .pagoQR: return "Pago con QR"
        case .compraTarjeta: return "Tarjeta virtual"
        case .pase: return "Pase entre bolsillos"
        case .apartado: return "Apartado"
        case .rendimiento: return "Rendimiento"
        case .ingreso: return "Ingreso de plata"
        }
    }

    var esEntrada: Bool {
        [.cobroQR, .cobroLink, .cobroTarjeta, .transferenciaRecibida, .rendimiento, .ingreso].contains(self)
    }
}

enum EstadoMovimiento: String, Codable, Hashable {
    case listo, enRevision, frenado, devuelto
    var nombre: String {
        switch self {
        case .listo: return "Listo"
        case .enRevision: return "En revisión"
        case .frenado: return "Frenado"
        case .devuelto: return "Devuelto"
        }
    }
}

struct Movimiento: Identifiable, Codable, Hashable {
    /// Número de operación (CZ-4F7K-29QX-11).
    var id: String
    var titulo: String
    var detalle: String
    /// Con signo: positivo entra, negativo sale. Los pases van en positivo.
    var centavos: Centavos
    var fecha: Date
    var bolsillo: Bolsillo
    var tipo: TipoMovimiento
    var estado: EstadoMovimiento = .listo
    /// CVU o CUIT de la otra parte.
    var contraparteCuenta: String? = nil
    var contraparteCuit: String? = nil
    var motivo: String? = nil
    var tono: Tono = .neutro
    /// Si va un ícono en vez de iniciales (comercios, pases, tarjeta).
    var simbolo: String? = nil
    var comision: Centavos = 0

    var iniciales: String { Formato.iniciales(titulo) }
    /// Subtítulo de la fila: «Seña del turno · Negocio».
    var subtitulo: String { [detalle, bolsillo.nombre].filter { !$0.isEmpty }.joined(separator: " · ") }
}

/// Plata con nombre: alquiler, aguinaldo, monotributo…
struct Apartado: Identifiable, Codable, Hashable {
    var id: String
    var nombre: String
    /// Ícono 3D del recurso (ic-llaves, ic-calendario, ic-escudo, ic-frasco…).
    var icono: String
    var objetivo: Centavos
    var actual: Centavos
    var vence: Date?
    /// «Se llena con el 15 % de cada cobro», «$ 40.000 cada viernes».
    var regla: Regla
    var bolsillo: Bolsillo

    enum Regla: Codable, Hashable {
        case porcentaje(Int)
        case fijo(Centavos, String)
        case manual
    }

    var progreso: Double { objetivo > 0 ? min(1, Double(actual) / Double(objetivo)) : 0 }
    var falta: Centavos { max(0, objetivo - actual) }
    var listo: Bool { actual >= objetivo }
}

enum DisenoTarjeta: String, Codable, CaseIterable, Identifiable, Hashable {
    case vidrio, rosa, noche, virtual
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .vidrio: return "Cuarzo"
        case .rosa: return "Rosa"
        case .noche: return "Noche"
        case .virtual: return "Virtual"
        }
    }
    var frente: String { "tarjeta-\(rawValue)-frente" }
    var dorso: String { "tarjeta-\(rawValue)-dorso" }
}

struct Tarjeta: Identifiable, Codable, Hashable {
    enum Tipo: String, Codable, Hashable { case virtual, fisica }
    enum EstadoFisica: Codable, Hashable { case sinPedir, enCamino(Date), activa }

    var id: String
    var tipo: Tipo
    var numero: String
    var vence: String
    var cvv: String
    var titular: String
    var diseno: DisenoTarjeta
    var bolsillo: Bolsillo
    var congelada: Bool
    var comprasAfuera: Bool
    var comprasOnline: Bool
    var limiteDia: Centavos
    var usadoDia: Centavos
    var limiteMes: Centavos
    var usadoMes: Centavos
    var estadoFisica: EstadoFisica

    var ultimos4: String { String(numero.suffix(4)) }
    var numeroEnBloques: String {
        stride(from: 0, to: numero.count, by: 4).map { i -> String in
            let a = numero.index(numero.startIndex, offsetBy: i)
            let b = numero.index(a, offsetBy: min(4, numero.count - i))
            return String(numero[a..<b])
        }.joined(separator: " ")
    }
}

struct LinkDePago: Identifiable, Codable, Hashable {
    enum Estado: String, Codable, Hashable { case pendiente, pagado, vencido }
    var id: String
    var concepto: String
    var centavos: Centavos?
    var creado: Date
    var estado: Estado
    var pagadoPor: String?
    var url: String { "https://cuarzo.ar/p/" + id.lowercased() }
}

/// Lo que se acredita de los cobros con tarjeta del negocio.
struct Liquidacion: Identifiable, Codable, Hashable {
    var id: String
    var fecha: Date
    var operaciones: Int
    var bruto: Centavos
    var comision: Centavos
    var acreditada: Bool
    var neto: Centavos { bruto - comision }
}

struct Notificacion: Identifiable, Codable, Hashable {
    var id: String
    var titulo: String
    var texto: String
    var fecha: Date
    var leida: Bool
    var simbolo: String
}

struct Rendimiento: Codable, Hashable {
    /// TNA de referencia (dato de muestra).
    var tna: Double
    var ganadoHoy: Centavos
    var ganadoMes: Centavos
    /// Lo de los últimos 14 días, para el gráfico.
    var historial: [Centavos]
}

struct Dispositivo: Identifiable, Codable, Hashable {
    var id: String
    var nombre: String
    var detalle: String
    var esEste: Bool
}

/// Una transferencia frenada (pantalla 16): qué, por qué y hasta cuándo.
struct Frenada: Identifiable, Codable, Hashable {
    var id: String
    var monto: Centavos
    var destino: String
    var bolsillo: Bolsillo
    var fecha: Date
    var porQue: String
    var hasta: String
    var anulaEl: Date
}

/// Todo lo que la app necesita para dibujarse. Lo devuelve `Datos.panel()`.
struct Panel: Codable, Hashable {
    var usuario: Usuario
    var saldos: [Bolsillo: Centavos]
    var movimientos: [Movimiento]
    var contactos: [Contacto]
    var apartados: [Apartado]
    var tarjetas: [Tarjeta]
    var links: [LinkDePago]
    var liquidaciones: [Liquidacion]
    var notificaciones: [Notificacion]
    var rendimiento: Rendimiento
    var dispositivos: [Dispositivo]
    /// Pasos de «Para arrancar» ya hechos (cuenta nueva).
    var pasosHechos: Set<PasoArranque>
    var frenadas: [Frenada]
}

/// La lista «Para arrancar» de la cuenta nueva (pantalla 15).
enum PasoArranque: String, Codable, CaseIterable, Hashable {
    case identidad, primeraPlata, qrNegocio, primerApartado
}

enum ErrorCuarzo: Error, Equatable, LocalizedError {
    case sinConexion
    case sinSaldo
    case destinoNoEncontrado
    case frenada(Frenada)
    case limite(Centavos)
    case rechazada(String)

    var errorDescription: String? {
        switch self {
        case .sinConexion: return "No hay conexión. Tu plata está a salvo; probá de nuevo en un rato."
        case .sinSaldo: return "No te alcanza en ese bolsillo. Podés pasar plata del otro."
        case .destinoNoEncontrado: return "No encontramos ese CVU o alias. Revisalo y probá de nuevo."
        case .frenada: return "Frenamos esta transferencia para cuidarte."
        case .limite(let l): return "Supera tu límite de " + Formato.plata(l) + " por día."
        case .rechazada(let m): return m
        }
    }
}
