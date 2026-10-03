import Foundation

/// Validación y conversión de los datos de los formularios (equivale a validators.py).
/// Acepta números como 24.580, $35.000 o 8,5.
struct Validador {
    private(set) var errores: [String: String] = [:]
    var ok: Bool { errores.isEmpty }

    mutating func error(_ campo: String, _ mensaje: String) {
        if errores[campo] == nil { errores[campo] = mensaje }
    }

    /// Años sin punto (2027); cantidades grandes con punto (2.000.000).
    private func cifra(_ n: Int) -> String {
        n >= 10_000 ? Fmt.numero(n) : String(n)
    }

    private func limpiar(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func texto(_ campo: String, _ crudo: String, _ etiqueta: String,
                        requerido: Bool = false, maxLen: Int = 100, mayusculas: Bool = false) -> String? {
        let t = limpiar(crudo)
        if t.isEmpty {
            if requerido { error(campo, "\(etiqueta) es obligatorio.") }
            return nil
        }
        if t.count > maxLen {
            error(campo, "\(etiqueta): máximo \(maxLen) caracteres.")
            return nil
        }
        return mayusculas ? t.uppercased() : t
    }

    mutating func entero(_ campo: String, _ crudo: String, _ etiqueta: String,
                         requerido: Bool = false, minimo: Int? = nil, maximo: Int? = nil) -> Int? {
        let t = limpiar(crudo)
        if t.isEmpty {
            if requerido { error(campo, "\(etiqueta) es obligatorio.") }
            return nil
        }
        if t.hasPrefix("-") {
            error(campo, "\(etiqueta): no se permiten valores negativos.")
            return nil
        }
        let separadores: Set<Character> = [".", ",", "$"]
        let sinSeparadores = t.filter { !separadores.contains($0) && !$0.isWhitespace }
        guard !sinSeparadores.isEmpty,
              sinSeparadores.allSatisfy({ $0.isASCII && $0.isNumber }),
              let n = Int(sinSeparadores) else {
            error(campo, "\(etiqueta): escribe solo números enteros (sin letras).")
            return nil
        }
        let bajo = minimo.map { n < $0 } ?? false
        let alto = maximo.map { n > $0 } ?? false
        if bajo || alto {
            error(campo, "\(etiqueta): debe estar entre \(cifra(minimo ?? 0)) y \(cifra(maximo ?? 0)).")
            return nil
        }
        return n
    }

    mutating func decimal(_ campo: String, _ crudo: String, _ etiqueta: String,
                          requerido: Bool = false, minimo: Double? = nil, maximo: Double? = nil) -> Double? {
        let t = limpiar(crudo)
        if t.isEmpty {
            if requerido { error(campo, "\(etiqueta) es obligatorio.") }
            return nil
        }
        if t.hasPrefix("-") {
            error(campo, "\(etiqueta): no se permiten valores negativos.")
            return nil
        }
        let normal = t.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
        guard let n = Double(normal), n.isFinite else {
            error(campo, "\(etiqueta): escribe un número, por ejemplo 8,5.")
            return nil
        }
        let r = (n * 100).rounded() / 100
        let bajo = minimo.map { r < $0 } ?? false
        let alto = maximo.map { r > $0 } ?? false
        if bajo || alto {
            error(campo, "\(etiqueta): debe estar entre \(Fmt.decimal(minimo ?? 0, 2)) y \(Fmt.decimal(maximo ?? 0, 2)).")
            return nil
        }
        return r
    }

    mutating func fecha(_ campo: String, _ valor: Date?, _ etiqueta: String, noFuturo: Bool = false) -> String? {
        guard let valor = valor else { return nil }
        let iso = Fechas.iso(valor)
        let anio = Int(iso.prefix(4)) ?? 0
        if anio < 1990 || anio > 2100 {
            error(campo, "\(etiqueta): el año debe estar entre 1990 y 2100.")
            return nil
        }
        if noFuturo && iso > Fechas.hoyISO {
            error(campo, "\(etiqueta): no puede ser una fecha futura.")
            return nil
        }
        return iso
    }

    /// La fecha `a` debe ser igual o posterior a `b`.
    mutating func noMenorQue(_ campo: String, _ a: String?, _ b: String?, _ etiquetaA: String, _ etiquetaB: String) {
        if let a = a, let b = b, a < b {
            error(campo, "\(etiquetaA) debe ser igual o posterior a «\(etiquetaB)».")
        }
    }

    /// El número `a` debe ser mayor que `b`.
    mutating func mayorQue(_ campo: String, _ a: Int?, _ b: Int?, _ etiquetaA: String, _ etiquetaB: String) {
        if let a = a, let b = b, a <= b {
            error(campo, "\(etiquetaA) debe ser mayor que «\(etiquetaB)».")
        }
    }
}
