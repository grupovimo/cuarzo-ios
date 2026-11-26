import SwiftUI
import UIKit

enum Pestana: String, CaseIterable, Hashable {
    case inicio, movimientos, tarjeta, perfil
    var nombre: String {
        switch self {
        case .inicio: return "Inicio"
        case .movimientos: return "Movimientos"
        case .tarjeta: return "Tarjeta"
        case .perfil: return "Perfil"
        }
    }
    var simbolo: String {
        switch self {
        case .inicio: return "house"
        case .movimientos: return "list.bullet"
        case .tarjeta: return "creditcard"
        case .perfil: return "person"
        }
    }
}

/// Pantallas que se apilan dentro de una pestaña.
enum Ruta: Hashable {
    case movimiento(String)
    case notificaciones
    case rendimiento
    case apartados
    case apartado(String)
    case negocios
    case ventas
    case links
    case liquidaciones
    case limitesTarjeta
    case seguridad
    case limitesTransferencia
    case dispositivos
    case datosCuenta
    case ayuda
    case apariencia
    case probarEstados
}

/// Flujos que tapan la app (o suben como hoja).
enum Modal: Identifiable, Hashable {
    case cobrar(ModoCobro)
    case pagar
    case transferir(Contacto?)
    case pasar(Bolsillo)
    case ingresar
    case comprobante(String, celebrar: Bool)
    case frenada(Frenada)
    case nuevoApartado
    case moverApartado(String, guardar: Bool)
    case pedirFisica
    case tocarParaCobrar
    case chat

    var id: String {
        switch self {
        case .cobrar(let m): return "cobrar-\(m)"
        case .pagar: return "pagar"
        case .transferir(let c): return "transferir-\(c?.id ?? "")"
        case .pasar(let b): return "pasar-\(b.rawValue)"
        case .ingresar: return "ingresar"
        case .comprobante(let id, _): return "comprobante-\(id)"
        case .frenada(let f): return "frenada-\(f.id)"
        case .nuevoApartado: return "nuevoApartado"
        case .moverApartado(let id, let g): return "mover-\(id)-\(g)"
        case .pedirFisica: return "pedirFisica"
        case .tocarParaCobrar: return "tocar"
        case .chat: return "chat"
        }
    }

    /// Las chicas suben como hoja; los flujos con pasos tapan todo.
    var esHoja: Bool {
        switch self {
        case .pasar, .ingresar, .moverApartado: return true
        default: return false
        }
    }
}

enum ModoCobro: String, Hashable { case qr, link }

/// Qué vista corresponde a cada ruta.
struct DestinoRuta: View {
    let ruta: Ruta
    var body: some View {
        Group {
            switch ruta {
            case .movimiento(let id): DetalleMovimiento(id: id)
            case .notificaciones: NotificacionesPantalla()
            case .rendimiento: RendimientoPantalla()
            case .apartados: ApartadosPantalla()
            case .apartado(let id): DetalleApartado(id: id)
            case .negocios: NegociosPantalla()
            case .ventas: VentasPantalla()
            case .links: LinksPantalla()
            case .liquidaciones: LiquidacionesPantalla()
            case .limitesTarjeta: LimitesTarjetaPantalla()
            case .seguridad: SeguridadPantalla()
            case .limitesTransferencia: LimitesTransferenciaPantalla()
            case .dispositivos: DispositivosPantalla()
            case .datosCuenta: DatosCuentaPantalla()
            case .ayuda: AyudaPantalla()
            case .apariencia: AparienciaPantalla()
            case .probarEstados: ProbarEstadosPantalla()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Qué vista corresponde a cada flujo.
struct DestinoModal: View {
    let modal: Modal
    var body: some View {
        Group {
            switch modal {
            case .cobrar(let m): CobrarPantalla(modo: m)
            case .pagar: PagarFlujo()
            case .transferir(let c): TransferirFlujo(destino: c)
            case .pasar(let b): PasarPantalla(desde: b)
            case .ingresar: IngresarPlataPantalla()
            case .comprobante(let id, let c): ComprobanteVista(movimientoID: id, celebrar: c)
            case .frenada(let f): FrenadaPantalla(frenada: f)
            case .nuevoApartado: NuevoApartadoFlujo()
            case .moverApartado(let id, let g): MoverApartadoPantalla(id: id, guardar: g)
            case .pedirFisica: PedirTarjetaFlujo()
            case .tocarParaCobrar: TocarParaCobrarFlujo()
            case .chat: ChatPantalla()
            }
        }
        .capas()
    }
}

/// Pila de una pestaña con su propia navegación.
struct PilaPestana<Raiz: View>: View {
    let pestana: Pestana
    @ViewBuilder let raiz: () -> Raiz
    @Environment(Estado.self) private var estado

    var body: some View {
        @Bindable var e = estado
        NavigationStack(path: Binding(get: { e.rutas[pestana] ?? [] }, set: { e.rutas[pestana] = $0 })) {
            raiz()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Ruta.self) { DestinoRuta(ruta: $0) }
        }
    }
}

/// La barra de pestañas del diseño: cuatro pestañas y el botón de Cobrar en el centro, más alto.
struct BarraPestanas: View {
    @Environment(Estado.self) private var estado
    @Namespace private var ns

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            boton(.inicio)
            boton(.movimientos)
            cobrar
            boton(.tarjeta)
            boton(.perfil)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .frame(height: 58, alignment: .top)
        .background(alignment: .top) {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color.velo)
                .overlay(alignment: .top) { Rectangle().fill(Color.linea).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func boton(_ p: Pestana) -> some View {
        let on = estado.pestana == p
        return Button {
            if on { withAnimation { estado.volverAlInicio(p) } } else { Haptico.seleccion() }
            estado.pestana = p
        } label: {
            VStack(spacing: 4) {
                Image(systemName: on ? p.simbolo + (p == .movimientos ? "" : ".fill") : p.simbolo)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(on ? Color.acento : Color.ter)
                    .frame(height: 26)
                    .symbolEffect(.bounce, value: on)
                Text(p.nombre)
                    .font(.geistFijo(11, .medio))
                    .foregroundStyle(on ? Color.texto : Color.ter)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.nombre)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var cobrar: some View {
        Button { estado.abrir(.cobrar(.qr)) } label: {
            VStack(spacing: 4) {
                Image(systemName: "qrcode")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.noche)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(LinearGradient.botonRosa))
                    .shadow(color: .rosa.opacity(0.55), radius: 12, y: 6)
                    .background(Circle().fill(Color.fondo).padding(-5))
                Text("Cobrar")
                    .font(.geistFijo(11, .medio))
                    .foregroundStyle(Color.texto)
            }
            .offset(y: -24)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(Presionable())
        .accessibilityLabel("Cobrar")
    }
}

/// Con la barra de navegación oculta, el gesto de volver deslizando desde el borde sigue andando.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
