import SwiftUI
import UIKit

/// Abre el formulario que corresponda (nuevo o edición).
struct FormularioView: View {
    @EnvironmentObject var store: Store
    let formulario: Formulario

    var body: some View {
        NavigationStack {
            contenido
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch formulario {
        case .moto:
            MotoForm(original: store.db.moto)
        case .registro(.tanqueos, let id):
            TanqueoForm(original: store.tanqueo(id), kmActual: store.kmActual)
        case .registro(.aceite, let id):
            AceiteForm(original: store.aceite(id), kmActual: store.kmActual,
                       intervaloPrevio: store.aceitesOrdenados.first?.intervaloKm ?? 3000)
        case .registro(.soat, let id):
            SoatForm(original: store.soat(id))
        case .registro(.tecnomecanica, let id):
            TecnoForm(original: store.tecno(id), kmActual: store.kmActual)
        case .registro(.mantenimientos, let id):
            MantenimientoForm(original: store.mantenimiento(id))
        }
    }
}

// MARK: - Marco común: título, Cancelar / Guardar y botón para cerrar el teclado

private struct MarcoFormulario: ViewModifier {
    @EnvironmentObject var store: Store
    let titulo: String
    let guardar: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { store.formulario = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                }
            }
    }
}

private extension View {
    func marcoFormulario(_ titulo: String, guardar: @escaping () -> Void) -> some View {
        modifier(MarcoFormulario(titulo: titulo, guardar: guardar))
    }
}

private func titulo(_ seccion: Seccion, nuevo: Bool) -> String {
    "\(nuevo ? "Agregar" : "Editar") \(seccion.singularMin)"
}

private func textoKm(_ km: Int?) -> String {
    guard let km = km, km > 0 else { return "" }
    return String(km)
}

// MARK: - Tanqueo

struct TanqueoForm: View {
    @EnvironmentObject var store: Store
    let original: Tanqueo?

    @State private var fecha: Date
    @State private var km: String
    @State private var litros: String
    @State private var valor: String
    @State private var estacion: String
    @State private var notas: String
    @State private var errores: [String: String] = [:]

    init(original: Tanqueo?, kmActual: Int) {
        self.original = original
        _fecha = State(initialValue: Fechas.desdeISO(original?.fecha) ?? Date())
        _km = State(initialValue: textoKm(original?.km ?? kmActual))
        _litros = State(initialValue: Fmt.editable(original?.litros))
        _valor = State(initialValue: original.map { String($0.valor) } ?? "")
        _estacion = State(initialValue: original?.estacion ?? "")
        _notas = State(initialValue: original?.notas ?? "")
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoFecha(etiqueta: "Fecha", fecha: $fecha, noFuturo: true, error: errores["fecha"])
                CampoTexto(etiqueta: "Kilometraje (km)", texto: $km, placeholder: "Ej: 24580",
                           teclado: .numberPad, error: errores["km"])
                CampoTexto(etiqueta: "Litros", texto: $litros, placeholder: "Ej: 8,5",
                           teclado: .decimalPad, error: errores["litros"])
                CampoTexto(etiqueta: "Valor total ($)", texto: $valor, placeholder: "Ej: 35000",
                           teclado: .numberPad, error: errores["valor"])
                CampoTexto(etiqueta: "Estación de servicio", texto: $estacion, placeholder: "Opcional",
                           error: errores["estacion"])
            }
            Section {
                CampoNotas(texto: $notas, error: errores["notas"])
            }
        }
        .marcoFormulario(titulo(.tanqueos, nuevo: original == nil), guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let fechaV = v.fecha("fecha", fecha, "Fecha", noFuturo: true)
        let kmV = v.entero("km", km, "Kilometraje (km)", requerido: true, minimo: 0, maximo: Reglas.kmMax)
        let litrosV = v.decimal("litros", litros, "Litros", requerido: true, minimo: 0.1, maximo: 100)
        let valorV = v.entero("valor", valor, "Valor total ($)", requerido: true, minimo: 1, maximo: 10_000_000)
        let estacionV = v.texto("estacion", estacion, "Estación de servicio")
        let notasV = v.texto("notas", notas, "Notas", maxLen: 500)
        errores = v.errores
        guard v.ok, let f = fechaV, let k = kmV, let l = litrosV, let val = valorV else { return }
        let t = Tanqueo(id: original?.id ?? 0, fecha: f, km: k, litros: l, valor: val,
                        estacion: estacionV, notas: notasV)
        if store.guardar(t, en: \.tanqueos) {
            store.formulario = nil
            store.avisar(Seccion.tanqueos.mensajeGuardado)
        }
    }
}

// MARK: - Cambio de aceite

struct AceiteForm: View {
    @EnvironmentObject var store: Store
    let original: Aceite?

    @State private var fecha: Date
    @State private var km: String
    @State private var marca: String
    @State private var viscosidad: String
    @State private var cantidad: String
    @State private var valor: String
    @State private var lugar: String
    @State private var intervalo: String
    @State private var notas: String
    @State private var errores: [String: String] = [:]

    init(original: Aceite?, kmActual: Int, intervaloPrevio: Int) {
        self.original = original
        _fecha = State(initialValue: Fechas.desdeISO(original?.fecha) ?? Date())
        _km = State(initialValue: textoKm(original?.km ?? kmActual))
        _marca = State(initialValue: original?.marca ?? "")
        _viscosidad = State(initialValue: original?.viscosidad ?? "")
        _cantidad = State(initialValue: Fmt.editable(original?.cantidad))
        _valor = State(initialValue: original?.valor.map { String($0) } ?? "")
        _lugar = State(initialValue: original?.lugar ?? "")
        _intervalo = State(initialValue: String(original?.intervaloKm ?? intervaloPrevio))
        _notas = State(initialValue: original?.notas ?? "")
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoFecha(etiqueta: "Fecha", fecha: $fecha, noFuturo: true, error: errores["fecha"])
                CampoTexto(etiqueta: "Kilometraje (km)", texto: $km, placeholder: "Ej: 24580",
                           teclado: .numberPad, error: errores["km"])
                CampoTexto(etiqueta: "Marca del aceite", texto: $marca, placeholder: "Ej: Motul",
                           error: errores["marca"])
                CampoTexto(etiqueta: "Tipo / viscosidad", texto: $viscosidad, placeholder: "Ej: 10W40",
                           sugerencias: Reglas.viscosidades, mayusculas: true, error: errores["viscosidad"])
                CampoTexto(etiqueta: "Cantidad utilizada (litros)", texto: $cantidad, placeholder: "Opcional",
                           teclado: .decimalPad, error: errores["cantidad"])
                CampoTexto(etiqueta: "Valor ($)", texto: $valor, placeholder: "Opcional",
                           teclado: .numberPad, error: errores["valor"])
                CampoTexto(etiqueta: "Taller o lugar", texto: $lugar, placeholder: "Opcional",
                           error: errores["lugar"])
                CampoTexto(etiqueta: "Próximo cambio cada (km)", texto: $intervalo, placeholder: "Ej: 3000",
                           teclado: .numberPad,
                           ayuda: "Ej: 3000 → el próximo cambio será al kilometraje + 3.000.",
                           error: errores["intervalo_km"])
            }
            Section {
                CampoNotas(texto: $notas, error: errores["notas"])
            }
        }
        .marcoFormulario(titulo(.aceite, nuevo: original == nil), guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let fechaV = v.fecha("fecha", fecha, "Fecha", noFuturo: true)
        let kmV = v.entero("km", km, "Kilometraje (km)", requerido: true, minimo: 0, maximo: Reglas.kmMax)
        let marcaV = v.texto("marca", marca, "Marca del aceite", requerido: true)
        let viscV = v.texto("viscosidad", viscosidad, "Tipo / viscosidad", requerido: true, maxLen: 20)
        let cantidadV = v.decimal("cantidad", cantidad, "Cantidad utilizada (litros)", minimo: 0.1, maximo: 20)
        let valorV = v.entero("valor", valor, "Valor ($)", minimo: 0, maximo: 10_000_000)
        let lugarV = v.texto("lugar", lugar, "Taller o lugar")
        let intervaloV = v.entero("intervalo_km", intervalo, "Próximo cambio cada (km)", requerido: true,
                                  minimo: 100, maximo: 20_000)
        let notasV = v.texto("notas", notas, "Notas", maxLen: 500)
        errores = v.errores
        guard v.ok, let f = fechaV, let k = kmV, let m = marcaV, let vis = viscV, let i = intervaloV else { return }
        let a = Aceite(id: original?.id ?? 0, fecha: f, km: k, marca: m, viscosidad: vis, cantidad: cantidadV,
                       valor: valorV, lugar: lugarV, intervaloKm: i, notas: notasV)
        if store.guardar(a, en: \.aceite) {
            store.formulario = nil
            store.avisar(Seccion.aceite.mensajeGuardado)
        }
    }
}

// MARK: - SOAT

struct SoatForm: View {
    @EnvironmentObject var store: Store
    let original: Soat?

    @State private var expedicion: Date
    @State private var vencimiento: Date
    @State private var numero: String
    @State private var aseguradora: String
    @State private var notas: String
    @State private var errores: [String: String] = [:]

    init(original: Soat?) {
        self.original = original
        let exp = Fechas.desdeISO(original?.fechaExpedicion) ?? Date()
        _expedicion = State(initialValue: exp)
        _vencimiento = State(initialValue: Fechas.desdeISO(original?.fechaVencimiento) ?? Fechas.sumarAnios(1, a: exp))
        _numero = State(initialValue: original?.numero ?? "")
        _aseguradora = State(initialValue: original?.aseguradora ?? "")
        _notas = State(initialValue: original?.notas ?? "")
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoFecha(etiqueta: "Fecha de expedición", fecha: $expedicion, noFuturo: true,
                           error: errores["fecha_expedicion"])
                CampoFecha(etiqueta: "Fecha de vencimiento", fecha: $vencimiento,
                           error: errores["fecha_vencimiento"])
                CampoTexto(etiqueta: "Número del SOAT", texto: $numero, placeholder: "Opcional",
                           error: errores["numero"])
                CampoTexto(etiqueta: "Entidad aseguradora", texto: $aseguradora, placeholder: "Opcional",
                           error: errores["aseguradora"])
            }
            Section {
                CampoNotas(texto: $notas, error: errores["notas"])
            }
        }
        .marcoFormulario(titulo(.soat, nuevo: original == nil), guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let expV = v.fecha("fecha_expedicion", expedicion, "Fecha de expedición", noFuturo: true)
        let venV = v.fecha("fecha_vencimiento", vencimiento, "Fecha de vencimiento")
        let numeroV = v.texto("numero", numero, "Número del SOAT", maxLen: 50)
        let asegV = v.texto("aseguradora", aseguradora, "Entidad aseguradora")
        let notasV = v.texto("notas", notas, "Notas", maxLen: 500)
        v.noMenorQue("fecha_vencimiento", venV, expV, "Fecha de vencimiento", "Fecha de expedición")
        errores = v.errores
        guard v.ok, let e = expV, let ve = venV else { return }
        let s = Soat(id: original?.id ?? 0, fechaExpedicion: e, fechaVencimiento: ve, numero: numeroV,
                     aseguradora: asegV, notas: notasV)
        if store.guardar(s, en: \.soat) {
            store.formulario = nil
            store.avisar(Seccion.soat.mensajeGuardado)
        }
    }
}

// MARK: - Tecnomecánica

struct TecnoForm: View {
    @EnvironmentObject var store: Store
    let original: Tecnomecanica?

    @State private var realizacion: Date
    @State private var vencimiento: Date
    @State private var numero: String
    @State private var centro: String
    @State private var km: String
    @State private var notas: String
    @State private var errores: [String: String] = [:]

    init(original: Tecnomecanica?, kmActual: Int) {
        self.original = original
        let real = Fechas.desdeISO(original?.fechaRealizacion) ?? Date()
        _realizacion = State(initialValue: real)
        _vencimiento = State(initialValue: Fechas.desdeISO(original?.fechaVencimiento) ?? Fechas.sumarAnios(1, a: real))
        _numero = State(initialValue: original?.numero ?? "")
        _centro = State(initialValue: original?.centro ?? "")
        _km = State(initialValue: original == nil ? textoKm(kmActual) : (original?.km.map { String($0) } ?? ""))
        _notas = State(initialValue: original?.notas ?? "")
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoFecha(etiqueta: "Fecha de realización", fecha: $realizacion, noFuturo: true,
                           error: errores["fecha_realizacion"])
                CampoFecha(etiqueta: "Fecha de vencimiento", fecha: $vencimiento,
                           error: errores["fecha_vencimiento"])
                CampoTexto(etiqueta: "Número del certificado", texto: $numero, placeholder: "Opcional",
                           error: errores["numero"])
                CampoTexto(etiqueta: "Centro de revisión", texto: $centro, placeholder: "Opcional",
                           error: errores["centro"])
                CampoTexto(etiqueta: "Kilometraje (km)", texto: $km, placeholder: "Opcional",
                           teclado: .numberPad, error: errores["km"])
            }
            Section {
                CampoNotas(texto: $notas, error: errores["notas"])
            }
        }
        .marcoFormulario(titulo(.tecnomecanica, nuevo: original == nil), guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let realV = v.fecha("fecha_realizacion", realizacion, "Fecha de realización", noFuturo: true)
        let venV = v.fecha("fecha_vencimiento", vencimiento, "Fecha de vencimiento")
        let numeroV = v.texto("numero", numero, "Número del certificado", maxLen: 50)
        let centroV = v.texto("centro", centro, "Centro de revisión")
        let kmV = v.entero("km", km, "Kilometraje (km)", minimo: 0, maximo: Reglas.kmMax)
        let notasV = v.texto("notas", notas, "Notas", maxLen: 500)
        v.noMenorQue("fecha_vencimiento", venV, realV, "Fecha de vencimiento", "Fecha de realización")
        errores = v.errores
        guard v.ok, let r = realV, let ve = venV else { return }
        let t = Tecnomecanica(id: original?.id ?? 0, fechaRealizacion: r, fechaVencimiento: ve, numero: numeroV,
                              centro: centroV, km: kmV, notas: notasV)
        if store.guardar(t, en: \.tecnomecanica) {
            store.formulario = nil
            store.avisar(Seccion.tecnomecanica.mensajeGuardado)
        }
    }
}

// MARK: - Mantenimiento

struct MantenimientoForm: View {
    @EnvironmentObject var store: Store
    let original: Mantenimiento?

    @State private var nombre: String
    @State private var fecha: Date?
    @State private var km: String
    @State private var proximaFecha: Date?
    @State private var proximoKm: String
    @State private var costo: String
    @State private var notas: String
    @State private var errores: [String: String] = [:]

    init(original: Mantenimiento?) {
        self.original = original
        _nombre = State(initialValue: original?.nombre ?? "")
        _fecha = State(initialValue: Fechas.desdeISO(original?.fecha))
        _km = State(initialValue: original?.km.map { String($0) } ?? "")
        _proximaFecha = State(initialValue: Fechas.desdeISO(original?.proximaFecha))
        _proximoKm = State(initialValue: original?.proximoKm.map { String($0) } ?? "")
        _costo = State(initialValue: original?.costo.map { String($0) } ?? "")
        _notas = State(initialValue: original?.notas ?? "")
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoTexto(etiqueta: "Nombre del mantenimiento", texto: $nombre, placeholder: "Ej: Cambio de bujía",
                           sugerencias: Reglas.mantenimientosComunes,
                           ayuda: "Elige uno de la lista o escribe el tuyo.", error: errores["nombre"])
            }
            Section {
                CampoFechaOpcional(etiqueta: "Fecha en que se hizo", fecha: $fecha, noFuturo: true,
                                   error: errores["fecha"])
                CampoTexto(etiqueta: "Kilometraje en que se hizo (km)", texto: $km, placeholder: "Opcional",
                           teclado: .numberPad, error: errores["km"])
            } header: {
                Text("Último realizado")
            }
            Section {
                CampoFechaOpcional(etiqueta: "Próxima fecha", fecha: $proximaFecha,
                                   error: errores["proxima_fecha"])
                CampoTexto(etiqueta: "Próximo kilometraje (km)", texto: $proximoKm, placeholder: "Opcional",
                           teclado: .numberPad, error: errores["proximo_km"])
            } header: {
                Text("Próximo")
            } footer: {
                Text("Indica al menos una fecha o un kilometraje.")
            }
            Section {
                CampoTexto(etiqueta: "Costo ($)", texto: $costo, placeholder: "Opcional",
                           teclado: .numberPad, error: errores["costo"])
                CampoNotas(texto: $notas, error: errores["notas"])
            }
        }
        .marcoFormulario(titulo(.mantenimientos, nuevo: original == nil), guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let nombreV = v.texto("nombre", nombre, "Nombre del mantenimiento", requerido: true)
        let fechaV = v.fecha("fecha", fecha, "Fecha en que se hizo", noFuturo: true)
        let kmV = v.entero("km", km, "Kilometraje en que se hizo (km)", minimo: 0, maximo: Reglas.kmMax)
        let proxFechaV = v.fecha("proxima_fecha", proximaFecha, "Próxima fecha")
        let proxKmV = v.entero("proximo_km", proximoKm, "Próximo kilometraje (km)", minimo: 0, maximo: Reglas.kmMax)
        let costoV = v.entero("costo", costo, "Costo ($)", minimo: 0, maximo: 10_000_000)
        let notasV = v.texto("notas", notas, "Notas", maxLen: 500)
        v.noMenorQue("proxima_fecha", proxFechaV, fechaV, "Próxima fecha", "Fecha en que se hizo")
        v.mayorQue("proximo_km", proxKmV, kmV, "Próximo kilometraje (km)", "Kilometraje en que se hizo (km)")
        if v.ok && fechaV == nil && kmV == nil && proxFechaV == nil && proxKmV == nil {
            v.error("_general", "Indica al menos una fecha o un kilometraje.")
        }
        errores = v.errores
        guard v.ok, let n = nombreV else { return }
        let m = Mantenimiento(id: original?.id ?? 0, nombre: n, fecha: fechaV, km: kmV, proximaFecha: proxFechaV,
                              proximoKm: proxKmV, costo: costoV, notas: notasV,
                              completado: original?.completado ?? false)
        if store.guardar(m, en: \.mantenimientos) {
            store.formulario = nil
            store.avisar(Seccion.mantenimientos.mensajeGuardado)
        }
    }
}

// MARK: - Información de la moto

struct MotoForm: View {
    @EnvironmentObject var store: Store

    @State private var marca: String
    @State private var modelo: String
    @State private var anio: String
    @State private var placa: String
    @State private var km: String
    @State private var errores: [String: String] = [:]

    init(original: Moto) {
        _marca = State(initialValue: original.marca)
        _modelo = State(initialValue: original.modelo)
        _anio = State(initialValue: original.anio.map { String($0) } ?? "")
        _placa = State(initialValue: original.placa)
        _km = State(initialValue: String(original.kmActual))
    }

    var body: some View {
        Form {
            ErrorGeneral(errores: errores)
            Section {
                CampoTexto(etiqueta: "Marca", texto: $marca, placeholder: "Ej: Honda", error: errores["marca"])
                CampoTexto(etiqueta: "Modelo", texto: $modelo, placeholder: "Ej: CB 125F", error: errores["modelo"])
                CampoTexto(etiqueta: "Año", texto: $anio, placeholder: "Ej: 2024", teclado: .numberPad,
                           error: errores["anio"])
                CampoTexto(etiqueta: "Placa", texto: $placa, placeholder: "Ej: ABC12D", mayusculas: true,
                           error: errores["placa"])
                CampoTexto(etiqueta: "Kilometraje actual (km)", texto: $km, teclado: .numberPad,
                           ayuda: "También sube solo cuando registras un tanqueo, aceite o mantenimiento con más km.",
                           error: errores["km_actual"])
            }
        }
        .marcoFormulario("Información de la moto", guardar: guardar)
    }

    private func guardar() {
        var v = Validador()
        let marcaV = v.texto("marca", marca, "Marca", requerido: true, maxLen: 50)
        let modeloV = v.texto("modelo", modelo, "Modelo", requerido: true, maxLen: 50)
        let anioV = v.entero("anio", anio, "Año", requerido: true, minimo: 1950, maximo: Fechas.anioActual + 1)
        let placaV = v.texto("placa", placa, "Placa", requerido: true, maxLen: 10, mayusculas: true)
        let kmV = v.entero("km_actual", km, "Kilometraje actual (km)", requerido: true, minimo: 0, maximo: Reglas.kmMax)
        errores = v.errores
        guard v.ok, let ma = marcaV, let mo = modeloV, let a = anioV, let p = placaV, let k = kmV else { return }
        var moto = Moto()
        moto.marca = ma
        moto.modelo = mo
        moto.anio = a
        moto.placa = p
        moto.kmActual = k
        if store.guardarMoto(moto) {
            store.formulario = nil
            store.avisar("Información de la moto actualizada.")
        }
    }
}
