import SwiftUI

/// Pasar plata entre bolsillos (hoja). Sin Face ID: es entre tus cuentas.
struct PasarPantalla: View {
    var desde: Bolsillo
    /// Monto sugerido (p. ej., lo que falta para pagar).
    var sugerido: Centavos = 0
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var origen: Bolsillo = .negocio
    @State private var entrada = EntradaMonto()
    @State private var giro = 0.0
    @State private var pasando = false
    @State private var error: String?

    private var saldoOrigen: Centavos { estado.saldo(origen) }
    private var alcanza: Bool { entrada.centavos <= saldoOrigen }

    var body: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                Cabecera("Pasar entre bolsillos") { Redondo("xmark", "Cerrar") { dismiss() } }
                direccion.padding(.horizontal, 20).padding(.top, 4)
                MontoTipeado(entrada: entrada, tamano: g.size.height < 640 ? 40 : 48)
                    .padding(.top, 18).padding(.horizontal, 20)
                Text(alcanza ? "Tenés " + Formato.plata(saldoOrigen, centavos: true) + " en " + origen.nombre
                             : "No te alcanza en " + origen.nombre)
                    .font(.geist(13)).foregroundStyle(alcanza ? Color.sec : Color.error)
                    .padding(.top, 6)
                rapidos.padding(.top, 12)
                Spacer(minLength: 6)
                if let error {
                    Text(error).font(.geist(13)).foregroundStyle(Color.error).padding(.bottom, 6)
                }
                TecladoNumerico(entrada: $entrada, alto: g.size.height < 640 ? 42 : 50).padding(.horizontal, 12)
                Button { pasar() } label: {
                    if pasando { ProgressView().tint(Color.noche) } else {
                        Text(entrada.vacio ? "Pasar" : "Pasar " + Formato.plata(entrada.centavos))
                    }
                }
                .buttonStyle(.principal)
                .disabled(entrada.vacio || !alcanza || pasando)
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 10)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(Color.fondo.ignoresSafeArea())
        .onAppear {
            origen = desde
            if sugerido > 0 { entrada = EntradaMonto(centavos: sugerido) }
        }
    }

    private var direccion: some View {
        HStack(spacing: 0) {
            lado(origen, titulo: "De")
            Button {
                Haptico.seleccion()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    origen = origen.otro
                    giro += 180
                }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.noche)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.rosa))
                    .rotationEffect(.degrees(giro))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(Presionable(escala: 0.88))
            .padding(.horizontal, -8)
            .zIndex(1)
            .accessibilityLabel("Invertir: pasar de " + origen.otro.nombre + " a " + origen.nombre)
            lado(origen.otro, titulo: "A")
        }
    }

    private func lado(_ b: Bolsillo, titulo: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).rotulo()
            HStack(spacing: 6) {
                Image(systemName: b.simbolo).font(.system(size: 13)).foregroundStyle(b == .negocio ? Color.acento : Color.sec)
                Text(b.nombre).font(.geist(15, .semi)).foregroundStyle(Color.texto)
            }
            MontoChico(centavos: estado.saldo(b), tamano: 14, color: .sec, conCentavos: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .caja(radio: 16)
        .id(b)
        .transition(.opacity)
    }

    private var rapidos: some View {
        HStack(spacing: 8) {
            Chip(texto: "Todo", on: entrada.centavos == saldoOrigen && saldoOrigen > 0) { entrada = EntradaMonto(centavos: saldoOrigen) }
            ForEach([1_000_000, 5_000_000, 10_000_000], id: \.self) { c in
                Chip(texto: Formato.plata(c), on: entrada.centavos == c) { entrada = EntradaMonto(centavos: c) }
            }
        }
    }

    private func pasar() {
        pasando = true
        error = nil
        let monto = entrada.centavos
        Task {
            do {
                _ = try await estado.pasar(monto, de: origen)
                estado.avisar("Pasaste " + Formato.plata(monto) + " a " + origen.otro.nombre)
                dismiss()
            } catch {
                self.error = estado.mensaje(error)
                Haptico.error()
            }
            pasando = false
        }
    }
}

/// Ingresar plata: tu CVU y alias para transferirte desde cualquier banco.
struct IngresarPlataPantalla: View {
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Cabecera("Ingresar plata") { Redondo("xmark", "Cerrar") { dismiss() } }
            ScrollView {
                VStack(spacing: 0) {
                    Icono3D(nombre: "ic-monedas", tamano: 88)
                    Titulo("Transferite desde cualquier banco.", tamano: 24, centrado: true).padding(.top, 8)
                    Text("Llega al instante y sin costo. Entra al bolsillo Personal.")
                        .parrafo(14).multilineTextAlignment(.center).padding(.top, 8)
                    datos.padding(.top, 20)
                    pasos.padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            ShareLink(item: textoCompartir) {
                Label("Compartir mis datos", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.principal)
            .simultaneousGesture(TapGesture().onEnded { Task { await estado.marcarPaso(.primeraPlata) } })
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
        .background(Color.fondo.ignoresSafeArea())
    }

    private var textoCompartir: String {
        let u = estado.usuario
        return "Mis datos de Cuarzo\n" + u.nombreCompleto + "\nAlias: " + u.alias + "\nCVU: " + u.cvu + "\nCUIT: " + u.cuit
    }

    private var datos: some View {
        VStack(spacing: 0) {
            fila("Alias", estado.usuario.alias, aviso: "Copiaste tu alias")
            Separador()
            fila("CVU", estado.usuario.cvu, aviso: "Copiaste tu CVU")
            Separador()
            HStack {
                Text("Titular").font(.geist(13)).foregroundStyle(Color.sec)
                Spacer()
                Text(estado.usuario.nombreCompleto + " · CUIT " + estado.usuario.cuit)
                    .font(.geist(13, .medio)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .vidrio(radio: 20)
    }

    private func fila(_ t: String, _ valor: String, aviso: String) -> some View {
        Button {
            copiar(valor, aviso: aviso, estado: estado)
            Task { await estado.marcarPaso(.primeraPlata) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(.geist(13)).foregroundStyle(Color.sec)
                    Text(valor).font(.mono(14)).foregroundStyle(Color.texto).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                Image(systemName: "doc.on.doc").font(.system(size: 16)).foregroundStyle(Color.acento)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t + " " + valor + ". Copiar")
    }

    private var pasos: some View {
        VStack(alignment: .leading, spacing: 14) {
            paso(1, "Abrí la app de tu banco o billetera.")
            paso(2, "Elegí transferir y pegá tu alias o CVU.")
            paso(3, "Listo: te avisamos apenas entra.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paso(_ n: Int, _ t: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(.mono(12)).foregroundStyle(Color.acento)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.acentoSuave))
            Text(t).font(.geist(14)).foregroundStyle(Color.texto)
        }
    }
}
