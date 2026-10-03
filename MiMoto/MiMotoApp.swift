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

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Inicio", systemImage: "house.fill") }
            NavigationStack { SeccionView(seccion: .tanqueos) }
                .tabItem { Label("Tanqueos", systemImage: Seccion.tanqueos.icono) }
            NavigationStack { SeccionView(seccion: .aceite) }
                .tabItem { Label("Aceite", systemImage: Seccion.aceite.icono) }
            NavigationStack { SeccionView(seccion: .mantenimientos) }
                .tabItem { Label("Mantenim.", systemImage: Seccion.mantenimientos.icono) }
            NavigationStack { MasView() }
                .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
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
