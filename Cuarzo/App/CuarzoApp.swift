import SwiftUI

@main
struct CuarzoApp: App {
    @State private var estado: Estado
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue

    init() {
        let d = UserDefaults.standard
        // Con `-pantalla x` (capturas y pruebas) se abre directo esa pantalla, con la cuenta de muestra.
        if let p = Arranque.pantalla {
            d.set(p == "onboarding" ? "onboarding" : p == "alta" ? "alta" : "lista", forKey: "fase")
            d.set(Arranque.cuentaNueva, forKey: "cuentaNueva")
            d.set(Arranque.oscuro ? Apariencia.oscuro.rawValue : Apariencia.claro.rawValue, forKey: "apariencia")
            d.set(true, forKey: "saldoVisible")
            d.set(true, forKey: "tourVisto")
        }
        _estado = State(initialValue: Estado())
    }

    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(estado)
                .preferredColorScheme(Apariencia(rawValue: apariencia)?.esquema)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .tint(Color.acento)
                .task {
                    if Arranque.sinConexion { await estado.simularSinConexion(true) }
                    await estado.cargar()
                }
        }
    }
}

/// Oscuro primero (es la cara de la marca); claro o lo que diga el teléfono, a elección.
enum Apariencia: String, CaseIterable, Identifiable {
    case oscuro, claro, sistema
    var id: String { rawValue }
    var titulo: String { self == .sistema ? "Automático" : self == .claro ? "Claro" : "Oscuro" }
    var esquema: ColorScheme? { self == .sistema ? nil : self == .claro ? .light : .dark }
}

/// En qué parte de la vida de la cuenta está la persona.
enum Fase: String { case onboarding, alta, lista }

struct Raiz: View {
    @Environment(Estado.self) private var estado
    @Environment(\.scenePhase) private var escena
    @AppStorage("fase") private var faseGuardada = Fase.onboarding.rawValue
    @State private var bloqueada: Bool
    @State private var tapar = false

    init() {
        let fase = Fase(rawValue: UserDefaults.standard.string(forKey: "fase") ?? "") ?? .onboarding
        let p = Arranque.pantalla
        _bloqueada = State(initialValue: fase == .lista && (p == nil || p == "bloqueo"))
    }

    private var fase: Fase { Fase(rawValue: faseGuardada) ?? .onboarding }

    var body: some View {
        ZStack {
            switch fase {
            case .onboarding:
                Onboarding(paso: Arranque.paso) { yaTengo in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if yaTengo { bloqueada = true; faseGuardada = Fase.lista.rawValue } else { faseGuardada = Fase.alta.rawValue }
                    }
                }
                .transition(.opacity)
            case .alta:
                Alta(paso: Arranque.pantalla == "alta" ? Arranque.paso : 0, alVolver: {
                    withAnimation(.easeInOut(duration: 0.4)) { faseGuardada = Fase.onboarding.rawValue }
                }) {
                    UserDefaults.standard.set(true, forKey: "cuentaNueva")
                    withAnimation(.easeInOut(duration: 0.5)) { faseGuardada = Fase.lista.rawValue }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .lista:
                AppPrincipal()
                    .transition(.opacity)
            }
            if bloqueada && fase == .lista {
                Bloqueo {
                    withAnimation(.easeInOut(duration: 0.35)) { bloqueada = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(10)
            }
            // Al pasar a segundo plano se tapa el saldo (multitarea) y al volver se pide Face ID.
            if tapar {
                ZStack {
                    Color.fondo.ignoresSafeArea()
                    Image("simbolo-vidrio").resizable().scaledToFit().frame(width: 96)
                }
                .zIndex(20)
            }
        }
        .capas()
        .onChange(of: escena) { _, nueva in
            switch nueva {
            case .background:
                if fase == .lista && estado.faceIDActivo && Arranque.pantalla == nil { bloqueada = true }
            case .inactive:
                if fase == .lista { tapar = true }
            case .active:
                tapar = false
            @unknown default:
                break
            }
        }
    }
}

/// La app con sus cuatro pestañas, el botón de Cobrar y los flujos.
struct AppPrincipal: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        @Bindable var e = estado
        ZStack(alignment: .bottom) {
            ZStack {
                PilaPestana(pestana: .inicio) { InicioPantalla() }
                    .opacity(estado.pestana == .inicio ? 1 : 0)
                    .allowsHitTesting(estado.pestana == .inicio)
                PilaPestana(pestana: .movimientos) { MovimientosPantalla() }
                    .opacity(estado.pestana == .movimientos ? 1 : 0)
                    .allowsHitTesting(estado.pestana == .movimientos)
                PilaPestana(pestana: .tarjeta) { TarjetaPantalla() }
                    .opacity(estado.pestana == .tarjeta ? 1 : 0)
                    .allowsHitTesting(estado.pestana == .tarjeta)
                PilaPestana(pestana: .perfil) { PerfilPantalla() }
                    .opacity(estado.pestana == .perfil ? 1 : 0)
                    .allowsHitTesting(estado.pestana == .perfil)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if (estado.rutas[estado.pestana] ?? []).isEmpty {
                    BarraPestanas().transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: (estado.rutas[estado.pestana] ?? []).isEmpty)
        }
        .fullScreenCover(item: $e.cubierta) { DestinoModal(modal: $0).environment(estado) }
        .sheet(item: $e.hoja) { m in
            DestinoModal(modal: m)
                .environment(estado)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.fondo)
        }
        .task { Arranque.abrir(en: estado) }
    }
}

/// Qué pantalla abrir al arrancar (`-pantalla cobrar`, `-pantalla onboarding -paso 2`, `-cuentaNueva YES`,
/// `-sinConexion YES`, `-oscuro NO`). Sólo para capturas y pruebas.
enum Arranque {
    static var pantalla: String? {
        let p = UserDefaults.standard.string(forKey: "pantalla")
        return p?.isEmpty == true ? nil : p
    }
    static var paso: Int { UserDefaults.standard.integer(forKey: "paso") }
    static var oscuro: Bool { UserDefaults.standard.object(forKey: "oscuro") as? Bool ?? true }
    static var cuentaNueva: Bool { UserDefaults.standard.bool(forKey: "cuentaNueva") }
    static var sinConexion: Bool { UserDefaults.standard.bool(forKey: "sinConexion") }

    @MainActor
    static func abrir(en e: Estado) {
        guard let p = pantalla else { return }
        let rutas: [String: Ruta] = [
            "apartados": .apartados, "apartado": .apartado("a-alquiler"), "negocios": .negocios, "ventas": .ventas,
            "links": .links, "liquidaciones": .liquidaciones, "rendimiento": .rendimiento, "notificaciones": .notificaciones,
            "movimiento": .movimiento(e.panel.movimientos.first?.id ?? ""),
        ]
        let rutasPerfil: [String: Ruta] = [
            "seguridad": .seguridad, "ayuda": .ayuda, "datos-cuenta": .datosCuenta, "limites-transferencia": .limitesTransferencia,
            "dispositivos": .dispositivos, "apariencia": .apariencia, "probar": .probarEstados,
        ]
        let modales: [String: Modal] = [
            "cobrar": .cobrar(.qr), "cobrar-link": .cobrar(.link), "pagar": .pagar, "transferir": .transferir(nil),
            "transferir-martina": .transferir(DatosDeMuestra.contactos[0]), "pasar": .pasar(.negocio), "ingresar": .ingresar,
            "comprobante": .comprobante(e.panel.movimientos.first?.id ?? "", celebrar: false), "frenada": .frenada(DatosDeMuestra.frenada),
            "nuevo-apartado": .nuevoApartado, "mover-apartado": .moverApartado("a-alquiler", guardar: true), "pedir-fisica": .pedirFisica,
            "tocar": .tocarParaCobrar, "chat": .chat,
        ]
        if let pe = Pestana(rawValue: p) { e.pestana = pe }
        else if p == "limites-tarjeta" { e.pestana = .tarjeta; e.rutas[.tarjeta] = [.limitesTarjeta] }
        else if let r = rutas[p] { e.pestana = .inicio; e.rutas[.inicio] = [r] }
        else if let r = rutasPerfil[p] { e.pestana = .perfil; e.rutas[.perfil] = [r] }
        else if let m = modales[p] { e.abrir(m) }
    }
}
