import SwiftUI

/// Pantalla de inicio: datos de la moto, botones rápidos, alertas y resumen de cada sección.
struct DashboardView: View {
    @EnvironmentObject var store: Store

    private let columnas = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init() {}

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                acciones
                if !store.alertas.isEmpty {
                    alertas
                }
                tarjetaTanqueo
                tarjetaAceite
                tarjetaDocumento(.soat, titulo: "SOAT", vence: store.soatOrdenados.first?.fechaVencimiento)
                tarjetaDocumento(.tecnomecanica, titulo: "Tecnomecánica",
                                 vence: store.tecnoOrdenados.first?.fechaVencimiento)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Tema.fondo)
        .navigationTitle("Mi Moto")
    }

    // MARK: Datos de la moto

    private var hero: some View {
        let moto = store.db.moto
        let anio = moto.anio.map { String($0) } ?? "—"
        let placa = moto.placa.isEmpty ? "—" : moto.placa
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mi moto").font(.caption).foregroundStyle(Color.white.opacity(0.7))
                    Text(moto.nombre).font(.title2.bold()).foregroundStyle(Color.white)
                    Text("Año \(anio)  ·  Placa \(placa)")
                        .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "speedometer")
                    .font(.title)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.numero(moto.kmActual))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("km").font(.headline).foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                Button {
                    store.abrir(.moto)
                } label: {
                    Text("Editar información").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color.white)
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Tema.navy, Tema.navy2], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Botones rápidos

    private var acciones: some View {
        LazyVGrid(columns: columnas, spacing: 10) {
            ForEach(Seccion.allCases) { s in
                Button {
                    store.abrir(.registro(s, nil))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: s.icono)
                        Text(s.textoAccion)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .foregroundStyle(Color.white)
                    .background(Tema.navy2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Alertas de mantenimiento

    private var alertas: some View {
        let lista = store.alertas
        return enlace(.mantenimientos) {
            Encabezado(titulo: "Mantenimientos que requieren atención", icono: "exclamationmark.triangle.fill")
            ForEach(lista) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.m.nombre).font(.subheadline.weight(.semibold))
                    Badge(estado: m.estado)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Tarjetas de resumen

    private var tarjetaTanqueo: some View {
        let filas = store.tanqueosCalc
        let resumen = store.resumen(filas)
        let ultimo = filas.first
        return enlace(.tanqueos) {
            Encabezado(titulo: "Último tanqueo", icono: Seccion.tanqueos.icono)
            if let c = ultimo {
                Text(Fmt.fecha(c.t.fecha)).font(.title3.bold())
                Text("\(Fmt.decimal(c.t.litros, 2)) litros  ·  \(Fmt.moneda(c.t.valor))")
                    .font(.subheadline.weight(.semibold))
                Text(Fmt.km(c.t.km)).font(.subheadline)
                Text("Precio por litro: \(Fmt.monedaD(c.precioLitro))")
                    .font(.caption).foregroundStyle(Color.secondary)
                if let consumo = resumen.consumoProm {
                    Text("Consumo promedio: \(Fmt.decimal(consumo, 1)) km/l")
                        .font(.caption).foregroundStyle(Color.secondary)
                }
            } else {
                Text("Aún no has registrado tanqueos.").foregroundStyle(Color.secondary)
            }
        }
    }

    private var tarjetaAceite: some View {
        let ultimo = store.aceitesOrdenados.first
        let estado = store.estadoAceite
        return enlace(.aceite) {
            Encabezado(titulo: "Último cambio de aceite", icono: Seccion.aceite.icono)
            if let a = ultimo {
                Text(Fmt.fecha(a.fecha)).font(.title3.bold())
                Text(Fmt.km(a.km)).font(.subheadline)
                Text("Aceite: \(a.viscosidad)  ·  \(a.marca)").font(.subheadline.weight(.semibold))
                Text("Próximo cambio a los:").font(.caption).foregroundStyle(Color.secondary)
                Text(Fmt.km(a.proximoKm)).font(.headline)
                Badge(estado: estado)
            } else {
                Text("Aún no has registrado cambios de aceite.").foregroundStyle(Color.secondary)
            }
        }
    }

    private func tarjetaDocumento(_ seccion: Seccion, titulo: String, vence: String?) -> some View {
        let estado = Reglas.estadoVencimiento(vence)
        return enlace(seccion) {
            Encabezado(titulo: titulo, icono: seccion.icono)
            if let vence = vence {
                Text("Vence:").font(.caption).foregroundStyle(Color.secondary)
                Text(Fmt.fecha(vence)).font(.title3.bold())
                if let dias = estado.dias {
                    Text(textoDias(dias)).font(.subheadline.weight(.semibold))
                }
                Badge(estado: estado)
            } else {
                Text("Aún no has registrado tu \(titulo).").foregroundStyle(Color.secondary)
            }
        }
    }

    private func textoDias(_ dias: Int) -> String {
        dias >= 0 ? "Faltan \(Reglas.plural(dias, "día", "días"))"
                  : "Venció hace \(Reglas.plural(-dias, "día", "días"))"
    }

    /// Tarjeta que al tocarla abre la sección correspondiente.
    private func enlace<C: View>(_ seccion: Seccion, @ViewBuilder _ contenido: () -> C) -> some View {
        let cuerpo = contenido()
        return NavigationLink {
            SeccionView(seccion: seccion)
        } label: {
            Tarjeta {
                cuerpo
                HStack(spacing: 4) {
                    Spacer()
                    Text("Ver detalle").font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right").font(.caption)
                }
                .foregroundStyle(Tema.acento)
                .padding(.top, 4)
            }
        }
        .buttonStyle(.plain)
    }
}
