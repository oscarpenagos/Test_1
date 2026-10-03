import Foundation

// MARK: - Estados (verde / amarillo / rojo)

enum Nivel: Int, Comparable {
    case bad = 0, warn, ok, none, done

    static func < (a: Nivel, b: Nivel) -> Bool { a.rawValue < b.rawValue }
}

struct Estado: Equatable {
    var nivel: Nivel
    var texto: String
    var dias: Int? = nil
    var restante: Int? = nil
}

/// Secciones de la app (cada una es una tabla de la versión de escritorio).
enum Seccion: String, CaseIterable, Identifiable {
    case tanqueos, aceite, soat, tecnomecanica, mantenimientos

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .tanqueos: return "Tanqueos"
        case .aceite: return "Cambios de aceite"
        case .soat: return "SOAT"
        case .tecnomecanica: return "Tecnomecánica"
        case .mantenimientos: return "Mantenimientos"
        }
    }

    /// Para mensajes: "Tanqueo guardado correctamente."
    var singular: String {
        switch self {
        case .tanqueos: return "Tanqueo"
        case .aceite: return "Cambio de aceite"
        case .soat: return "SOAT"
        case .tecnomecanica: return "Tecnomecánica"
        case .mantenimientos: return "Mantenimiento"
        }
    }

    /// Para títulos: "Agregar tanqueo", "Editar SOAT"
    var singularMin: String {
        switch self {
        case .tanqueos: return "tanqueo"
        case .aceite: return "cambio de aceite"
        case .soat: return "SOAT"
        case .tecnomecanica: return "tecnomecánica"
        case .mantenimientos: return "mantenimiento"
        }
    }

    var nombreTipo: String {
        switch self {
        case .tanqueos: return "Tanqueo"
        case .aceite: return "Aceite"
        case .soat: return "SOAT"
        case .tecnomecanica: return "Tecnomecánica"
        case .mantenimientos: return "Mantenimiento"
        }
    }

    var icono: String {
        switch self {
        case .tanqueos: return "fuelpump.fill"
        case .aceite: return "drop.fill"
        case .soat: return "doc.text.fill"
        case .tecnomecanica: return "checkmark.seal.fill"
        case .mantenimientos: return "wrench.and.screwdriver.fill"
        }
    }

    var textoAccion: String {
        switch self {
        case .tanqueos: return "Agregar tanqueo"
        case .aceite: return "Registrar cambio de aceite"
        case .soat: return "Actualizar SOAT"
        case .tecnomecanica: return "Actualizar tecnomecánica"
        case .mantenimientos: return "Agregar mantenimiento"
        }
    }

    var mensajeGuardado: String {
        self == .tecnomecanica ? "Tecnomecánica guardada correctamente." : "\(singular) guardado correctamente."
    }
}

// MARK: - Reglas de negocio (equivalentes a servicios.py)

enum Reglas {
    static let diasAviso = 30   // amarillo si faltan 30 días o menos
    static let kmAviso = 500    // amarillo si faltan 500 km o menos
    static let kmMax = 2_000_000

    static let viscosidades = ["10W30", "10W40", "10W50", "15W50", "20W50", "5W30", "5W40"]
    static let mantenimientosComunes = [
        "Cambio de aceite", "Cambio de filtro", "Cambio de bujía", "Revisión de frenos",
        "Cambio de pastillas", "Cambio de llantas", "Revisión de cadena", "Lubricación de cadena",
    ]

    static func plural(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    static func nivelDias(_ dias: Int) -> Nivel {
        if dias < 0 { return .bad }
        return dias <= diasAviso ? .warn : .ok
    }

    static func nivelKm(_ restante: Int) -> Nivel {
        if restante < 0 { return .bad }
        return restante <= kmAviso ? .warn : .ok
    }

    static func estadoVencimiento(_ fecha: String?) -> Estado {
        guard let dias = Fechas.diasHasta(fecha) else {
            return Estado(nivel: .none, texto: "Sin registro")
        }
        let nivel = nivelDias(dias)
        let texto: String
        if dias < 0 {
            texto = "Vencido — venció hace \(plural(-dias, "día", "días"))"
        } else if dias == 0 {
            texto = "Vence hoy"
        } else if nivel == .warn {
            texto = "Próximo a vencer — faltan \(plural(dias, "día", "días"))"
        } else {
            texto = "Vigente — faltan \(plural(dias, "día", "días"))"
        }
        return Estado(nivel: nivel, texto: texto, dias: dias)
    }

    static func estadoAceite(_ ultimo: Aceite?, km: Int) -> Estado {
        guard let u = ultimo else {
            return Estado(nivel: .none, texto: "Aún no hay cambios registrados")
        }
        let restante = u.proximoKm - km
        let nivel = nivelKm(restante)
        let texto: String
        if restante < 0 {
            texto = "Atrasado — te pasaste por \(Fmt.km(-restante))"
        } else if nivel == .warn {
            texto = "Próximo cambio — faltan \(Fmt.km(restante))"
        } else {
            texto = "Al día — faltan \(Fmt.km(restante))"
        }
        return Estado(nivel: nivel, texto: texto, restante: restante)
    }

    static func estadoMantenimiento(_ m: Mantenimiento, km: Int) -> Estado {
        if m.completado { return Estado(nivel: .done, texto: "Realizado") }
        var niveles: [Nivel] = []
        var textos: [String] = []
        if let dias = Fechas.diasHasta(m.proximaFecha) {
            niveles.append(nivelDias(dias))
            if dias < 0 {
                textos.append("atrasado \(plural(-dias, "día", "días"))")
            } else if dias == 0 {
                textos.append("es hoy")
            } else {
                textos.append("faltan \(plural(dias, "día", "días"))")
            }
        }
        if let proximo = m.proximoKm {
            let restante = proximo - km
            niveles.append(nivelKm(restante))
            let cifra = Fmt.km(abs(restante))
            textos.append(restante < 0 ? "atrasado \(cifra)" : "faltan \(cifra)")
        }
        guard let peor = niveles.min() else {
            return Estado(nivel: .none, texto: "Sin próximo mantenimiento programado")
        }
        return Estado(nivel: peor, texto: capitalizar(textos.joined(separator: " · ")))
    }

    static func capitalizar(_ s: String) -> String {
        guard let primera = s.first else { return s }
        return primera.uppercased() + s.dropFirst()
    }
}

// MARK: - Datos calculados

struct TanqueoCalc: Identifiable {
    let t: Tanqueo
    var precioLitro: Double?
    var difKm: Int?
    var consumo: Double?
    var id: Int { t.id }
}

struct ResumenTanqueos {
    var consumoProm: Double?
    var totalGastado: Int
    var totalLitros: Double
}

struct MantenimientoCalc: Identifiable {
    let m: Mantenimiento
    let estado: Estado
    var id: Int { m.id }
}

struct ItemHistorial: Identifiable {
    let fecha: String
    let tipo: Seccion
    let regId: Int
    let titulo: String
    let detalle: String
    var id: String { "\(tipo.rawValue):\(regId)" }
}

struct FilaLista: Identifiable {
    let id: Int
    let titulo: String
    let subtitulo: String
    let derecha: String
    let estado: Estado?
}

struct Linea: Identifiable {
    let etiqueta: String
    let valor: String
    var id: String { etiqueta }
}
