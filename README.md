# Mi Moto — app para iPhone (SwiftUI)

Versión para iPhone de «Mi Moto». Tiene las mismas funciones que la versión de escritorio:
tanqueos, cambios de aceite, SOAT, tecnomecánica, mantenimientos, historial, alertas por colores
y copia de seguridad.

- Funciona sin internet; los datos se guardan solo en el iPhone.
- Requiere iOS 16 o superior.
- Los respaldos JSON son **compatibles con la versión de escritorio (Python)**. Puedes exportar
  allá e importar aquí, o al revés.

## Estructura

```
MiMoto.xcodeproj/            Proyecto de Xcode
MiMoto-Info.plist            Permite ver los datos en la app Archivos
MiMoto/
├── MiMotoApp.swift          Inicio de la app y pestañas
├── DashboardView.swift      Pantalla de inicio
├── SeccionView.swift        Lista, resumen y detalle de cada sección
├── Formularios.swift        Formularios (agregar / editar)
├── OtrasVistas.swift        Más, Historial y Copia de seguridad
├── Componentes.swift        Colores, tarjetas, campos
├── Store.swift              Guardado, cálculos, historial, exportar/importar
├── Reglas.swift             Alertas (DIAS_AVISO = 30, KM_AVISO = 500)
├── Validador.swift          Validación de datos
├── Formato.swift            Formato de números, dinero y fechas
├── Modelos.swift            Registros (mismos campos que la base SQLite)
└── Assets.xcassets          Ícono y color
.github/workflows/compilar-ios.yml   Compila el .ipa en GitHub (gratis)
```

---

## Instalarla desde Windows (sin Mac)

Apple solo permite instalar apps firmadas con una cuenta de Apple. Por eso hay dos pasos:
primero GitHub compila la app en un Mac en la nube y te da el archivo `MiMoto.ipa`. Después
**Sideloadly** firma ese archivo con tu Apple ID y lo instala en el iPhone por cable USB.

### Paso 1 — Obtener el archivo MiMoto.ipa (GitHub, gratis)

1. Crea una cuenta en https://github.com si no tienes una.
2. Arriba a la derecha pulsa **+ → New repository**. Ponle de nombre `mimoto`, márcalo como
   **Private** y pulsa **Create repository**.
3. En la página del repositorio pulsa **uploading an existing file**. Arrastra **todo el contenido**
   de esta carpeta: `MiMoto.xcodeproj`, `MiMoto`, `MiMoto-Info.plist`, `README.md` y la carpeta
   `.github`. Asegúrate de incluir `.github`. Luego pulsa **Commit changes**.
4. Abre la pestaña **Actions**. La compilación «Compilar app iOS» arranca sola y tarda unos 5–10 minutos.
   Si no arranca, entra en «Compilar app iOS» y pulsa **Run workflow**.
5. Cuando aparezca el círculo verde ✅, entra en esa ejecución. Abajo, en **Artifacts**, descarga
   **MiMoto-ipa**. Descomprime el zip y obtendrás `MiMoto.ipa`.

### Paso 2 — Instalar en el iPhone (Sideloadly)

1. Instala **iTunes** e **iCloud** en su **versión web** de Apple. La versión de Microsoft Store no
   sirve; si la tienes, desinstálala primero. Los enlaces están en https://sideloadly.io.
2. Descarga e instala **Sideloadly** desde https://sideloadly.io.
3. Conecta el iPhone por cable USB, desbloquéalo y pulsa **Confiar** en el aviso del iPhone.
4. En Sideloadly:
   - Arrastra `MiMoto.ipa` a la ventana.
   - Escribe tu Apple ID; sirve uno normal y gratuito.
   - Pulsa **Start** y escribe tu contraseña (o el código de verificación) cuando te lo pida.
5. En el iPhone:
   - **Ajustes → General → VPN y gestión de dispositivos** → toca tu Apple ID → **Confiar**.
   - Con iOS 16 o superior, activa además **Ajustes → Privacidad y seguridad → Modo de desarrollador**.
     El iPhone se reinicia y te pide confirmar.
6. Abre **Mi Moto** desde la pantalla de inicio.

> **Importante:** con un Apple ID gratuito la app funciona **7 días**. Después hay que volver a
> instalarla con Sideloadly; los datos se conservan. Sideloadly puede renovarla sola si dejas
> activada la opción de actualización automática. Con una cuenta de desarrollador de Apple
> (USD 99/año) dura 1 año. De todos modos, exporta un respaldo de vez en cuando.

## Instalarla con un Mac (alternativa)

1. Instala **Xcode 16** o superior desde la App Store y abre `MiMoto.xcodeproj`.
2. En **Signing & Capabilities**, elige tu Apple ID en **Team**.
3. Conecta el iPhone, selecciónalo arriba y pulsa ▶︎ **Run**.

## Pasar tus datos actuales al iPhone

1. En el computador, abre la app de escritorio → **Copia de seguridad → Exportar datos**. También puedes
   usar el archivo `respaldo_moto_mis_datos.json` que viene incluido.
2. Envía ese archivo al iPhone por correo, WhatsApp, iCloud Drive o Google Drive y guárdalo en
   **Archivos**.
3. En la app del iPhone ve a **Más → Copia de seguridad → Importar respaldo** y elige el archivo.

## Alertas

| Elemento | Verde | Amarillo | Rojo |
|---|---|---|---|
| SOAT / Tecnomecánica | faltan más de 30 días | 30 días o menos | vencido |
| Aceite y mantenimientos por km | faltan más de 500 km | 500 km o menos | pasó el kilometraje |

Los umbrales se cambian en `Reglas.swift` (`diasAviso`, `kmAviso`).

## Si la compilación en GitHub falla

Abre la ejecución en rojo, copia el error del paso «Compilar la app» y compártelo con Claude para
corregirlo.
