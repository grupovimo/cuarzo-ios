import SwiftUI
import XCTest
@testable import Cuarzo

/// Humo: monta cada pantalla con DatosDeMuestra en una ventana de verdad y la dibuja, en oscuro y en claro.
/// Si algo se cae al abrirla (como el `async let` que cerraba Tu Local Web en Release), salta acá.
/// Corre también en Release: `xcodebuild test -configuration Release ENABLE_TESTABILITY=YES …`.
@MainActor
final class PantallasTests: XCTestCase {
    private var ventana: UIWindow?

    override func tearDown() {
        ventana?.isHidden = true
        ventana = nil
    }

    private func estadoDeMuestra(nueva: Bool = false) -> Estado {
        Estado(datos: DatosDeMuestra(cuentaNueva: nueva, demora: 0),
               panel: nueva ? DatosDeMuestra.panelNuevo() : DatosDeMuestra.panelCompleto())
    }

    func montar<V: View>(_ vista: V, nueva: Bool = false, segundos: Double = 0.35, file: StaticString = #filePath, line: UInt = #line) {
        for oscuro in [true, false] {
            let raiz = vista.environment(estadoDeMuestra(nueva: nueva)).preferredColorScheme(oscuro ? .dark : .light)
            let escena = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let v = escena.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
            let host = UIHostingController(rootView: raiz)
            v.rootViewController = host
            v.makeKeyAndVisible()
            ventana = v
            RunLoop.main.run(until: Date().addingTimeInterval(segundos))
            host.view.layoutIfNeeded()
            XCTAssertGreaterThan(host.view.bounds.width, 0, file: file, line: line)
            XCTAssertNotNil(ImageRenderer(content: raiz.frame(width: 375, height: 812)).uiImage, file: file, line: line)
            v.isHidden = true
        }
    }

    // MARK: - Base

    func testFuentes() {
        for n in ["Geist-Regular", "Geist-Medium", "Geist-SemiBold", "GeistMono-Medium"] {
            XCTAssertNotNil(UIFont(name: n, size: 15), n)
        }
    }

    func testImagenes() {
        for n in ["horizontal-noche", "horizontal-claro", "simbolo-vidrio", "simbolo-noche", "tarjeta-vidrio-frente", "tarjeta-virtual-frente",
                  "ic-llaves", "ic-frasco", "ic-escudo", "ic-calendario", "ic-qr", "ic-monedas", "cristal-a", "selfie", "camara-qr-v"] {
            XCTAssertNotNil(UIImage(named: n), n)
        }
    }

    func testFormato() {
        XCTAssertEqual(Formato.plata(105_563_050), "$\u{00A0}1.055.630,50")
        XCTAssertEqual(Formato.plata(1_500_000), "$\u{00A0}15.000")
        XCTAssertEqual(Formato.plata(1_500_000, centavos: true), "$\u{00A0}15.000,00")
        XCTAssertEqual(Formato.conSigno(-480_000), "−\u{00A0}$\u{00A0}4.800")
        XCTAssertEqual(Formato.centavos(deTexto: "25000"), 2_500_000)
        XCTAssertEqual(Formato.centavos(deTexto: "1500,5"), 150_050)
        XCTAssertEqual(Formato.iniciales("Martina Ríos"), "MR")
    }

    func testTeclado() {
        var e = EntradaMonto()
        for t: TeclaMonto in [.digito(2), .digito(5), .digito(0), .digito(0), .digito(0)] { e.tocar(t) }
        XCTAssertEqual(e.visible, "25.000")
        XCTAssertEqual(e.centavos, 2_500_000)
        XCTAssertTrue(e.tocar(.coma))
        XCTAssertFalse(e.tocar(.coma))
        e.tocar(.digito(5)); e.tocar(.digito(0))
        XCTAssertFalse(e.tocar(.digito(1)))
        XCTAssertEqual(e.centavos, 2_500_050)
        e.tocar(.borrar); e.tocar(.borrar); e.tocar(.borrar)
        XCTAssertEqual(e.centavos, 2_500_000)
    }

    func testSaldosDeMuestra() {
        let p = DatosDeMuestra.panelCompleto()
        XCTAssertEqual(p.saldos[.negocio]! + p.saldos[.personal]!, 105_563_050)
        XCTAssertEqual(p.apartados.reduce(0) { $0 + $1.actual }, 60_639_000)
    }

    func testTransferirYFrenar() async throws {
        let d = DatosDeMuestra(demora: 0)
        let martina = DatosDeMuestra.contactos[0]
        let m = try await d.transferir(a: martina, centavos: 2_500_000, desde: .negocio, motivo: "Varios")
        XCTAssertEqual(m.centavos, -2_500_000)
        let p = try await d.panel()
        XCTAssertEqual(p.saldos[.negocio], 84_215_000 - 2_500_000)
        do {
            _ = try await d.transferir(a: martina, centavos: 99_000_000_00, desde: .personal, motivo: "")
            XCTFail("tenía que faltar saldo")
        } catch let e as ErrorCuarzo { XCTAssertEqual(e, .sinSaldo) }
        do {
            _ = try await d.buscarDestino("no.existe")
            XCTFail("no tenía que encontrarlo")
        } catch let e as ErrorCuarzo { XCTAssertEqual(e, .destinoNoEncontrado) }
        let otro = try await d.buscarDestino("0110599520000099999999")
        XCTAssertFalse(otro.esCuarzo)
    }

    // MARK: - Raíz y componentes

    func testRaizConPestanas() { montar(AppPrincipal()) }
    func testRaizCuentaNueva() { montar(AppPrincipal(), nueva: true) }
    func testBarra() { montar(VStack { Spacer(); BarraPestanas() }) }
    func testComponentes() {
        montar(ScrollView {
            VStack(spacing: 12) {
                Monto(centavos: 105_563_050)
                Monto(centavos: 105_563_050, oculto: true)
                MontoChico(centavos: 84_215_000)
                QRCuarzo(contenido: "https://cuarzo.ar/p/prueba")
                CristalExito(animar: false)
                TecladoNumerico(entrada: .constant(EntradaMonto(texto: "25000")))
                MontoTipeado(entrada: EntradaMonto(texto: "25000"))
                Vacio(titulo: "Todavía no hay nada", texto: "Cuando te entre plata la vas a ver acá.", accion: "Ingresar plata") {}
                ErrorVista {}
                Titulo("Lo del laburo, aparte.", tamano: 36)
                Etiqueta(texto: "Cuenta Cuarzo", simbolo: "bolt")
                LeyendaPSP()
                CapaFaceID(paso: FaceIDPaso(motivo: "Para pagar", fase: .escaneando))
            }
        })
    }

    // MARK: - Entrada

    func testOnboarding() { for i in 0..<3 { montar(Onboarding(paso: i) { _ in }, segundos: 0.2) } }
    func testAlta() { for i in 0..<6 { montar(Alta(paso: i, alVolver: {}, alTerminar: {}), segundos: 0.2) } }
    func testBloqueo() { montar(Bloqueo {}) }

    // MARK: - Plata

    func testInicio() { montar(InicioPantalla()) }
    func testInicioNueva() { montar(InicioPantalla(), nueva: true) }
    func testMovimientos() { montar(MovimientosPantalla()) }
    func testMovimientosVacios() { montar(MovimientosPantalla(), nueva: true) }
    func testDetalleMovimiento() { montar(DetalleMovimiento(id: DatosDeMuestra.movimientos()[0].id)) }
    func testCobrarQR() { montar(CobrarPantalla(modo: .qr)) }
    func testCobrarLink() { montar(CobrarPantalla(modo: .link)) }
    func testPagar() { montar(PagarFlujo()) }
    func testTransferir() { montar(TransferirFlujo(destino: nil)) }
    func testTransferirAMartina() { montar(TransferirFlujo(destino: DatosDeMuestra.contactos[0])) }
    func testPasar() { montar(PasarPantalla(desde: .negocio)) }
    func testIngresar() { montar(IngresarPlataPantalla()) }
    func testComprobante() { montar(ComprobanteVista(movimientoID: DatosDeMuestra.movimientos()[0].id, celebrar: true)) }
    func testComprobanteInexistente() { montar(ComprobanteVista(movimientoID: "no-existe")) }

    // MARK: - Tarjeta, apartados y negocio

    func testTarjeta() { montar(TarjetaPantalla()) }
    func testLimitesTarjeta() { montar(LimitesTarjetaPantalla()) }
    func testPedirTarjeta() { montar(PedirTarjetaFlujo()) }
    func testApartados() { montar(ApartadosPantalla()) }
    func testApartadosVacios() { montar(ApartadosPantalla(), nueva: true) }
    func testDetalleApartado() { montar(DetalleApartado(id: "a-alquiler")) }
    func testNuevoApartado() { montar(NuevoApartadoFlujo()) }
    func testMoverApartado() { montar(MoverApartadoPantalla(id: "a-alquiler", guardar: true)) }
    func testNegocios() { montar(NegociosPantalla()) }
    func testNegociosVacio() { montar(NegociosPantalla(), nueva: true) }
    func testVentas() { montar(VentasPantalla()) }
    func testLinks() { montar(LinksPantalla()) }
    func testLiquidaciones() { montar(LiquidacionesPantalla()) }
    func testTocarParaCobrar() { montar(TocarParaCobrarFlujo()) }
    func testRendimiento() { montar(RendimientoPantalla()) }

    // MARK: - Perfil y estados

    func testPerfil() { montar(PerfilPantalla()) }
    func testSeguridad() { montar(SeguridadPantalla()) }
    func testLimitesTransferencia() { montar(LimitesTransferenciaPantalla()) }
    func testDispositivos() { montar(DispositivosPantalla()) }
    func testDatosCuenta() { montar(DatosCuentaPantalla()) }
    func testAyuda() { montar(AyudaPantalla()) }
    func testChat() { montar(ChatPantalla()) }
    func testApariencia() { montar(AparienciaPantalla()) }
    func testProbarEstados() { montar(ProbarEstadosPantalla()) }
    func testNotificaciones() { montar(NotificacionesPantalla()) }
    func testFrenada() { montar(FrenadaPantalla(frenada: DatosDeMuestra.frenada)) }

    /// Todas las rutas y los flujos se pueden construir (si se suma un caso y no tiene vista, no compila).
    func testDestinos() {
        let rutas: [Ruta] = [.movimiento("x"), .notificaciones, .rendimiento, .apartados, .apartado("a-alquiler"), .negocios, .ventas,
                             .links, .liquidaciones, .limitesTarjeta, .seguridad, .limitesTransferencia, .dispositivos, .datosCuenta,
                             .ayuda, .apariencia, .probarEstados]
        montar(ScrollView { VStack { ForEach(rutas, id: \.self) { DestinoRuta(ruta: $0).frame(height: 300) } } }, segundos: 0.6)
    }
}
