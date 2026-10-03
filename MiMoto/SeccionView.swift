import SwiftUI

/// Lista + resumen + acciones. Una sola vista sirve para todas las secciones.
struct SeccionView: View {
    @EnvironmentObject var store: Store
    let seccion: Seccion
    @State private var porEliminar: Int? = nil

    // Inicializador explícito: con `@State private var` el memberwise sintetizado
    // queda fileprivate y SeccionView se crea desde otros archivos.
    init(seccion: Seccion) {
        self.seccion = seccion
    }

    var body: some View {
        let filas = store.filas(seccion)
        List {
            if !filas.isEmpty {
                Section {
                    ResumenSeccion(seccion: seccion)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                if filas.isEmpty {
                    Text("Aún no hay registros. Toca «+» arriba para agregar el primero.")
                        .foregroundStyle(Color.secondary)
                }
                ForEach(filas) { fila in
                    NavigationLink {
                        DetalleView(seccion: seccion, id: fila.id)
                    } label: {
                        FilaView(fila: fila)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            porEliminar = fila.id
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        .tint(Color.red)
                        Button {
                            store.abrir(.registro(seccion, fila.id))
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(Color.blue)
                    }
                    .swipeActions(edge: .leading) {
                        if seccion == .mantenimientos {
                            Button {
                                store.alternarRealizado(fila.id)
                            } label: {
                                Label("Realizado", systemImage: "checkmark.circle.fill")
                            }
                            .tint(Color.green)
                        }
                    }
                }
            } footer: {
                if !filas.isEmpty {
                    Text("Toca un registro para ver todos sus datos. Desliza a la izquierda para editar o eliminar.")
                }
            }
        }
        .navigationTitle(seccion.titulo)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.abrir(.registro(seccion, nil))
                } label: {
                    Label("Agregar", systemImage: "plus.circle.fill")
                }
            }
        }
        .confirmationDialog("¿Eliminar este registro?",
                            isPresented: Binding(get: { porEliminar != nil },
                                                 set: { if !$0 { porEliminar = nil } }),
                            titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let id = porEliminar { store.eliminar(seccion, id: id) }
                porEliminar = nil
            }
            Button("Cancelar", role: .cancel) { porEliminar = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

struct FilaView: View {
    let fila: FilaLista

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(fila.estado?.nivel.color ?? Color.gray.opacity(0.3))
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(fila.titulo).font(.body.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 8)
                    if !fila.derecha.isEmpty {
                        Text(fila.derecha).font(.subheadline).foregroundStyle(Color.secondary)
                    }
                }
                if !fila.subtitulo.isEmpty {
                    Text(fila.subtitulo).font(.caption).foregroundStyle(Color.secondary)
                }
                if let estado = fila.estado {
                    Badge(estado: estado)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DatoTile: Identifiable {
    let titulo: String
    let valor: String
    var id: String { titulo }

    init(_ titulo: String, _ valor: String) {
        self.titulo = titulo
        self.valor = valor
    }
}

/// Cifras de resumen arriba de cada lista.
struct ResumenSeccion: View {
    @EnvironmentObject var store: Store
    let seccion: Seccion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(tiles) { t in
                    Tile(titulo: t.titulo, valor: t.valor)
                }
            }
            if let estado = estadoGeneral {
                Badge(estado: estado)
            }
        }
        .padding(.vertical, 4)
    }

    private var tiles: [DatoTile] {
        switch seccion {
        case .tanqueos:
            let r = store.resumen(store.tanqueosCalc)
            return [DatoTile("Consumo prom.", r.consumoProm.map { "\(Fmt.decimal($0, 1)) km/l" } ?? "—"),
                    DatoTile("Total gastado", Fmt.moneda(r.totalGastado)),
                    DatoTile("Total litros", "\(Fmt.decimal(r.totalLitros, 1)) L")]
        case .aceite:
            let proximo = store.aceitesOrdenados.first?.proximoKm
            return [DatoTile("Próximo cambio", Fmt.km(proximo)), DatoTile("Km actual", Fmt.km(store.kmActual))]
        case .soat:
            return [DatoTile("Vence", Fmt.fecha(store.soatOrdenados.first?.fechaVencimiento))]
        case .tecnomecanica:
            return [DatoTile("Vence", Fmt.fecha(store.tecnoOrdenados.first?.fechaVencimiento))]
        case .mantenimientos:
            let lista = store.mantenimientosCalc
            func contar(_ n: Nivel) -> String { String(lista.filter { $0.estado.nivel == n }.count) }
            return [DatoTile("Atrasados", contar(.bad)), DatoTile("Próximos", contar(.warn)), DatoTile("Al día", contar(.ok))]
        }
    }

    private var estadoGeneral: Estado? {
        switch seccion {
        case .aceite: return store.estadoAceite
        case .soat: return Reglas.estadoVencimiento(store.soatOrdenados.first?.fechaVencimiento)
        case .tecnomecanica: return Reglas.estadoVencimiento(store.tecnoOrdenados.first?.fechaVencimiento)
        default: return nil
        }
    }
}

/// Todos los datos de un registro, con Editar / Eliminar (y Marcar realizado).
struct DetalleView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let seccion: Seccion
    let id: Int
    @State private var confirmar = false

    var body: some View {
        let lineas = store.detalle(seccion, id: id)
        List {
            if lineas.isEmpty {
                Text("Ese registro ya no existe.").foregroundStyle(Color.secondary)
            } else {
                if let estado = store.estado(seccion, id: id) {
                    Section {
                        Badge(estado: estado)
                    }
                }
                Section {
                    ForEach(lineas) { l in
                        LabeledContent(l.etiqueta) {
                            Text(l.valor)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
                Section {
                    Button {
                        store.abrir(.registro(seccion, id))
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    if seccion == .mantenimientos, let m = store.mantenimiento(id) {
                        Button {
                            store.alternarRealizado(id)
                        } label: {
                            Label(m.completado ? "Reabrir mantenimiento" : "Marcar realizado",
                                  systemImage: m.completado ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                        }
                    }
                    Button(role: .destructive) {
                        confirmar = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(seccion.singular)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar este registro?", isPresented: $confirmar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                store.eliminar(seccion, id: id)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}
