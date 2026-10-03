import SwiftUI

@main
struct MiMotoApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "es_CO"))
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    /// Pestaña inicial (0 = Inicio). Se puede cambiar con el argumento -pestanaInicial.
    @State private var pestana = UserDefaults.standard.integer(forKey: "pestanaInicial")

    var body: some View {
        TabView(selection: $pestana) {
            Navegacion { DashboardView() }
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(0)
            Navegacion { SeccionView(seccion: .tanqueos) }
                .tabItem { Label("Tanqueos", systemImage: Seccion.tanqueos.icono) }
                .tag(1)
            Navegacion { SeccionView(seccion: .aceite) }
                .tabItem { Label("Aceite", systemImage: Seccion.aceite.icono) }
                .tag(2)
            Navegacion { SeccionView(seccion: .mantenimientos) }
                .tabItem { Label("Mantenim.", systemImage: Seccion.mantenimientos.icono) }
                .tag(3)
            Navegacion { MasView() }
                .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .onAppear {
            // Permite abrir un formulario al iniciar (-abrirFormulario tanqueos); útil para capturas.
            if let clave = UserDefaults.standard.string(forKey: "abrirFormulario"),
               let seccion = Seccion(rawValue: clave) {
                store.abrir(.registro(seccion, nil))
            }
        }
        .tint(Tema.acento)
        .sheet(item: $store.formulario) { formulario in
            FormularioView(formulario: formulario)
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "es_CO"))
        }
        .overlay(alignment: .bottom) {
            if let aviso = store.aviso {
                AvisoBanner(aviso: aviso)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { store.aviso = nil }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.aviso)
    }
}
