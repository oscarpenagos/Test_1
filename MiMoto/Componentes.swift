import SwiftUI
import UIKit

// MARK: - Colores (azul oscuro, negro, blanco y gris, como la versión de escritorio)

enum Tema {
    static let navy = Color(red: 10 / 255, green: 35 / 255, blue: 66 / 255)
    static let navy2 = Color(red: 22 / 255, green: 58 / 255, blue: 107 / 255)
    static let acento = Color("AccentColor")
    static let fondo = Color(UIColor.systemGroupedBackground)
    static let tarjeta = Color(UIColor.secondarySystemGroupedBackground)
}

extension Nivel {
    var color: Color {
        switch self {
        case .ok: return Color.green
        case .warn: return Color.orange
        case .bad: return Color.red
        case .none, .done: return Color.gray
        }
    }
}

// MARK: - Piezas visuales

struct Tarjeta<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.tarjeta, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Badge: View {
    let estado: Estado

    var body: some View {
        Text(estado.texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(estado.nivel.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(estado.nivel.color.opacity(0.15), in: Capsule())
    }
}

struct Tile: View {
    let titulo: String
    let valor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(Color.secondary)
            Text(valor).font(.headline).foregroundStyle(Tema.acento)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Tema.tarjeta, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct Encabezado: View {
    let titulo: String
    let icono: String

    var body: some View {
        Label(titulo, systemImage: icono)
            .font(.headline)
            .foregroundStyle(Tema.acento)
    }
}

struct AvisoBanner: View {
    let aviso: Aviso

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: aviso.error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(aviso.texto).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(aviso.error ? Color.red : Color.green.opacity(0.9), in: Capsule())
        .shadow(radius: 6)
        .padding(.horizontal)
    }
}

/// Hoja para compartir o guardar archivos (Archivos, correo, WhatsApp…).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Compatibilidad con iOS 15 (iPhone 13 de fábrica)

/// Navegación que funciona en iOS 15 y aprovecha NavigationStack desde iOS 16.
struct Navegacion<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}

extension View {
    /// Oculta el teclado al desplazar el formulario (solo iOS 16 o superior).
    @ViewBuilder
    func ocultarTecladoAlDesplazar() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

// MARK: - Campos de formulario

struct MensajeError: View {
    let texto: String?

    var body: some View {
        if let texto = texto {
            Text(texto).font(.caption).foregroundStyle(Color.red)
        }
    }
}

struct CampoTexto: View {
    let etiqueta: String
    @Binding var texto: String
    var placeholder: String = ""
    var teclado: UIKeyboardType = .default
    var sugerencias: [String] = []
    var mayusculas: Bool = false
    var ayuda: String? = nil
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etiqueta).font(.caption).foregroundStyle(Color.secondary)
            HStack {
                TextField(placeholder.isEmpty ? etiqueta : placeholder, text: $texto)
                    .keyboardType(teclado)
                    .textInputAutocapitalization(mayusculas ? TextInputAutocapitalization.characters : TextInputAutocapitalization.sentences)
                    .disableAutocorrection(teclado != .default || mayusculas)
                if !sugerencias.isEmpty {
                    Menu {
                        ForEach(sugerencias, id: \.self) { s in
                            Button(s) { texto = s }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(Tema.acento)
                    }
                }
            }
            if let ayuda = ayuda {
                Text(ayuda).font(.caption2).foregroundStyle(Color.secondary)
            }
            MensajeError(texto: error)
        }
        .padding(.vertical, 2)
    }
}

struct CampoNotas: View {
    @Binding var texto: String
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notas").font(.caption).foregroundStyle(Color.secondary)
            if #available(iOS 16.0, *) {
                TextField("Opcional", text: $texto, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextEditor(text: $texto)
                    .frame(minHeight: 80)
            }
            MensajeError(texto: error)
        }
        .padding(.vertical, 2)
    }
}

enum RangoFechas {
    static let minimo = Fechas.fecha(anio: 1990, mes: 1, dia: 1)
    static let maximo = Fechas.fecha(anio: 2100, mes: 12, dia: 31)

    static func rango(noFuturo: Bool) -> ClosedRange<Date> {
        minimo...(noFuturo ? Date() : maximo)
    }
}

struct CampoFecha: View {
    let etiqueta: String
    @Binding var fecha: Date
    var noFuturo: Bool = false
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DatePicker(etiqueta, selection: $fecha,
                       in: RangoFechas.rango(noFuturo: noFuturo), displayedComponents: .date)
            MensajeError(texto: error)
        }
    }
}

/// Fecha que se puede dejar vacía (interruptor + calendario).
struct CampoFechaOpcional: View {
    let etiqueta: String
    @Binding var fecha: Date?
    var noFuturo: Bool = false
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(etiqueta, isOn: Binding(
                get: { fecha != nil },
                set: { activo in fecha = activo ? (fecha ?? Date()) : nil }))
            if fecha != nil {
                DatePicker("Fecha", selection: Binding(
                    get: { fecha ?? Date() },
                    set: { fecha = $0 }),
                    in: RangoFechas.rango(noFuturo: noFuturo), displayedComponents: .date)
            }
            MensajeError(texto: error)
        }
    }
}

struct ErrorGeneral: View {
    let errores: [String: String]

    var body: some View {
        if !errores.isEmpty {
            Section {
                Label(errores["_general"] ?? "Revisa los campos marcados en rojo.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
            }
        }
    }
}
