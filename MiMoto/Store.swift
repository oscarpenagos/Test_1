import Foundation
import SwiftUI

/// Formularios que se pueden abrir desde cualquier pantalla.
enum Formulario: Identifiable, Equatable {
    case moto
    case registro(Seccion, Int?)

    var id: String {
        switch self {
        case .moto: return "moto"
        case .registro(let s, let id): return "\(s.rawValue):\(id ?? 0)"
        }
    }
}

struct Aviso: Identifiable, Equatable {
    let id = UUID()
    let texto: String
    let error: Bool
}

/// Guarda los datos en el iPhone (archivo JSON en Documentos) y hace todos los cálculos.
final class Store: ObservableObject {
    @Published private(set) var db = BaseDatos()
    @Published var formulario: Formulario? = nil
    @Published var aviso: Aviso? = nil

    private let carpeta: URL
    private let archivo: URL

    init() {
        carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        archivo = carpeta.appendingPathComponent("moto.json")
        if FileManager.default.fileExists(atPath: archivo.path) {
            do {
                db = try Respaldo.decodificar(Data(contentsOf: archivo))
            } catch {
                // Conserva el archivo dañado para no perder nada.
                let copia = carpeta.appendingPathComponent("moto_danado_\(Fechas.marca("yyyyMMdd_HHmmss")).json")
                try? FileManager.default.copyItem(at: archivo, to: copia)
            }
        }
    }

    // MARK: Interfaz

    func abrir(_ f: Formulario) { formulario = f }

    func avisar(_ texto: String, error: Bool = false) {
        let nuevo = Aviso(texto: texto, error: error)
        aviso = nuevo
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            if self?.aviso?.id == nuevo.id { self?.aviso = nil }
        }
    }

    // MARK: Guardado

    private func escribir(_ datos: BaseDatos) throws {
        let data = try Respaldo.codificar(datos)
        try data.write(to: archivo, options: .atomic)
    }

    /// Escribe primero en disco y solo si funciona actualiza la pantalla.
    @discardableResult
    private func aplicar(_ nuevo: BaseDatos) -> Bool {
        do {
            try escribir(nuevo)
            db = nuevo
            return true
        } catch {
            avisar("No se pudieron guardar los datos. Intenta de nuevo.", error: true)
            return false
        }
    }

    @discardableResult
    func guardar<T: Registro>(_ item: T, en ruta: WritableKeyPath<BaseDatos, [T]>) -> Bool {
        var copia = db
        var nuevo = item
        if nuevo.id > 0, let i = copia[keyPath: ruta].firstIndex(where: { $0.id == nuevo.id }) {
            copia[keyPath: ruta][i] = nuevo
        } else {
            nuevo.id = (copia[keyPath: ruta].map { $0.id }.max() ?? 0) + 1
            copia[keyPath: ruta].append(nuevo)
        }
        if let km = nuevo.kmRegistrado, km > copia.moto.kmActual {
            copia.moto.kmActual = km
        }
        return aplicar(copia)
    }

    @discardableResult
    func guardarMoto(_ moto: Moto) -> Bool {
        var copia = db
        copia.moto = moto
        return aplicar(copia)
    }

    func eliminar(_ seccion: Seccion, id: Int) {
        var copia = db
        switch seccion {
        case .tanqueos: copia.tanqueos.removeAll { $0.id == id }
        case .aceite: copia.aceite.removeAll { $0.id == id }
        case .soat: copia.soat.removeAll { $0.id == id }
        case .tecnomecanica: copia.tecnomecanica.removeAll { $0.id == id }
        case .mantenimientos: copia.mantenimientos.removeAll { $0.id == id }
        }
        if aplicar(copia) { avisar("Registro eliminado.") }
    }

    func alternarRealizado(_ id: Int) {
        var copia = db
        guard let i = copia.mantenimientos.firstIndex(where: { $0.id == id }) else { return }
        copia.mantenimientos[i].completado.toggle()
        let realizado = copia.mantenimientos[i].completado
        if aplicar(copia) {
            avisar(realizado ? "Mantenimiento marcado como realizado." : "Mantenimiento reabierto.")
        }
    }

    // MARK: Búsquedas

    var kmActual: Int { db.moto.kmActual }

    func tanqueo(_ id: Int?) -> Tanqueo? { db.tanqueos.first { $0.id == id } }
    func aceite(_ id: Int?) -> Aceite? { db.aceite.first { $0.id == id } }
    func soat(_ id: Int?) -> Soat? { db.soat.first { $0.id == id } }
    func tecno(_ id: Int?) -> Tecnomecanica? { db.tecnomecanica.first { $0.id == id } }
    func mantenimiento(_ id: Int?) -> Mantenimiento? { db.mantenimientos.first { $0.id == id } }

    // MARK: Cálculos (servicios.py)

    /// Del más reciente al más antiguo, con precio por litro y consumo (km/l).
    /// El consumo se estima como los km recorridos desde el tanqueo anterior
    /// divididos entre los litros de este tanqueo (supone tanque lleno).
    var tanqueosCalc: [TanqueoCalc] {
        let orden = db.tanqueos.sorted { ($0.fecha, $0.km, $0.id) < ($1.fecha, $1.km, $1.id) }
        var resultado: [TanqueoCalc] = []
        var anterior: Tanqueo? = nil
        for t in orden {
            var c = TanqueoCalc(t: t, precioLitro: t.litros > 0 ? Double(t.valor) / t.litros : nil,
                                difKm: nil, consumo: nil)
            if let a = anterior, t.km > a.km {
                c.difKm = t.km - a.km
                c.consumo = t.litros > 0 ? Double(t.km - a.km) / t.litros : nil
            }
            resultado.append(c)
            anterior = t
        }
        return resultado.reversed()
    }

    func resumen(_ filas: [TanqueoCalc]) -> ResumenTanqueos {
        let consumos = filas.compactMap { $0.consumo }.filter { $0 > 0 }
        return ResumenTanqueos(
            consumoProm: consumos.isEmpty ? nil : consumos.reduce(0, +) / Double(consumos.count),
            totalGastado: filas.reduce(0) { $0 + $1.t.valor },
            totalLitros: filas.reduce(0.0) { $0 + $1.t.litros })
    }

    var aceitesOrdenados: [Aceite] {
        db.aceite.sorted { ($0.fecha, $0.km, $0.id) > ($1.fecha, $1.km, $1.id) }
    }

    var estadoAceite: Estado { Reglas.estadoAceite(aceitesOrdenados.first, km: kmActual) }

    var soatOrdenados: [Soat] {
        db.soat.sorted { ($0.fechaVencimiento, $0.id) > ($1.fechaVencimiento, $1.id) }
    }

    var tecnoOrdenados: [Tecnomecanica] {
        db.tecnomecanica.sorted { ($0.fechaVencimiento, $0.id) > ($1.fechaVencimiento, $1.id) }
    }

    /// Primero los atrasados, luego los próximos, al día, sin programar y realizados.
    var mantenimientosCalc: [MantenimientoCalc] {
        let km = kmActual
        return db.mantenimientos
            .map { MantenimientoCalc(m: $0, estado: Reglas.estadoMantenimiento($0, km: km)) }
            .sorted { ($0.estado.nivel.rawValue, -$0.m.id) < ($1.estado.nivel.rawValue, -$1.m.id) }
    }

    var alertas: [MantenimientoCalc] {
        mantenimientosCalc.filter { $0.estado.nivel == .bad || $0.estado.nivel == .warn }
    }

    // MARK: Listas de cada sección

    func filas(_ seccion: Seccion) -> [FilaLista] {
        switch seccion {
        case .tanqueos:
            return tanqueosCalc.map { c in
                FilaLista(id: c.id, titulo: Fmt.fecha(c.t.fecha),
                          subtitulo: "\(Fmt.decimal(c.t.litros, 2)) L · \(Fmt.moneda(c.t.valor)) · \(Fmt.km(c.t.km))",
                          derecha: c.consumo.map { "\(Fmt.decimal($0, 1)) km/l" } ?? "",
                          estado: nil)
            }
        case .aceite:
            let estado = estadoAceite
            return aceitesOrdenados.enumerated().map { (i, a) in
                FilaLista(id: a.id, titulo: "\(a.marca) \(a.viscosidad)",
                          subtitulo: "\(Fmt.fecha(a.fecha)) · \(Fmt.km(a.km))",
                          derecha: "Próx. \(Fmt.km(a.proximoKm))",
                          estado: i == 0 ? estado : nil)
            }
        case .soat:
            return soatOrdenados.map { s in
                let extra = [s.aseguradora, s.numero].compactMap { $0 }.filter { !$0.isEmpty }
                return FilaLista(id: s.id, titulo: "Vence \(Fmt.fecha(s.fechaVencimiento))",
                                 subtitulo: (["Expedido \(Fmt.fecha(s.fechaExpedicion))"] + extra).joined(separator: " · "),
                                 derecha: "", estado: Reglas.estadoVencimiento(s.fechaVencimiento))
            }
        case .tecnomecanica:
            return tecnoOrdenados.map { t in
                let extra = [t.centro, t.numero].compactMap { $0 }.filter { !$0.isEmpty }
                return FilaLista(id: t.id, titulo: "Vence \(Fmt.fecha(t.fechaVencimiento))",
                                 subtitulo: (["Realizada \(Fmt.fecha(t.fechaRealizacion))"] + extra).joined(separator: " · "),
                                 derecha: "", estado: Reglas.estadoVencimiento(t.fechaVencimiento))
            }
        case .mantenimientos:
            return mantenimientosCalc.map { c in
                var partes: [String] = []
                if let f = c.m.fecha { partes.append("Hecho \(Fmt.fecha(f))") }
                if let k = c.m.km { partes.append(Fmt.km(k)) }
                if let p = c.m.proximaFecha { partes.append("Próx. \(Fmt.fecha(p))") }
                if let p = c.m.proximoKm { partes.append("Próx. \(Fmt.km(p))") }
                return FilaLista(id: c.id, titulo: c.m.nombre, subtitulo: partes.joined(separator: " · "),
                                 derecha: c.m.costo.map { Fmt.moneda($0) } ?? "", estado: c.estado)
            }
        }
    }

    // MARK: Detalle de un registro

    func estado(_ seccion: Seccion, id: Int) -> Estado? {
        switch seccion {
        case .tanqueos: return nil
        case .aceite:
            return aceitesOrdenados.first?.id == id ? estadoAceite : nil
        case .soat: return soat(id).map { Reglas.estadoVencimiento($0.fechaVencimiento) }
        case .tecnomecanica: return tecno(id).map { Reglas.estadoVencimiento($0.fechaVencimiento) }
        case .mantenimientos: return mantenimiento(id).map { Reglas.estadoMantenimiento($0, km: kmActual) }
        }
    }

    func detalle(_ seccion: Seccion, id: Int) -> [Linea] {
        var l: [Linea] = []
        func add(_ etiqueta: String, _ valor: String?) {
            if let v = valor, !v.isEmpty, v != "—" { l.append(Linea(etiqueta: etiqueta, valor: v)) }
        }
        switch seccion {
        case .tanqueos:
            guard let c = tanqueosCalc.first(where: { $0.id == id }) else { return [] }
            let t = c.t
            add("Fecha", Fmt.fecha(t.fecha))
            add("Kilometraje", Fmt.km(t.km))
            add("Litros", "\(Fmt.decimal(t.litros, 2)) litros")
            add("Valor total", Fmt.moneda(t.valor))
            add("Estación de servicio", t.estacion)
            add("Precio por litro", Fmt.monedaD(c.precioLitro))
            add("Recorrido desde el anterior", c.difKm.map { Fmt.km($0) })
            add("Consumo aprox.", c.consumo.map { "\(Fmt.decimal($0, 1)) km/l" })
            add("Notas", t.notas)
        case .aceite:
            guard let a = aceite(id) else { return [] }
            add("Fecha", Fmt.fecha(a.fecha))
            add("Kilometraje", Fmt.km(a.km))
            add("Marca del aceite", a.marca)
            add("Tipo / viscosidad", a.viscosidad)
            add("Cantidad utilizada", a.cantidad.map { "\(Fmt.decimal($0, 2)) litros" })
            add("Valor", a.valor.map { Fmt.moneda($0) })
            add("Taller o lugar", a.lugar)
            add("Próximo cambio cada", Fmt.km(a.intervaloKm))
            add("Próximo cambio", Fmt.km(a.proximoKm))
            add("Notas", a.notas)
        case .soat:
            guard let s = soat(id) else { return [] }
            add("Fecha de expedición", Fmt.fecha(s.fechaExpedicion))
            add("Fecha de vencimiento", Fmt.fecha(s.fechaVencimiento))
            add("Número del SOAT", s.numero)
            add("Entidad aseguradora", s.aseguradora)
            add("Notas", s.notas)
        case .tecnomecanica:
            guard let t = tecno(id) else { return [] }
            add("Fecha de realización", Fmt.fecha(t.fechaRealizacion))
            add("Fecha de vencimiento", Fmt.fecha(t.fechaVencimiento))
            add("Número del certificado", t.numero)
            add("Centro de revisión", t.centro)
            add("Kilometraje", t.km.map { Fmt.km($0) })
            add("Notas", t.notas)
        case .mantenimientos:
            guard let m = mantenimiento(id) else { return [] }
            add("Mantenimiento", m.nombre)
            add("Fecha en que se hizo", m.fecha.map { Fmt.fecha($0) })
            add("Kilometraje en que se hizo", m.km.map { Fmt.km($0) })
            add("Próxima fecha", m.proximaFecha.map { Fmt.fecha($0) })
            add("Próximo kilometraje", m.proximoKm.map { Fmt.km($0) })
            add("Costo", m.costo.map { Fmt.moneda($0) })
            add("Notas", m.notas)
        }
        return l
    }

    // MARK: Historial

    func historial(_ tipo: Seccion?) -> [ItemHistorial] {
        var items: [ItemHistorial] = []
        if tipo == nil || tipo == .tanqueos {
            for c in tanqueosCalc {
                items.append(ItemHistorial(fecha: c.t.fecha, tipo: .tanqueos, regId: c.id,
                                           titulo: "Tanqueo · \(Fmt.decimal(c.t.litros, 2)) L",
                                           detalle: "\(Fmt.moneda(c.t.valor)) · \(Fmt.km(c.t.km))"))
            }
        }
        if tipo == nil || tipo == .aceite {
            for a in aceitesOrdenados {
                items.append(ItemHistorial(fecha: a.fecha, tipo: .aceite, regId: a.id,
                                           titulo: "Cambio de aceite · \(a.marca) \(a.viscosidad)",
                                           detalle: "\(Fmt.km(a.km)) · próximo a \(Fmt.km(a.proximoKm))"))
            }
        }
        if tipo == nil || tipo == .soat {
            for s in soatOrdenados {
                var detalle = "Vence \(Fmt.fecha(s.fechaVencimiento))"
                if let a = s.aseguradora, !a.isEmpty { detalle += " · \(a)" }
                items.append(ItemHistorial(fecha: s.fechaExpedicion, tipo: .soat, regId: s.id,
                                           titulo: "SOAT", detalle: detalle))
            }
        }
        if tipo == nil || tipo == .tecnomecanica {
            for t in tecnoOrdenados {
                var detalle = "Vence \(Fmt.fecha(t.fechaVencimiento))"
                if let c = t.centro, !c.isEmpty { detalle += " · \(c)" }
                items.append(ItemHistorial(fecha: t.fechaRealizacion, tipo: .tecnomecanica, regId: t.id,
                                           titulo: "Tecnomecánica", detalle: detalle))
            }
        }
        if tipo == nil || tipo == .mantenimientos {
            for c in mantenimientosCalc {
                guard let fecha = c.m.fecha ?? c.m.proximaFecha else { continue }
                var partes = [c.estado.texto]
                if let costo = c.m.costo, costo > 0 { partes.append(Fmt.moneda(costo)) }
                items.append(ItemHistorial(fecha: fecha, tipo: .mantenimientos, regId: c.id,
                                           titulo: c.m.nombre, detalle: partes.joined(separator: " · ")))
            }
        }
        return items.sorted { ($0.fecha, $0.regId) > ($1.fecha, $1.regId) }
    }

    // MARK: Copia de seguridad

    /// Crea el archivo JSON para compartir o guardar en Archivos.
    func archivoExportacion() throws -> URL {
        let data = try Respaldo.codificar(db)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("respaldo_moto_\(Fechas.marca("yyyyMMdd_HHmm")).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reemplaza todos los datos por los del respaldo. Valida todo antes de tocar
    /// nada y guarda una copia automática de los datos actuales en «copias».
    func importar(_ data: Data) throws -> Int {
        let nuevo = try Respaldo.decodificar(data)
        let copias = carpeta.appendingPathComponent("copias", isDirectory: true)
        try FileManager.default.createDirectory(at: copias, withIntermediateDirectories: true)
        let copia = copias.appendingPathComponent("copia_antes_de_importar_\(Fechas.marca("yyyyMMdd_HHmmss")).json")
        try Respaldo.codificar(db).write(to: copia, options: .atomic)
        try escribir(nuevo)
        db = nuevo
        return nuevo.totalRegistros
    }
}

// MARK: - Formato del respaldo (compatible con la versión de escritorio)

enum ErrorRespaldo: LocalizedError {
    case jsonInvalido
    case noValido
    case formato(String)
    case registro(String)

    var errorDescription: String? {
        switch self {
        case .jsonInvalido: return "No se pudo leer el archivo: no es un JSON válido."
        case .noValido: return "El archivo no es un respaldo válido de esta aplicación."
        case .formato(let t): return "Datos de «\(t)» con formato incorrecto."
        case .registro(let t): return "Hay un registro inválido en «\(t)». No se modificó nada."
        }
    }
}

enum Respaldo {
    private struct Archivo: Encodable {
        let app = "moto_app"
        let version = 1
        let exportado: String
        let datos: Datos
    }

    private struct Datos: Encodable {
        let moto: [Moto]
        let tanqueos: [Tanqueo]
        let aceite: [Aceite]
        let soat: [Soat]
        let tecnomecanica: [Tecnomecanica]
        let mantenimientos: [Mantenimiento]
    }

    static func codificar(_ db: BaseDatos) throws -> Data {
        let archivo = Archivo(
            exportado: Fechas.marca("yyyy-MM-dd'T'HH:mm:ss"),
            datos: Datos(moto: [db.moto], tanqueos: db.tanqueos, aceite: db.aceite, soat: db.soat,
                         tecnomecanica: db.tecnomecanica, mantenimientos: db.mantenimientos))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archivo)
    }

    static func decodificar(_ data: Data) throws -> BaseDatos {
        let objeto: Any
        do {
            objeto = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ErrorRespaldo.jsonInvalido
        }
        guard let raiz = objeto as? [String: Any],
              raiz["app"] as? String == "moto_app",
              let datos = raiz["datos"] as? [String: Any] else {
            throw ErrorRespaldo.noValido
        }

        func tabla<T: Decodable>(_ nombre: String, _ tipo: T.Type) throws -> [T] {
            guard let valor = datos[nombre], !(valor is NSNull) else { return [] }
            guard let filas = valor as? [Any] else { throw ErrorRespaldo.formato(nombre) }
            do {
                let d = try JSONSerialization.data(withJSONObject: filas)
                return try JSONDecoder().decode([T].self, from: d)
            } catch {
                throw ErrorRespaldo.registro(nombre)
            }
        }

        var db = BaseDatos()
        db.moto = try tabla("moto", Moto.self).first ?? Moto()
        db.tanqueos = try normalizar(tabla("tanqueos", Tanqueo.self))
        db.aceite = try normalizar(tabla("aceite", Aceite.self))
        db.soat = try normalizar(tabla("soat", Soat.self))
        db.tecnomecanica = try normalizar(tabla("tecnomecanica", Tecnomecanica.self))
        db.mantenimientos = try normalizar(tabla("mantenimientos", Mantenimiento.self))
        return db
    }

    /// Asigna un id a los registros que no lo tengan o lo tengan repetido.
    private static func normalizar<T: Registro>(_ filas: [T]) -> [T] {
        var vistos = Set<Int>()
        var siguiente = (filas.map { $0.id }.max() ?? 0) + 1
        return filas.map { fila in
            var f = fila
            if f.id <= 0 || vistos.contains(f.id) {
                f.id = siguiente
                siguiente += 1
            }
            vistos.insert(f.id)
            return f
        }
    }
}
