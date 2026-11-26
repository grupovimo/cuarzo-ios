# Cuarzo · iOS

Maqueta navegable de alta fidelidad de Cuarzo, la billetera de Grupo Vimo para el que labura y cobra (SwiftUI, iOS 17+, sólo iPhone y vertical, oscuro primero y claro). No tiene backend: todo corre en memoria con los datos de las pantallas (`propuestas/billetera/pantallas`) y la marca (`propuestas/billetera/marca`). Va a TestFlight sólo al grupo interno «Equipo».

## Generar y compilar

```sh
brew install xcodegen          # una vez
xcodegen generate              # crea Cuarzo.xcodeproj (no se versiona)
xcodebuild -project Cuarzo.xcodeproj -scheme Cuarzo -derivedDataPath build/dd \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```

Tests de humo (abren cada pantalla en oscuro y en claro): `test` con un simulador como destino. En Release: sumá `-configuration Release ENABLE_TESTABILITY=YES`. Para cuidar el Xcode 26.3 de GitHub, compilá con `OTHER_SWIFT_FLAGS='-Xfrontend -warn-long-expression-type-checking=1000'` y partí todo lo que pase de un segundo.

Capturas: `./capturar.sh` (o `./capturar.sh inicio tarjeta.claro`). Lee `pantallas.txt` y deja todo en `capturas/`. En esta Mac, antes de usar el simulador: `until mkdir ~/Trabajo/vimo/.sim-lock 2>/dev/null; do sleep 10; done` y al final `rmdir ~/Trabajo/vimo/.sim-lock`. Sólo el simulador «Prueba Corredor».

Para abrir una pantalla directo: argumento de arranque `-pantalla <nombre>` (ver `Arranque` en `App/CuarzoApp.swift`), `-paso N` para el onboarding y el alta, `-cuentaNueva YES`, `-sinConexion YES` y `-oscuro NO`.

## Estructura

- `Cuarzo/App`: entrada, raíz (onboarding → alta → bloqueo con Face ID → app), pestañas con el botón de Cobrar al centro, rutas y flujos (`Navegacion.swift`).
- `Cuarzo/Tema`: colores del manual (noche ciruela, rosa cuarzo, nácar y tinta) que cambian en claro, y tipografía (Geist y Geist Mono, títulos con renglones balanceados).
- `Cuarzo/Componentes`: vidrio, botones, montos, teclado, QR real con la C, cristal de éxito, ticket y papel del comprobante, Face ID simulado, avisos, vacíos y errores.
- `Cuarzo/Nucleo`: modelos, el protocolo `Datos`, `DatosDeMuestra` (actor en memoria que simula red, errores y frenadas) y `Estado` (`@Observable`), lo único que leen las pantallas.
- `Cuarzo/Pantallas`: Entrada, Plata (inicio, movimientos, cobrar, pagar, transferir, comprobante), Tarjeta, Apartados, Negocios y Perfil.

## Conectar datos reales

1. Escribí otra implementación de `Datos` (`Nucleo/Datos.swift`), por ejemplo `DatosApi` contra el PSP socio. Devuelve un `Panel` y hace cada operación (transferir, pagar, pasar, links, tocar para cobrar, apartados, tarjetas).
2. Pasala al crear el estado: en `CuarzoApp`, `Estado(datos: DatosApi())`.

Las pantallas no cambian. La plata va siempre en centavos (`Int`). Regla: nunca uses `async let`, porque cierra la app en Release; las llamadas van una detrás de otra.

## TestFlight

`.github/workflows/testflight.yml` (a mano: `gh workflow run testflight -R grupovimo/cuarzo-ios`) compila, corre los tests, firma con el perfil `ar.com.cuarzo.app App Store` (equipo M6935MSNQB, certificado 6G78MCHSKK) y sube con número de build AAMMDDhhmm. Necesita los secretos `ASC_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `DIST_P12`, `DIST_P12_CLAVE` y `PERFIL_APP`. Sólo grupo interno «Equipo»: nunca Socios ni externos.
