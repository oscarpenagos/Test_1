import Foundation

// MARK: - Registros
//
// Los nombres de los campos en JSON son los mismos que usa la versión de
// escritorio (Python), así un respaldo exportado en el computador se puede
// importar en el iPhone y viceversa.

protocol Registro: Codable, Identifiable where ID == Int {
    var id: Int { get set }
    /// Kilometraje del registro; si es mayor al actual, sube el de la moto.
    var kmRegistrado: Int? { get }
}

struct Moto: Codable, Equatable {
    var marca: String = ""
    var modelo: String = ""
    var anio: Int? = nil
    var placa: String = ""
    var kmActual: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, marca, modelo, anio, placa
        case kmActual = "km_actual"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        marca = c.texto(.marca) ?? ""
        modelo = c.texto(.modelo) ?? ""
        anio = c.entero(.anio)
        placa = c.texto(.placa) ?? ""
        kmActual = c.entero(.kmActual) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .id)
        try c.encode(marca, forKey: .marca)
        try c.encode(modelo, forKey: .modelo)
        try c.encode(anio, forKey: .anio)
        try c.encode(placa, forKey: .placa)
        try c.encode(kmActual, forKey: .kmActual)
    }

    var nombre: String {
        let m = marca.isEmpty ? "Sin marca" : marca
        return "\(m) \(modelo)".trimmingCharacters(in: .whitespaces)
    }
}

struct Tanqueo: Registro, Equatable {
    var id: Int
    var fecha: String          // aaaa-mm-dd
    var km: Int
    var litros: Double
    var valor: Int
    var estacion: String?
    var notas: String?

    enum CodingKeys: String, CodingKey {
        case id, fecha, km, litros, valor, estacion, notas
    }

    var kmRegistrado: Int? { km }
}

extension Tanqueo {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.entero(.id) ?? 0
        fecha = try c.obligatorio(c.texto(.fecha), .fecha)
        km = try c.obligatorio(c.entero(.km), .km)
        litros = try c.obligatorio(c.decimal(.litros), .litros)
        valor = try c.obligatorio(c.entero(.valor), .valor)
        estacion = c.texto(.estacion)
        notas = c.texto(.notas)
    }
}

struct Aceite: Registro, Equatable {
    var id: Int
    var fecha: String
    var km: Int
    var marca: String
    var viscosidad: String
    var cantidad: Double?
    var valor: Int?
    var lugar: String?
    var intervaloKm: Int
    var notas: String?

    enum CodingKeys: String, CodingKey {
        case id, fecha, km, marca, viscosidad, cantidad, valor, lugar, notas
        case intervaloKm = "intervalo_km"
    }

    var kmRegistrado: Int? { km }
    var proximoKm: Int { km + intervaloKm }
}

extension Aceite {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.entero(.id) ?? 0
        fecha = try c.obligatorio(c.texto(.fecha), .fecha)
        km = try c.obligatorio(c.entero(.km), .km)
        marca = c.texto(.marca) ?? ""
        viscosidad = c.texto(.viscosidad) ?? ""
        cantidad = c.decimal(.cantidad)
        valor = c.entero(.valor)
        lugar = c.texto(.lugar)
        intervaloKm = c.entero(.intervaloKm) ?? 3000
        notas = c.texto(.notas)
    }
}

struct Soat: Registro, Equatable {
    var id: Int
    var fechaExpedicion: String
    var fechaVencimiento: String
    var numero: String?
    var aseguradora: String?
    var notas: String?

    enum CodingKeys: String, CodingKey {
        case id, numero, aseguradora, notas
        case fechaExpedicion = "fecha_expedicion"
        case fechaVencimiento = "fecha_vencimiento"
    }

    var kmRegistrado: Int? { nil }
}

extension Soat {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.entero(.id) ?? 0
        fechaExpedicion = try c.obligatorio(c.texto(.fechaExpedicion), .fechaExpedicion)
        fechaVencimiento = try c.obligatorio(c.texto(.fechaVencimiento), .fechaVencimiento)
        numero = c.texto(.numero)
        aseguradora = c.texto(.aseguradora)
        notas = c.texto(.notas)
    }
}

struct Tecnomecanica: Registro, Equatable {
    var id: Int
    var fechaRealizacion: String
    var fechaVencimiento: String
    var numero: String?
    var centro: String?
    var km: Int?
    var notas: String?

    enum CodingKeys: String, CodingKey {
        case id, numero, centro, km, notas
        case fechaRealizacion = "fecha_realizacion"
        case fechaVencimiento = "fecha_vencimiento"
    }

    var kmRegistrado: Int? { km }
}

extension Tecnomecanica {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.entero(.id) ?? 0
        fechaRealizacion = try c.obligatorio(c.texto(.fechaRealizacion), .fechaRealizacion)
        fechaVencimiento = try c.obligatorio(c.texto(.fechaVencimiento), .fechaVencimiento)
        numero = c.texto(.numero)
        centro = c.texto(.centro)
        km = c.entero(.km)
        notas = c.texto(.notas)
    }
}

struct Mantenimiento: Registro, Equatable {
    var id: Int
    var nombre: String
    var fecha: String?
    var km: Int?
    var proximaFecha: String?
    var proximoKm: Int?
    var costo: Int?
    var notas: String?
    var completado: Bool

    enum CodingKeys: String, CodingKey {
        case id, nombre, fecha, km, costo, notas, completado
        case proximaFecha = "proxima_fecha"
        case proximoKm = "proximo_km"
    }

    var kmRegistrado: Int? { km }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(fecha, forKey: .fecha)
        try c.encode(km, forKey: .km)
        try c.encode(proximaFecha, forKey: .proximaFecha)
        try c.encode(proximoKm, forKey: .proximoKm)
        try c.encode(costo, forKey: .costo)
        try c.encode(notas, forKey: .notas)
        try c.encode(completado ? 1 : 0, forKey: .completado)
    }
}

extension Mantenimiento {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.entero(.id) ?? 0
        nombre = try c.obligatorio(c.texto(.nombre), .nombre)
        fecha = c.texto(.fecha)
        km = c.entero(.km)
        proximaFecha = c.texto(.proximaFecha)
        proximoKm = c.entero(.proximoKm)
        costo = c.entero(.costo)
        notas = c.texto(.notas)
        if let n = c.entero(.completado) {
            completado = n != 0
        } else if let b = try? c.decodeIfPresent(Bool.self, forKey: .completado) {
            completado = b
        } else {
            completado = false
        }
    }
}

// MARK: - Base de datos completa

struct BaseDatos: Equatable {
    var moto = Moto()
    var tanqueos: [Tanqueo] = []
    var aceite: [Aceite] = []
    var soat: [Soat] = []
    var tecnomecanica: [Tecnomecanica] = []
    var mantenimientos: [Mantenimiento] = []

    var totalRegistros: Int {
        1 + tanqueos.count + aceite.count + soat.count + tecnomecanica.count + mantenimientos.count
    }
}

// MARK: - Decodificación tolerante
//
// Acepta números escritos como texto o con decimales (por ejemplo 3000.0),
// igual que SQLite en la versión de escritorio.

extension KeyedDecodingContainer {
    /// Números absurdamente grandes se descartan (evita desbordes con archivos dañados).
    func entero(_ key: Key) -> Int? {
        let limite = 1_000_000_000_000
        func razonable(_ n: Int?) -> Int? {
            guard let n = n, n > -limite, n < limite else { return nil }
            return n
        }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return razonable(v) }
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite, abs(v) < 1e12 {
            return Int(v.rounded())
        }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            return razonable(Int(s.trimmingCharacters(in: .whitespaces)))
        }
        return nil
    }

    func decimal(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func texto(_ key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        return nil
    }

    func obligatorio<T>(_ valor: T?, _ key: Key) throws -> T {
        guard let v = valor else {
            throw DecodingError.keyNotFound(
                key, DecodingError.Context(codingPath: codingPath, debugDescription: "Falta \(key.stringValue)"))
        }
        return v
    }
}
