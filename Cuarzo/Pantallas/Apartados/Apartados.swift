import SwiftUI

/// Texto de la regla con la parte importante en rosa («Se llena con el 15 % de cada cobro»).
func textoRegla(_ r: Apartado.Regla) -> Text {
    switch r {
    case .porcentaje(let p):
        return Text("Se llena con el ") + Text("\(p)\u{00A0}%").foregroundStyle(Color.acento).fontWeight(.medium) + Text(" de cada cobro")
    case .fijo(let c, let cuando):
        return Text(Formato.plata(c)).foregroundStyle(Color.acento).fontWeight(.medium) + Text(" " + cuando)
    case .manual:
        return Text("Lo cargás a mano")
    }
}

/// «Vence el 1/12» o «Para el 18/12».
func textoVence(_ a: Apartado) -> String? {
    guard let v = a.vence else { return nil }
    if case .fijo = a.regla { return "Para el " + Fecha.corta(v) }
    return "Vence el " + Fecha.corta(v)
}

/// Apartados (pantalla 13): plata con nombre que rinde mientras espera.
struct ApartadosPantalla: View {
    @Environment(Estado.self) private var estado

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.3, y: 0.14), tamanoBrillo: 360)
            VStack(spacing: 0) {
                CabeceraAtras("Apartados") {
                    Redondo("plus", "Nuevo apartado") { estado.abrir(.nuevoApartado) }
                }
                ScrollView {
                    if estado.panel.apartados.isEmpty {
                        vacio
                    } else {
                        lista
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await estado.cargar() }
            }
        }
    }

    private var lista: some View {
        VStack(spacing: 10) {
            TotalApartados()
            ForEach(estado.panel.apartados) { a in
                Button { estado.ir(.apartado(a.id)) } label: { TarjetaApartado(apartado: a) }
                    .buttonStyle(Presionable(escala: 0.98))
            }
            Button { estado.abrir(.nuevoApartado) } label: {
                Label("Nuevo apartado", systemImage: "plus")
                    .font(.geist(15, .medio))
                    .foregroundStyle(Color.acento)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.linea2, lineWidth: 1))
            }
            .buttonStyle(Presionable())
            Text("El rendimiento depende del fondo del socio y no está garantizado. TNA de referencia: dato de muestra.")
                .font(.geist(11.5)).foregroundStyle(Color.sec).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private var vacio: some View {
        VStack(spacing: 0) {
            Vacio(icono: "ic-frasco", titulo: "Ponele nombre a tu plata.",
                  texto: "Alquiler, aguinaldo o lo que quieras. Se llena sola y rinde a diario mientras espera.",
                  accion: "Crear el primero") { estado.abrir(.nuevoApartado) }
                .padding(.top, 40)
            HStack(spacing: 8) {
                ForEach([("ic-llaves", "Alquiler"), ("ic-calendario", "Aguinaldo"), ("ic-escudo", "Monotributo")], id: \.0) { par in
                    VStack(spacing: 6) {
                        Icono3D(nombre: par.0, tamano: 46)
                        Text(par.1).font(.geist(12, .medio)).foregroundStyle(Color.sec)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .caja(radio: 16)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// «Plata con nombre»: el total apartado.
private struct TotalApartados: View {
    @Environment(Estado.self) private var estado
    var body: some View {
        Button { estado.ir(.rendimiento) } label: {
            HStack(spacing: 14) {
                Icono3D(nombre: "ic-frasco", tamano: 72)
                    .padding(.vertical, -6).padding(.leading, -8).padding(.trailing, -4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plata con nombre").rotulo()
                    Monto(centavos: estado.totalApartado, tamano: 30, oculto: !estado.saldoVisible)
                    HStack(spacing: 6) {
                        Image(systemName: "bolt").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.acento)
                        Text("Rinde a diario mientras esperás").font(.geist(12.5)).foregroundStyle(Color.sec)
                    }
                }
                Spacer(minLength: 0)
                Flecha()
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .vidrio()
        }
        .buttonStyle(Presionable(escala: 0.98))
        .accessibilityHint("Ver el rendimiento")
    }
}

/// Un apartado en la lista: ícono, nombre, vence, monto, barra y regla.
struct TarjetaApartado: View {
    let apartado: Apartado
    @Environment(Estado.self) private var estado

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Icono3D(nombre: apartado.icono, tamano: 48).padding(-4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(apartado.nombre).font(.geist(16, .semi)).tracking(-0.3).foregroundStyle(Color.texto).lineLimit(1)
                    if let v = textoVence(apartado) {
                        Text(v).font(.geist(13)).foregroundStyle(Color.sec)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(estado.saldoVisible ? Formato.plata(apartado.actual, centavos: false) : "$\u{00A0}•••")
                        .font(.geist(16, .semi)).monospacedDigit().tracking(-0.3).foregroundStyle(Color.texto)
                    Text(apartado.listo ? "Listo" : "de " + Formato.plata(apartado.objetivo, centavos: false))
                        .font(.geist(12)).foregroundStyle(apartado.listo ? Color.acento : Color.sec)
                }
            }
            BarraProgreso(valor: apartado.progreso).padding(.top, 12)
            if !apartado.listo {
                HStack {
                    textoRegla(apartado.regla).font(.geist(12.5)).foregroundStyle(Color.sec)
                    Spacer()
                    Text("\(Int((apartado.progreso * 100).rounded()))\u{00A0}%").font(.geist(12.5)).monospacedDigit().foregroundStyle(Color.sec)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .caja()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detalle

/// Un apartado: anillo de progreso, guardar y sacar, regla editable y sus movimientos.
struct DetalleApartado: View {
    let id: String
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var confirmarBorrar = false
    @State private var editarRegla = false

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.2), tamanoBrillo: 420)
            if let a = estado.apartado(id) {
                contenido(a)
            } else {
                VStack {
                    CabeceraAtras("Apartado")
                    Vacio(icono: "ic-frasco", titulo: "Ese apartado ya no está.", texto: "Lo que tenía volvió a tu bolsillo.",
                          accion: "Ver apartados") { dismiss() }
                    Spacer()
                }
            }
        }
    }

    private func contenido(_ a: Apartado) -> some View {
        VStack(spacing: 0) {
            CabeceraAtras(a.nombre) {
                Menu {
                    Button { editarRegla = true } label: { Label("Cambiar cómo se llena", systemImage: "slider.horizontal.3") }
                    Button(role: .destructive) { confirmarBorrar = true } label: { Label("Borrar apartado", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 17, weight: .medium)).foregroundStyle(Color.texto)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.sup2).overlay(Circle().strokeBorder(Color.linea, lineWidth: 1)))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Más opciones")
            }
            ScrollView {
                VStack(spacing: 0) {
                    AnilloApartado(apartado: a).padding(.top, 8)
                    datosClave(a).padding(.top, 18)
                    HStack(spacing: 10) {
                        Button { estado.abrir(.moverApartado(a.id, guardar: false)) } label: { Label("Sacar", systemImage: "arrow.up.right") }
                            .buttonStyle(.secundario)
                            .disabled(a.actual == 0)
                        Button { estado.abrir(.moverApartado(a.id, guardar: true)) } label: { Label("Guardar", systemImage: "plus") }
                            .buttonStyle(.principal)
                    }
                    .padding(.top, 18)
                    regla(a).padding(.top, 12)
                    MovimientosApartado(apartado: a)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("¿Borrar «\(a.nombre)»?", isPresented: $confirmarBorrar, titleVisibility: .visible) {
            Button("Borrar y devolver la plata", role: .destructive) { Task { await borrar(a) } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(mensajeBorrar(a))
        }
        .sheet(isPresented: $editarRegla) { EditarRegla(apartado: a).environment(estado) }
    }

    private func mensajeBorrar(_ a: Apartado) -> String {
        let plata: String = Formato.plata(a.actual)
        return "Los \(plata) vuelven a tu bolsillo \(a.bolsillo.nombre)."
    }

    private func datosClave(_ a: Apartado) -> some View {
        HStack(spacing: 8) {
            dato(a.listo ? "Completo" : "Faltan", a.listo ? "Listo" : Formato.plata(a.falta, centavos: false), rosa: a.listo)
            if let v = a.vence {
                let d = max(0, Fecha.dias(desde: .now, hasta: v))
                dato(textoVence(a) ?? "Vence", d == 0 ? "Hoy" : d == 1 ? "Mañana" : "En \(d) días")
            }
            dato("Bolsillo", a.bolsillo.nombre)
        }
    }

    private func dato(_ t: String, _ v: String, rosa: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.geist(12)).foregroundStyle(Color.sec).lineLimit(1).minimumScaleFactor(0.8)
            Text(v).font(.geist(15, .semi)).monospacedDigit().foregroundStyle(rosa ? Color.acento : Color.texto)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .caja(radio: 14)
        .accessibilityElement(children: .combine)
    }

    private func regla(_ a: Apartado) -> some View {
        Button { editarRegla = true } label: {
            FilaAjuste(simbolo: "arrow.triangle.2.circlepath", titulo: "Cómo se llena", tono: .rosa) {
                Flecha()
            }
            .overlay(alignment: .bottomLeading) {
                textoRegla(a.regla).font(.geist(13)).foregroundStyle(Color.sec)
                    .padding(.leading, 48).padding(.bottom, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .caja()
        }
        .buttonStyle(Presionable(escala: 0.98))
    }

    private func borrar(_ a: Apartado) async {
        do {
            try await estado.borrarApartado(a.id)
            estado.avisar("Devolvimos " + Formato.plata(a.actual) + " a " + a.bolsillo.nombre)
            dismiss()
        } catch {
            estado.avisar(estado.mensaje(error), tipo: .error)
        }
    }
}

/// El anillo grande: se llena al aparecer, con el ícono 3D adentro y el monto abajo.
private struct AnilloApartado: View {
    let apartado: Apartado
    @Environment(Estado.self) private var estado
    @State private var valor: Double = 0

    private var subtitulo: String {
        let objetivo: String = Formato.plata(apartado.objetivo)
        let porciento: Int = Int((apartado.progreso * 100).rounded())
        return "de \(objetivo) · \(porciento)\u{00A0}%"
    }

    private var gradiente: AngularGradient {
        AngularGradient(colors: [Color.rosaOsc, Color.rosa2, Color.rosaOsc], center: .center)
    }

    private var anillo: some View {
        ZStack {
            Circle().stroke(Color.sup3, lineWidth: 12)
            Circle()
                .trim(from: 0, to: valor)
                .stroke(gradiente, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.rosa.opacity(0.4), radius: 10)
            Icono3D(nombre: apartado.icono, tamano: 92)
        }
        .frame(width: 190, height: 190)
    }

    var body: some View {
        VStack(spacing: 14) {
            anillo
            VStack(spacing: 4) {
                Monto(centavos: apartado.actual, tamano: 38, oculto: !estado.saldoVisible)
                Text(subtitulo)
                    .font(.geist(14)).monospacedDigit().foregroundStyle(Color.sec)
            }
        }
        .onAppear(perform: llenar)
        .onChange(of: apartado.progreso) { _, _ in llenar() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(etiqueta)
    }

    private func llenar() {
        let p: Double = apartado.progreso
        withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) { valor = p }
    }

    private var etiqueta: String {
        let actual: String = Formato.plata(apartado.actual)
        return "\(apartado.nombre), \(actual) \(subtitulo)"
    }
}

/// Los movimientos que tocaron este apartado.
private struct MovimientosApartado: View {
    let apartado: Apartado
    @Environment(Estado.self) private var estado

    var body: some View {
        let ms = estado.panel.movimientos.filter { $0.tipo == .apartado && $0.titulo == apartado.nombre }
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Movimientos")
            if ms.isEmpty {
                Text("Cuando guardes o saques plata, lo ves acá.").parrafo(14).padding(.vertical, 6)
            } else {
                ForEach(ms) { m in
                    Button { estado.ir(.movimiento(m.id)) } label: { FilaMovimiento(m: m, conHora: true) }.buttonStyle(.plain)
                    if m.id != ms.last?.id { Separador() }
                }
            }
        }
    }
}

/// Cambiar cómo se llena un apartado.
private struct EditarRegla: View {
    let apartado: Apartado
    @Environment(Estado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var regla: ReglaElegida = .manual
    @State private var porcentaje = 15
    @State private var fijo: Centavos = 4_000_000

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(Color.linea2).frame(width: 36, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            Titulo("¿Cómo se llena?", tamano: 24).padding(.top, 18)
            SelectorRegla(regla: $regla, porcentaje: $porcentaje, fijo: $fijo).padding(.top, 16)
            Spacer(minLength: 16)
            Button("Guardar") { Task { await guardar() } }.buttonStyle(.principal)
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .background(Color.fondo.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear {
            switch apartado.regla {
            case .porcentaje(let p): regla = .porcentaje; porcentaje = p
            case .fijo(let c, _): regla = .fijo; fijo = c
            case .manual: regla = .manual
            }
        }
    }

    private func guardar() async {
        var a = apartado
        a.regla = regla.regla(porcentaje: porcentaje, fijo: fijo)
        do {
            try await estado.guardarApartado(a)
            estado.avisar("Listo, se llena así")
            dismiss()
        } catch {
            estado.avisar(estado.mensaje(error), tipo: .error)
        }
    }
}

/// Las tres formas de llenar un apartado.
enum ReglaElegida: Hashable {
    case porcentaje, fijo, manual
    func regla(porcentaje: Int, fijo: Centavos) -> Apartado.Regla {
        switch self {
        case .porcentaje: return .porcentaje(porcentaje)
        case .fijo: return .fijo(fijo, "cada viernes")
        case .manual: return .manual
        }
    }
}

/// Selector de regla: tarjetas seleccionables con su ajuste.
struct SelectorRegla: View {
    @Binding var regla: ReglaElegida
    @Binding var porcentaje: Int
    @Binding var fijo: Centavos

    var body: some View {
        VStack(spacing: 10) {
            opcion(.porcentaje, "Un % de cada cobro", "Se aparta solo cuando te entra plata.", "percent") {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20], id: \.self) { p in
                        Chip(texto: "\(p)\u{00A0}%", on: porcentaje == p) { porcentaje = p }
                    }
                }
            }
            opcion(.fijo, "Un monto cada viernes", "Lo separamos del bolsillo cada semana.", "calendar") {
                HStack(spacing: 8) {
                    ForEach([1_000_000, 2_000_000, 4_000_000], id: \.self) { c in
                        Chip(texto: Formato.plata(c), on: fijo == c) { fijo = c }
                    }
                }
            }
            opcion(.manual, "A mano", "Guardás cuando quieras.", "hand.tap") { EmptyView() }
        }
    }

    private func opcion<Extra: View>(_ r: ReglaElegida, _ t: String, _ d: String, _ s: String,
                                     @ViewBuilder extra: () -> Extra) -> some View {
        let on = regla == r
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: s).font(.system(size: 16)).foregroundStyle(Color.acento)
                    .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(Color.acentoSuave))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.geist(15, .semi)).foregroundStyle(Color.texto)
                    Text(d).font(.geist(13)).foregroundStyle(Color.sec)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(on ? Color.acento : Color.linea2)
            }
            if on { extra().transition(.opacity.combined(with: .move(edge: .top))) }
        }
        .padding(14)
        .caja(radio: 16, seleccionada: on)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptico.seleccion()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { regla = r }
        }
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
