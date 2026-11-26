import SwiftUI

/// Transferir: a quién (contactos, favoritos o un CVU/alias nuevo) → cuánto (pantalla 09) → Face ID → comprobante.
struct TransferirFlujo: View {
    var destino: Contacto?
    @Environment(Estado.self) private var estado
    @State private var elegido: Contacto?
    @State private var listo: String?
    @State private var empezo = false

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.25))
            if let listo {
                ComprobanteVista(movimientoID: listo, celebrar: true)
                    .transition(.opacity)
            } else if let elegido {
                MontoTransferencia(destino: elegido, desdeLista: destino == nil || destino?.id != elegido.id,
                                   cambiar: { ir(nil) }) { id in
                    withAnimation(.easeInOut(duration: 0.3)) { listo = id }
                }
                .transition(.move(edge: .trailing))
            } else {
                ElegirDestino { ir($0) }
                    .transition(.move(edge: .leading))
            }
        }
        .onAppear {
            guard !empezo else { return }
            empezo = true
            elegido = destino
        }
    }

    private func ir(_ c: Contacto?) {
        Haptico.tocar()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { elegido = c }
    }
}

// MARK: - A quién

private struct ElegirDestino: View {
    let elegir: (Contacto) -> Void
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var texto = ""
    @State private var buscando = false
    @State private var error: String?
    @State private var encontrado: Contacto?
    @FocusState private var foco: Bool

    private var limpio: String { texto.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "") }
    /// Parece un CVU (22 dígitos) o un alias (6 a 20, con un punto).
    private var pareceCuenta: Bool {
        (limpio.count == 22 && limpio.allSatisfy(\.isNumber)) || (limpio.count >= 6 && limpio.count <= 20 && limpio.contains("."))
    }

    private var contactos: [Contacto] {
        let q = texto.trimmingCharacters(in: .whitespaces).paraBuscar
        let todos = estado.panel.contactos.sorted { $0.nombre < $1.nombre }
        guard !q.isEmpty else { return todos }
        return todos.filter { $0.nombre.paraBuscar.contains(q) || $0.alias.contains(q) || $0.cvu.hasPrefix(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Cabecera("Transferir") { Redondo("xmark", "Cerrar") { dismiss() } }
            campo.padding(.horizontal, 20).padding(.top, 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let encontrado {
                        Confirmacion(c: encontrado, seguir: { elegir(encontrado) }, otro: {
                            withAnimation { self.encontrado = nil; texto = "" }
                        })
                        .padding(.top, 14)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                    } else {
                        if pareceCuenta { buscarFila.padding(.top, 12) }
                        if let error { errorFila(error).padding(.top, 10) }
                        if texto.isEmpty && !estado.favoritos.isEmpty { favoritos }
                        lista
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: encontrado)
                .animation(.easeInOut(duration: 0.2), value: pareceCuenta)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var campo: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.sec)
            TextField("", text: $texto, prompt: Text("Nombre, CVU o alias").foregroundStyle(Color.sec))
                .font(.geist(15))
                .foregroundStyle(Color.texto)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($foco)
                .submitLabel(.search)
                .onSubmit { if pareceCuenta { buscar() } }
                .onChange(of: texto) { _, _ in error = nil; encontrado = nil }
            if !texto.isEmpty {
                Button { texto = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ter) }
                    .buttonStyle(.plain).accessibilityLabel("Borrar")
            } else {
                Button {
                    if let s = UIPasteboard.general.string { texto = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                } label: {
                    Text("Pegar").font(.geist(14, .medio)).foregroundStyle(Color.acento)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .caja(radio: 14, seleccionada: foco)
    }

    private var buscarFila: some View {
        Button { buscar() } label: {
            HStack(spacing: 12) {
                Avatar(iniciales: "", tono: .rosa, simbolo: limpio.allSatisfy(\.isNumber) ? "number" : "at", tamano: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(limpio.allSatisfy(\.isNumber) ? "Transferir a este CVU" : "Transferir a este alias")
                        .font(.geist(15, .medio)).foregroundStyle(Color.texto)
                    Text(limpio).font(.mono(12.5)).foregroundStyle(Color.sec).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                if buscando { ProgressView().tint(Color.acento) } else { Flecha() }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
        .disabled(buscando)
    }

    private func errorFila(_ e: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 16))
            Text(e).font(.geist(14)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.error)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.errorSuave))
    }

    private var favoritos: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Favoritos").rotulo().padding(.top, 22).padding(.bottom, 12)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(estado.favoritos) { c in
                        Button { elegir(c) } label: {
                            VStack(spacing: 6) {
                                Avatar(iniciales: c.iniciales, tono: c.tono, tamano: 54)
                                    .overlay(alignment: .bottomTrailing) {
                                        if c.esCuarzo {
                                            Image("simbolo-vidrio").resizable().scaledToFit().frame(width: 18)
                                                .background(Circle().fill(Color.fondo).frame(width: 22, height: 22))
                                        }
                                    }
                                Text(c.nombre.split(separator: " ").first.map(String.init) ?? c.nombre)
                                    .font(.geist(12.5, .medio)).foregroundStyle(Color.texto).lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(Presionable(escala: 0.92))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
        }
    }

    @ViewBuilder
    private var lista: some View {
        let cs = contactos
        if !cs.isEmpty {
            Text(texto.isEmpty ? "Contactos" : "Resultados").rotulo().padding(.top, 22).padding(.bottom, 4)
            ForEach(Array(cs.enumerated()), id: \.element.id) { i, c in
                if i > 0 { Separador(sangria: 52) }
                Button { elegir(c) } label: { FilaContacto(c: c) }
                    .buttonStyle(Presionable(escala: 0.98))
                    .contextMenu {
                        Button(c.favorito ? "Sacar de favoritos" : "Sumar a favoritos", systemImage: c.favorito ? "star.slash" : "star") {
                            Task { await estado.alternarFavorito(c) }
                        }
                    }
            }
        } else if !pareceCuenta && error == nil {
            VStack(spacing: 10) {
                Icono3D(nombre: "ic-transferir", tamano: 80)
                Text(texto.isEmpty ? "Tu primera transferencia" : "No está en tus contactos")
                    .font(.geist(17, .semi)).foregroundStyle(Color.texto)
                Text("Escribí o pegá el CVU o alias de la otra persona. Entre cuentas Cuarzo llega al instante y sin costo.")
                    .parrafo(14).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 36)
            .padding(.horizontal, 12)
        }
    }

    private func buscar() {
        guard pareceCuenta, !buscando else { return }
        foco = false
        buscando = true
        error = nil
        Task {
            do {
                let c = try await estado.buscarDestino(limpio)
                Haptico.exito()
                withAnimation { encontrado = c }
            } catch {
                Haptico.error()
                withAnimation { self.error = estado.mensaje(error) }
            }
            buscando = false
        }
    }
}

private struct FilaContacto: View {
    let c: Contacto
    var body: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: c.iniciales, tono: c.tono, tamano: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(c.nombre).font(.geist(15, .medio)).foregroundStyle(Color.texto).lineLimit(1)
                    if c.favorito {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Color.acento)
                            .accessibilityLabel("Favorito")
                    }
                }
                Text(c.alias + " · " + c.banco).font(.geist(13)).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer()
            Flecha()
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }
}

/// Lo que encontramos para ese CVU/alias: nombre, banco y CUIT antes de mandar.
private struct Confirmacion: View {
    let c: Contacto
    let seguir: () -> Void
    let otro: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Avatar(iniciales: c.iniciales, tono: c.tono, tamano: 60)
            Text(c.nombre).font(.geist(20, .semi)).tracking(-0.5).foregroundStyle(Color.texto).padding(.top, 12)
            HStack(spacing: 6) {
                if c.esCuarzo {
                    Etiqueta(texto: "Cuenta Cuarzo", simbolo: "bolt")
                } else {
                    Etiqueta(texto: c.banco, simbolo: "building.columns", tipo: .neutra)
                }
            }
            .padding(.top, 8)
            VStack(spacing: 0) {
                RenglonTicket(etiqueta: "Alias", valor: c.alias, mono: true)
                Separador()
                RenglonTicket(etiqueta: "CVU", valor: Formato.cvu(c.cvu), mono: true)
                Separador()
                RenglonTicket(etiqueta: "CUIT", valor: c.cuit)
            }
            .padding(.top, 14)
            Button("Es esta persona, seguir", action: seguir).buttonStyle(.principal).padding(.top, 16)
            Button("No es, buscar otra", action: otro).buttonStyle(.textoRosa)
        }
        .padding(18)
        .vidrio()
    }
}

// MARK: - Cuánto (09)

private struct MontoTransferencia: View {
    let destino: Contacto
    let desdeLista: Bool
    let cambiar: () -> Void
    let enviado: (String) -> Void
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var entrada = EntradaMonto()
    @State private var desde: Bolsillo = .negocio
    @State private var motivo = "Varios"
    @State private var enviando = false
    @State private var error: String?

    private let motivos = ["Varios", "Alquiler", "Honorarios", "Cuota", "Facturas", "Expensas"]
    private var alcanza: Bool { entrada.centavos <= estado.saldo(desde) }

    var body: some View {
        GeometryReader { g in
            let chico = g.size.height < 660
            VStack(spacing: 0) {
                CabeceraCerrar("Transferir", atras: desdeLista ? cambiar : nil)
                destinoCaja.padding(.horizontal, 20).padding(.top, 4)
                etiquetas.padding(.horizontal, 20).padding(.top, 10)
                MontoTipeado(entrada: entrada, tamano: chico ? 46 : 56)
                    .padding(.top, chico ? 12 : 24).padding(.horizontal, 20)
                selectorBolsillo.padding(.top, 14)
                motivosFila.padding(.top, 12)
                Spacer(minLength: 6)
                if let error {
                    Text(error).font(.geist(13, .medio)).foregroundStyle(Color.error)
                        .multilineTextAlignment(.center).padding(.horizontal, 20).padding(.bottom, 4)
                } else if !alcanza {
                    Text("No te alcanza en " + desde.nombre + ". Elegí el otro bolsillo o pasá plata.")
                        .font(.geist(13)).foregroundStyle(Color.alerta).multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.bottom, 4)
                }
                TecladoNumerico(entrada: $entrada, alto: chico ? 44 : 52).padding(.horizontal, 12)
                Button { enviar() } label: {
                    if enviando {
                        HStack(spacing: 8) { ProgressView().tint(Color.noche); Text("Transfiriendo…") }
                    } else {
                        Text(entrada.vacio ? "Transferir" : "Transferir " + Formato.plata(entrada.centavos))
                    }
                }
                .buttonStyle(.principal)
                .disabled(entrada.vacio || !alcanza || enviando)
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .onAppear {
            if estado.saldo(.negocio) == 0 && estado.saldo(.personal) > 0 { desde = .personal }
        }
        .onChange(of: entrada) { _, _ in error = nil }
    }

    private var destinoCaja: some View {
        HStack(spacing: 12) {
            Avatar(iniciales: destino.iniciales, tono: destino.tono, tamano: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(destino.nombre).font(.geist(16, .semi)).tracking(-0.24).foregroundStyle(Color.texto).lineLimit(1)
                Text(destino.alias).font(.mono(12.5)).tracking(0.25).foregroundStyle(Color.sec).lineLimit(1)
            }
            Spacer()
            Button("Cambiar", action: cambiar)
                .font(.geist(14, .medio)).foregroundStyle(Color.acento).buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .caja()
    }

    private var etiquetas: some View {
        HStack(spacing: 8) {
            if destino.esCuarzo {
                Etiqueta(texto: "Cuenta Cuarzo", simbolo: "bolt")
            } else {
                Etiqueta(texto: destino.banco, simbolo: "building.columns", tipo: .neutra)
            }
            Etiqueta(texto: "Llega al instante · " + Formato.plata(0), tipo: .neutra)
            Spacer(minLength: 0)
        }
    }

    private var selectorBolsillo: some View {
        Menu {
            ForEach(Bolsillo.allCases) { b in
                Button {
                    Haptico.seleccion()
                    desde = b
                } label: {
                    Label(b.nombre + " · " + Formato.plata(estado.saldo(b)), systemImage: desde == b ? "checkmark" : b.simbolo)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: desde.simbolo).font(.system(size: 14)).foregroundStyle(Color.acento)
                Text("Desde " + desde.nombre).foregroundStyle(Color.texto)
                Text("· " + Formato.plata(estado.saldo(desde), centavos: false)).foregroundStyle(Color.sec).monospacedDigit()
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.sec)
            }
            .font(.geist(14))
            .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 8)
            .caja(radio: 12)
        }
        .accessibilityLabel("Desde " + desde.nombre + ", " + Formato.plata(estado.saldo(desde)) + ". Cambiar bolsillo")
    }

    private var motivosFila: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(motivos, id: \.self) { m in
                    Chip(texto: m, on: motivo == m) { motivo = m }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func enviar() {
        error = nil
        let monto = entrada.centavos
        Task {
            let primero = destino.nombre.split(separator: " ").first.map(String.init) ?? destino.nombre
            guard await estado.pedirFaceID("Para transferir " + Formato.plata(monto) + " a " + primero) else { return }
            enviando = true
            do {
                let m = try await estado.transferir(a: destino, centavos: monto, desde: desde, motivo: motivo)
                enviado(m.id)
            } catch ErrorCuarzo.frenada(let f) {
                Haptico.aviso()
                estado.abrir(.frenada(f))
            } catch {
                Haptico.error()
                self.error = estado.mensaje(error)
            }
            enviando = false
        }
    }
}
