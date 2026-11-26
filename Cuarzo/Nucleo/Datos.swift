import Foundation

/// Lo que la app le pide al servidor. Hoy lo cumple `DatosDeMuestra` (en memoria); para conectar el backend del
/// PSP socio alcanza con otra implementación (`DatosApi`) y pasarla al crear `Estado(datos:)`.
/// Regla: nada de `async let` (cierra la app en Release); las llamadas van una detrás de otra.
protocol Datos: AnyObject, Sendable {
    /// Todo lo que se dibuja: usuario, saldos, movimientos, apartados, tarjetas, negocio.
    func panel() async throws -> Panel

    /// Busca a quién transferir por CVU (22 dígitos) o alias (6 a 20 caracteres con puntos).
    func buscarDestino(_ cvuOAlias: String) async throws -> Contacto
    func transferir(a destino: Contacto, centavos: Centavos, desde: Bolsillo, motivo: String) async throws -> Movimiento
    func pagar(_ comercio: Comercio, centavos: Centavos, desde: Bolsillo) async throws -> Movimiento
    func pasar(_ centavos: Centavos, de origen: Bolsillo) async throws -> Movimiento

    func crearLink(concepto: String, centavos: Centavos?) async throws -> LinkDePago
    /// Tocar para cobrar: el celular lee la tarjeta del cliente.
    func cobrarConTarjeta(_ centavos: Centavos, concepto: String) async throws -> Movimiento

    func guardarApartado(_ apartado: Apartado) async throws
    func borrarApartado(id: String) async throws
    /// Positivo: guarda en el apartado. Negativo: lo devuelve al bolsillo.
    func mover(_ centavos: Centavos, apartado id: String) async throws -> Movimiento

    func guardarTarjeta(_ tarjeta: Tarjeta) async throws
    func pedirFisica(diseno: DisenoTarjeta, direccion: String) async throws -> Tarjeta

    func guardarContacto(_ contacto: Contacto) async throws
    func marcarPaso(_ paso: PasoArranque) async throws
}
