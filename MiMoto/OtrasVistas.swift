import SwiftUI
import UniformTypeIdentifiers

// MARK: - Más

struct MasView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            Section("Documentos") {
                NavigationLink(destination: SeccionView(seccion: .soat)) {
                    Label("SOAT", systemImage: Seccion.soat.icono)
                }
                NavigationLink(destination: SeccionView(seccion: .tecnomecanica)) {
                    Label("Tecnomecánica", systemImage: Seccion.tecnomecanica.icono)
                }
            }
            Section("Registros") {
                NavigationLink(destination: HistorialView()) {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
            }
            Section("Moto y datos") {
                Button {
                    store.abrir(.moto)
                } label: {
                    Label("Editar información de la moto", systemImage: "pencil")
                }
                NavigationLink(destination: RespaldoView()) {
                    Label("Copia de seguridad", systemImage: "externaldrive.fill")
                }
            }
        }
        .navigationTitle("Más")
    }
}

// MARK: - Historial

struct HistorialView: View {
    @EnvironmentObject var store: Store
    @State private var filtro: Seccion? = nil

    var body: some View {
        let items = store.historial(filtro)
        List {
            Section {
                Picker("Mostrar", selection: $filtro) {
                    Text("Todo").tag(Seccion?.none)
                    ForEach(Seccion.allCases) { s in
                        Text(s.nombreTipo).tag(Seccion?.some(s))
                    }
                }
            }
            Section {
                if items.isEmpty {
                    Text("No hay registros para mostrar.").foregroundStyle(Color.secondary)
                }
                ForEach(items) { item in
                    Button {
                        store.abrir(.registro(item.tipo, item.regId))
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.tipo.icono)
                                .foregroundStyle(Tema.acento)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.titulo).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                Text(item.detalle).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(Fmt.fecha(item.fecha)).font(.caption).foregroundStyle(Color.secondary)
                        }
                    }
                }
            } footer: {
                if !items.isEmpty {
                    Text("Toca un registro para editarlo.")
                }
            }
        }
        .navigationTitle("Historial")
    }
}

// MARK: - Copia de seguridad

struct ArchivoCompartido: Identifiable {
    let id = UUID()
    let url: URL
}

enum AlertaRespaldo {
    case confirmar(Data)
    case error(String)
    case listo(Int)

    var titulo: String {
        switch self {
        case .confirmar: return "Importar respaldo"
        case .error: return "No se pudo completar"
        case .listo: return "Respaldo importado"
        }
    }

    var mensaje: String {
        switch self {
        case .confirmar:
            return "Esto reemplazará todos los datos actuales por los del archivo. Antes se guarda una copia automática. ¿Continuar?"
        case .error(let texto): return texto
        case .listo(let total): return "\(total) registros restaurados."
        }
    }
}

struct RespaldoView: View {
    @EnvironmentObject var store: Store
    @State private var compartir: ArchivoCompartido? = nil
    @State private var eligiendo = false
    @State private var alerta: AlertaRespaldo? = nil

    var body: some View {
        List {
            Section {
                Text("Guarda todos tus registros en un archivo JSON. Consérvalo en un lugar seguro: Archivos, iCloud Drive, correo o WhatsApp.")
                    .foregroundStyle(Color.secondary)
                Button {
                    exportar()
                } label: {
                    Label("Exportar datos", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Exportar datos")
            }

            Section {
                Text("Restaura un respaldo exportado antes, desde esta app o desde la versión de computador (Python). Reemplaza todos los datos actuales; antes se guarda una copia automática.")
                    .foregroundStyle(Color.secondary)
                Button(role: .destructive) {
                    eligiendo = true
                } label: {
                    Label("Importar respaldo", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Importar datos")
            }

            Section {
                Text("Tus datos se guardan solo en este iPhone. Puedes verlos en la app Archivos › En mi iPhone › MiMoto.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .navigationTitle("Copia de seguridad")
        .sheet(item: $compartir) { archivo in
            ShareSheet(items: [archivo.url])
        }
        .fileImporter(isPresented: $eligiendo,
                      allowedContentTypes: [UTType.json, UTType.plainText, UTType.data],
                      allowsMultipleSelection: false) { resultado in
            switch resultado {
            case .success(let urls):
                guard let url = urls.first else { return }
                let acceso = url.startAccessingSecurityScopedResource()
                defer { if acceso { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    mostrar(.confirmar(data))
                } catch {
                    mostrar(.error("No se pudo leer el archivo."))
                }
            case .failure:
                mostrar(.error("No se pudo abrir el archivo."))
            }
        }
        .alert(alerta?.titulo ?? "",
               isPresented: Binding(get: { alerta != nil }, set: { if !$0 { alerta = nil } }),
               presenting: alerta) { a in
            switch a {
            case .confirmar(let data):
                Button("Cancelar", role: .cancel) {}
                Button("Reemplazar datos", role: .destructive) { importar(data) }
            case .error, .listo:
                Button("Aceptar", role: .cancel) {}
            }
        } message: { a in
            Text(a.mensaje)
        }
    }

    /// Las alertas se muestran un instante después para que el selector de archivos termine de cerrarse.
    private func mostrar(_ a: AlertaRespaldo) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alerta = a
        }
    }

    private func exportar() {
        do {
            let url = try store.archivoExportacion()
            compartir = ArchivoCompartido(url: url)
        } catch {
            alerta = .error("No se pudo crear el archivo de respaldo.")
        }
    }

    private func importar(_ data: Data) {
        do {
            let total = try store.importar(data)
            store.avisar("Respaldo importado: \(total) registros restaurados.")
            mostrar(.listo(total))
        } catch {
            mostrar(.error(error.localizedDescription))
        }
    }
}
