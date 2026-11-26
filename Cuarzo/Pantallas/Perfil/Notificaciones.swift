import SwiftUI

/// Avisos de la cuenta: lo nuevo arriba, lo leído abajo. Al salir, todo queda leído.
struct NotificacionesPantalla: View {
    @Environment(Estado.self) private var estado

    private var nuevas: [Notificacion] { estado.panel.notificaciones.filter { !$0.leida }.sorted { $0.fecha > $1.fecha } }
    private var leidas: [Notificacion] { estado.panel.notificaciones.filter(\.leida).sorted { $0.fecha > $1.fecha } }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: nil)
            VStack(spacing: 0) {
                CabeceraAtras("Notificaciones") {
                    if !nuevas.isEmpty {
                        Button("Leí todo") {
                            Haptico.tocar()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { estado.leerNotificaciones() }
                        }
                        .font(.geist(14, .semi)).foregroundStyle(Color.acento).buttonStyle(.plain)
                        .frame(minHeight: 44)
                    }
                }
                if estado.panel.notificaciones.isEmpty {
                    Spacer()
                    Vacio(icono: "ic-celular", titulo: "No hay avisos.", texto: "Cuando te entre plata o venza algo, te avisamos acá.")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !nuevas.isEmpty { grupo("Nuevas", nuevas) }
                            if !leidas.isEmpty { grupo("Anteriores", leidas) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .onDisappear { estado.leerNotificaciones() }
    }

    private func grupo(_ titulo: String, _ lista: [Notificacion]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).rotulo().padding(.top, 18)
            VStack(spacing: 0) {
                ForEach(Array(lista.enumerated()), id: \.element.id) { i, n in
                    if i > 0 { Separador(sangria: 52) }
                    fila(n)
                }
            }
            .padding(.horizontal, 16)
            .caja()
        }
    }

    private func fila(_ n: Notificacion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(iniciales: "", tono: n.leida ? .neutro : .rosa, simbolo: n.simbolo, tamano: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(n.titulo).font(.geist(15, n.leida ? .medio : .semi)).foregroundStyle(Color.texto)
                    Spacer(minLength: 8)
                    Text(cuando(n.fecha)).font(.geist(12)).foregroundStyle(Color.ter)
                }
                Text(n.texto).font(.geist(13)).foregroundStyle(Color.sec).fixedSize(horizontal: false, vertical: true)
            }
            if !n.leida {
                Circle().fill(Color.acento).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func cuando(_ d: Date) -> String {
        Fecha.calendario.isDateInToday(d) ? Fecha.hora(d) : Fecha.encabezado(d)
    }
}
