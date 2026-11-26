import SwiftUI
import UIKit

/// Copia al portapapeles con aviso y háptico.
@MainActor
func copiar(_ texto: String, aviso: String, estado: Estado) {
    UIPasteboard.general.string = texto
    estado.avisar(aviso)
}

/// Dibuja una vista como imagen (para compartir el comprobante o el QR).
@MainActor
func imagen<V: View>(de vista: V, ancho: CGFloat = 390, oscuro: Bool = false) -> UIImage? {
    let r = ImageRenderer(content: vista.frame(width: ancho).environment(\.colorScheme, oscuro ? .dark : .light))
    r.scale = 3
    return r.uiImage
}

/// Imagen transferible para ShareLink.
struct ImagenCompartible: Transferable {
    let imagen: UIImage
    let nombre: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.imagen.pngData() ?? Data() }
            .suggestedFileName { $0.nombre + ".png" }
    }
}

/// PDF de una vista (el comprobante «PDF»).
@MainActor
func pdf<V: View>(de vista: V, nombre: String, ancho: CGFloat = 390) -> URL? {
    let r = ImageRenderer(content: vista.frame(width: ancho).environment(\.colorScheme, .light))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre + ".pdf")
    var ok = false
    r.render { tamano, dibujar in
        var caja = CGRect(origin: .zero, size: tamano)
        guard let ctx = CGContext(url as CFURL, mediaBox: &caja, nil) else { return }
        ctx.beginPDFPage(nil)
        dibujar(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        ok = true
    }
    return ok ? url : nil
}
