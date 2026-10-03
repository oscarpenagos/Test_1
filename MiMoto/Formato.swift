import Foundation

/// Fechas guardadas como texto "aaaa-mm-dd" (igual que la versión de escritorio).
enum Fechas {
    static var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }

    static func fecha(anio: Int, mes: Int, dia: Int) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia)) ?? Date()
    }

    static func iso(_ d: Date) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: d)
        return "\(relleno(c.year ?? 0, 4))-\(relleno(c.month ?? 1, 2))-\(relleno(c.day ?? 1, 2))"
    }

    static func desdeISO(_ texto: String?) -> Date? {
        guard let texto = texto else { return nil }
        let partes = texto.prefix(10).split(separator: "-")
        guard partes.count == 3,
              let a = Int(partes[0]), let m = Int(partes[1]), let d = Int(partes[2]) else { return nil }
        let cal = calendario
        guard let f = cal.date(from: DateComponents(year: a, month: m, day: d)) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: f)
        guard c.year == a, c.month == m, c.day == d else { return nil }
        return f
    }

    static var hoyISO: String { iso(Date()) }

    /// Días desde hoy hasta la fecha (negativo si ya pasó).
    static func diasHasta(_ texto: String?) -> Int? {
        guard let f = desdeISO(texto) else { return nil }
        let cal = calendario
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: f)).day
    }

    static func sumarAnios(_ n: Int, a d: Date) -> Date {
        calendario.date(byAdding: .year, value: n, to: d) ?? d
    }

    static func marca(_ formato: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendario
        f.dateFormat = formato
        return f.string(from: Date())
    }

    static var anioActual: Int { calendario.component(.year, from: Date()) }

    private static func relleno(_ n: Int, _ ancho: Int) -> String {
        let s = String(n)
        return String(repeating: "0", count: Swift.max(0, ancho - s.count)) + s
    }
}

/// Números, dinero y fechas en formato colombiano: 24.580 · $35.000 · 8,5 · 28/09/2026
enum Fmt {
    static func miles(_ v: Double, _ decimales: Int = 0) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSize = 3
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.minimumFractionDigits = decimales
        f.maximumFractionDigits = decimales
        f.roundingMode = .halfUp
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    static func numero(_ v: Int?) -> String {
        guard let v = v else { return "—" }
        return miles(Double(v))
    }

    static func km(_ v: Int?) -> String {
        guard let v = v else { return "—" }
        return miles(Double(v)) + " km"
    }

    static func moneda(_ v: Int?) -> String {
        guard let v = v else { return "—" }
        return "$" + miles(Double(v))
    }

    static func monedaD(_ v: Double?) -> String {
        guard let v = v, v.isFinite else { return "—" }
        return "$" + miles(v.rounded())
    }

    /// 8,50 -> "8,5"; 32,0 -> "32"
    static func decimal(_ v: Double?, _ n: Int = 1) -> String {
        guard let v = v, v.isFinite else { return "—" }
        var t = miles(v, n)
        if t.contains(",") {
            while t.hasSuffix("0") { t.removeLast() }
            if t.hasSuffix(",") { t.removeLast() }
        }
        return t
    }

    /// Texto para un campo editable: 8.5 -> "8,5"
    static func editable(_ v: Double?) -> String {
        guard let v = v else { return "" }
        var s = String(v)
        if s.hasSuffix(".0") { s.removeLast(2) }
        return s.replacingOccurrences(of: ".", with: ",")
    }

    /// "2026-09-28" -> "28/09/2026"
    static func fecha(_ v: String?) -> String {
        guard let v = v, !v.isEmpty else { return "—" }
        let p = v.prefix(10).split(separator: "-")
        guard p.count == 3 else { return v }
        return "\(p[2])/\(p[1])/\(p[0])"
    }
}
