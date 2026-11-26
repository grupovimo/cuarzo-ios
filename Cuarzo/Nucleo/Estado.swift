import SwiftUI
import Observation

/// Lo único que leen las pantallas. Aplica cada acción en memoria al instante, le avisa a `datos` y, si el
/// servidor dice que no, vuelve atrás y muestra por qué.
@Observable @MainActor
final class Estado {
    let datos: Datos
    var panel: Panel

    // Carga y conexión
    var cargando = false
    var conectado = true
    var ultimaCarga: Date?

    // Navegación
    var pestana: Pestana = .inicio
    var rutas: [Pestana: [Ruta]] = [:]
    var cubierta: Modal?
    var hoja: Modal?

    // Capas
    var aviso: Aviso?
    var faceID: FaceIDPaso?

    /// Saldo a la vista u oculto (el ojo del inicio). Se recuerda.
    var saldoVisible: Bool {
        didSet { UserDefaults.standard.set(saldoVisible, forKey: "saldoVisible") }
    }
    /// Face ID para entrar y pagar.
    var faceIDActivo: Bool {
        didSet { UserDefaults.standard.set(faceIDActivo, forKey: "faceIDActivo") }
    }
    /// «Espera para cuentas nuevas»: las primeras 24 h, hasta $ 100.000 por transferencia.
    var esperaCuentasNuevas: Bool {
        didSet { UserDefaults.standard.set(esperaCuentasNuevas, forKey: "esperaCuentasNuevas") }
    }

    init(datos: Datos? = nil, panel: Panel? = nil) {
        let cuentaNueva = UserDefaults.standard.bool(forKey: "cuentaNueva")
        self.datos = datos ?? DatosDeMuestra(cuentaNueva: cuentaNueva)
        self.panel = panel ?? (cuentaNueva ? DatosDeMuestra.panelNuevo() : DatosDeMuestra.panelCompleto())
        let d = UserDefaults.standard
        saldoVisible = d.object(forKey: "saldoVisible") as? Bool ?? true
        faceIDActivo = d.object(forKey: "faceIDActivo") as? Bool ?? true
        esperaCuentasNuevas = d.object(forKey: "esperaCuentasNuevas") as? Bool ?? true
    }

    // MARK: - Lecturas

    var usuario: Usuario { panel.usuario }
    func saldo(_ b: Bolsillo) -> Centavos { panel.saldos[b, default: 0] }
    var saldoTotal: Centavos { saldo(.negocio) + saldo(.personal) }
    var totalApartado: Centavos { panel.apartados.reduce(0) { $0 + $1.actual } }
    var cuentaNueva: Bool { panel.movimientos.isEmpty && saldoTotal == 0 }
    var sinLeer: Int { panel.notificaciones.filter { !$0.leida }.count }
    var tarjetaVirtual: Tarjeta? { panel.tarjetas.first { $0.tipo == .virtual } }
    var tarjetaFisica: Tarjeta? { panel.tarjetas.first { $0.tipo == .fisica } }
    var favoritos: [Contacto] { panel.contactos.filter(\.favorito) }

    func movimiento(_ id: String) -> Movimiento? { panel.movimientos.first { $0.id == id } }
    func apartado(_ id: String) -> Apartado? { panel.apartados.first { $0.id == id } }

    var movimientosDeHoy: [Movimiento] {
        panel.movimientos.filter { Fecha.calendario.isDateInToday($0.fecha) }
    }
    /// Lo que entró hoy al bolsillo Negocio (cobros).
    var cobradoHoy: Centavos {
        movimientosDeHoy.filter { $0.bolsillo == .negocio && $0.tipo.esEntrada }.reduce(0) { $0 + $1.centavos }
    }
    /// Los movimientos agrupados por día, del más nuevo al más viejo.
    func porDia(_ lista: [Movimiento]) -> [(dia: Date, movimientos: [Movimiento])] {
        let g = Dictionary(grouping: lista) { Fecha.calendario.startOfDay(for: $0.fecha) }
        return g.keys.sorted(by: >).map { ($0, g[$0]!.sorted { $0.fecha > $1.fecha }) }
    }

    // MARK: - Carga

    func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            panel = try await datos.panel()
            conectado = true
            ultimaCarga = .now
        } catch {
            conectado = false
        }
    }

    // MARK: - Navegación

    func ir(_ r: Ruta) {
        rutas[pestana, default: []].append(r)
    }

    func ir(_ r: Ruta, en p: Pestana) {
        cubierta = nil
        hoja = nil
        pestana = p
        rutas[p] = [r]
    }

    func volverAlInicio(_ p: Pestana) {
        rutas[p] = []
    }

    /// Abre un flujo. Si ya hay uno arriba, lo cierra primero.
    func abrir(_ m: Modal) {
        Haptico.tocar()
        if cubierta != nil || hoja != nil {
            cubierta = nil
            hoja = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                self.mostrar(m)
            }
        } else {
            mostrar(m)
        }
    }

    private func mostrar(_ m: Modal) {
        if m.esHoja { hoja = m } else { cubierta = m }
    }

    func cerrarModales() {
        cubierta = nil
        hoja = nil
    }

    func avisar(_ texto: String, tipo: Aviso.Tipo = .ok) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { aviso = Aviso(texto: texto, tipo: tipo) }
        if tipo == .error { Haptico.error() } else { Haptico.exito() }
        let id = aviso?.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if self.aviso?.id == id { withAnimation(.easeOut(duration: 0.25)) { self.aviso = nil } }
        }
    }

    // MARK: - Face ID simulado

    /// Muestra el escaneo de Face ID y devuelve si pasó. Si está apagado en Seguridad, pasa directo.
    func pedirFaceID(_ motivo: String) async -> Bool {
        guard faceIDActivo else { return true }
        withAnimation(.easeOut(duration: 0.2)) { faceID = FaceIDPaso(motivo: motivo, fase: .escaneando) }
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { faceID?.fase = .listo }
        Haptico.exito()
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeIn(duration: 0.2)) { faceID = nil }
        return true
    }

    // MARK: - Acciones (todas pasan por acá)

    private func recargarSaldos() async {
        if let p = try? await datos.panel() { panel = p }
    }

    func buscarDestino(_ texto: String) async throws -> Contacto {
        try await conRed { try await self.datos.buscarDestino(texto) }
    }

    func transferir(a c: Contacto, centavos: Centavos, desde b: Bolsillo, motivo: String) async throws -> Movimiento {
        let m = try await conRed { try await self.datos.transferir(a: c, centavos: centavos, desde: b, motivo: motivo) }
        await recargarSaldos()
        return m
    }

    func pagar(_ comercio: Comercio, centavos: Centavos, desde b: Bolsillo) async throws -> Movimiento {
        let m = try await conRed { try await self.datos.pagar(comercio, centavos: centavos, desde: b) }
        await recargarSaldos()
        return m
    }

    func pasar(_ centavos: Centavos, de b: Bolsillo) async throws -> Movimiento {
        let m = try await conRed { try await self.datos.pasar(centavos, de: b) }
        await recargarSaldos()
        return m
    }

    func crearLink(concepto: String, centavos: Centavos?) async throws -> LinkDePago {
        let l = try await conRed { try await self.datos.crearLink(concepto: concepto, centavos: centavos) }
        await recargarSaldos()
        return l
    }

    func cobrarConTarjeta(_ centavos: Centavos, concepto: String) async throws -> Movimiento {
        let m = try await conRed { try await self.datos.cobrarConTarjeta(centavos, concepto: concepto) }
        await recargarSaldos()
        return m
    }

    func guardarApartado(_ a: Apartado) async throws {
        if let i = panel.apartados.firstIndex(where: { $0.id == a.id }) { panel.apartados[i] = a } else { panel.apartados.append(a) }
        try await conRed { try await self.datos.guardarApartado(a) }
        await recargarSaldos()
    }

    func borrarApartado(_ id: String) async throws {
        try await conRed { try await self.datos.borrarApartado(id: id) }
        await recargarSaldos()
    }

    func mover(_ centavos: Centavos, apartado id: String) async throws -> Movimiento {
        let m = try await conRed { try await self.datos.mover(centavos, apartado: id) }
        await recargarSaldos()
        return m
    }

    /// Cambia la tarjeta al toque (congelar, límites, compras afuera) y la guarda; si falla, vuelve atrás.
    func guardarTarjeta(_ t: Tarjeta) async {
        guard let i = panel.tarjetas.firstIndex(where: { $0.id == t.id }) else { return }
        let antes = panel.tarjetas[i]
        panel.tarjetas[i] = t
        do { try await conRed { try await self.datos.guardarTarjeta(t) } } catch {
            panel.tarjetas[i] = antes
            avisar(mensaje(error), tipo: .error)
        }
    }

    func pedirFisica(diseno: DisenoTarjeta, direccion: String) async throws -> Tarjeta {
        let t = try await conRed { try await self.datos.pedirFisica(diseno: diseno, direccion: direccion) }
        await recargarSaldos()
        return t
    }

    func alternarFavorito(_ c: Contacto) async {
        var c = c
        c.favorito.toggle()
        if let i = panel.contactos.firstIndex(where: { $0.id == c.id }) { panel.contactos[i] = c }
        try? await datos.guardarContacto(c)
    }

    func marcarPaso(_ p: PasoArranque) async {
        panel.pasosHechos.insert(p)
        try? await datos.marcarPaso(p)
    }

    func leerNotificaciones() {
        for i in panel.notificaciones.indices { panel.notificaciones[i].leida = true }
    }

    // MARK: - Modo de prueba (Perfil › Probar estados)

    func simularSinConexion(_ v: Bool) async {
        if let d = datos as? DatosDeMuestra { await d.ponerSinConexion(v) }
        conectado = !v
    }

    func mensaje(_ e: Error) -> String {
        (e as? ErrorCuarzo)?.errorDescription ?? "Algo no salió. Tu plata está a salvo; probá de nuevo."
    }

    private func conRed<T>(_ f: @escaping () async throws -> T) async throws -> T {
        do {
            let r = try await f()
            conectado = true
            return r
        } catch ErrorCuarzo.sinConexion {
            conectado = false
            throw ErrorCuarzo.sinConexion
        }
    }
}

struct Aviso: Identifiable, Equatable {
    enum Tipo { case ok, info, error }
    let id = UUID()
    var texto: String
    var tipo: Tipo
}

struct FaceIDPaso: Equatable {
    enum Fase { case escaneando, listo }
    var motivo: String
    var fase: Fase
}

enum Haptico {
    static func tocar() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7) }
    static func firme() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func exito() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func aviso() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func seleccion() { UISelectionFeedbackGenerator().selectionChanged() }
}
