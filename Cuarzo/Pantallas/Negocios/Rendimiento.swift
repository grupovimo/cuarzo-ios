import SwiftUI
import Charts

/// Lo que rinde la plata apartada: hoy, en el mes, la TNA de referencia y los últimos 14 días.
struct RendimientoPantalla: View {
    @Environment(Estado.self) private var estado

    private var r: Rendimiento { estado.panel.rendimiento }

    var body: some View {
        ZStack {
            FondoCuarzo(brillo: CGPoint(x: 0.5, y: 0.18), tamanoBrillo: 420)
            VStack(spacing: 0) {
                CabeceraAtras("Rendimiento")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        principal
                        comoFunciona.padding(.top, 8)
                        Text("El rendimiento depende del fondo del socio y no está garantizado. TNA de referencia: dato de muestra.")
                            .parrafo(12).padding(.top, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var principal: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ganaste hoy").rotulo()
                    Monto(centavos: r.ganadoHoy, tamano: 38, oculto: !estado.saldoVisible)
                }
                Spacer()
                Icono3D(nombre: "ic-rendimiento", tamano: 64).padding(.top, -6)
            }
            HStack(spacing: 8) {
                Etiqueta(texto: "TNA \(Int((r.tna * 100).rounded()))\u{00A0}% · muestra", simbolo: "chart.line.uptrend.xyaxis", tipo: .ok)
                Text("En " + Fecha.mes(.now) + ": " + Formato.plata(r.ganadoMes)).font(.geist(13)).monospacedDigit().foregroundStyle(Color.sec)
            }
            .padding(.top, 10)
            grafico.padding(.top, 18)
            Separador().padding(.vertical, 14)
            Button { estado.ir(.apartados) } label: {
                HStack {
                    Text("Rinde sobre " + Formato.plata(estado.totalApartado, centavos: false) + " apartados")
                        .font(.geist(14, .medio)).foregroundStyle(Color.texto)
                    Spacer()
                    Text("Ver").font(.geist(14, .medio)).foregroundStyle(Color.acento)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .vidrio()
    }

    private struct Punto: Identifiable { let id: Int; let centavos: Centavos }

    private var puntos: [Punto] { r.historial.enumerated().map { Punto(id: $0.offset, centavos: $0.element) } }

    private var grafico: some View {
        Chart(puntos) { p in
            AreaMark(x: .value("Día", p.id), y: .value("Rindió", Double(p.centavos) / 100))
                .foregroundStyle(LinearGradient(colors: [Color.acento.opacity(0.35), Color.acento.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Día", p.id), y: .value("Rindió", Double(p.centavos) / 100))
                .foregroundStyle(Color.acento)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            if p.id == puntos.count - 1 {
                PointMark(x: .value("Día", p.id), y: .value("Rindió", Double(p.centavos) / 100))
                    .foregroundStyle(Color.acento)
                    .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)
        .overlay(alignment: .bottomLeading) {
            Text("Últimos 14 días").font(.mono(9.5)).tracking(1).foregroundStyle(Color.sec).offset(y: 16)
        }
        .padding(.bottom, 10)
        .accessibilityElement()
        .accessibilityLabel("Rendimiento de los últimos 14 días, en subida")
    }

    private var comoFunciona: some View {
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: "Cómo funciona")
            VStack(alignment: .leading, spacing: 14) {
                paso(1, "Lo que apartás se invierte en un fondo de liquidez del socio.")
                paso(2, "Rinde todos los días, también sábados y domingos.")
                paso(3, "Lo sacás cuando quieras, al instante y sin costo.")
            }
            .padding(16)
            .caja()
        }
    }

    private func paso(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)").font(.geist(13, .semi)).foregroundStyle(Color.acento)
                .frame(width: 26, height: 26).background(Circle().fill(Color.acentoSuave))
            Text(t).font(.geist(15)).foregroundStyle(Color.texto).fixedSize(horizontal: false, vertical: true)
        }
    }
}
