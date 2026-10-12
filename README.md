# Agenda diaria

Aplicación móvil para Android que ayuda a organizar el día: tareas, calendario y recordatorios con notificaciones. Proyecto de primer semestre desarrollado con ayuda de modelos de inteligencia artificial.

|||
|-|-|
|Autor|Juan Sebastián Hernández Cortes|
|Semestre|Primero|
|Asignatura / docente|Contexto Ingeniería en Software|
|APK|[`apk/agenda-diaria.apk`](apk/agenda-diaria.apk) (también en la sección *Releases* del repositorio)|

## Funciones

* Vista por día con tira semanal y calendario para saltar a cualquier fecha.
* Tareas con hora, nota, prioridad, repetición (diaria, semanal, mensual), materia con color y subtareas.
* Captura en lenguaje natural: «Informe de física mañana 3pm» o «Reunión el viernes a las 15:30».
* **Notificaciones locales** a la hora indicada, incluso con la app cerrada.
* Búsqueda en todas las fechas y filtro por materia.
* Resumen semanal con barras por día y racha de días.
* Aviso de tareas vencidas y botón para pasarlas a hoy.
* Tema claro, oscuro o automático.
* Copia de seguridad en JSON y exportación a CSV (por portapapeles).
* Introducción de tres pasos la primera vez.
* Datos guardados solo en el dispositivo, sin cuentas ni servidores.

## Instalar la app (Android)

1. Descarga [`apk/agenda-diaria.apk`](apk/agenda-diaria.apk) en el teléfono.
2. Ábrelo y acepta «Instalar apps de fuentes desconocidas» cuando Android lo pida.
3. Al crear el primer recordatorio, acepta el permiso de notificaciones.

## Tecnologías

* Flutter y Dart (Material 3)
* `shared\\\_preferences` para guardar los datos
* `flutter\\\_local\\\_notifications` y `timezone` para las notificaciones
* `intl` y `flutter\\\_localizations` para fechas en español

## Ejecutar y compilar

Requisitos: Flutter 3.38.1 o superior y Android Studio con el SDK de Android.

```bash
flutter pub get
flutter run                      # prueba en emulador o teléfono
flutter build apk --release      # genera el APK
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

Configuración de Android necesaria para las notificaciones (ya incluida en este repositorio):

* `android/app/build.gradle.kts`: desugaring activado, `minSdk = 24` y dependencia `desugar\\\_jdk\\\_libs:2.1.4`.
* `android/app/src/main/AndroidManifest.xml`: permisos de notificaciones y alarmas, y los receptores del plugin.
* `android/app/src/main/res/raw/keep.xml`: evita que el compilador de release elimine el ícono de las notificaciones.

## Desarrollo con inteligencia artificial

* **Herramienta:** Claude (Anthropic), modelo Claude Sonnet 5.5, en la interfaz de chat de claude.ai.
* **Prompts utilizados:** ver [`docs/PROMPTS.md`](docs/PROMPTS.md).
* **Parámetros:** chat con valores por defecto del modelo (la interfaz no permite ajustar temperatura), con búsqueda web y ejecución de código activadas. Del prompt: rol de desarrollador sénior, objetivo, lista de temas, restricción de alcance de primer semestre, criterio de calidad y respuesta en español.
* **Revisión previa de herramientas:** Cursor, Claude Code, Grok Build y Qwen Code (ver documento de entrega).

## Principios de ingeniería de software aplicados

* Requisitos y alcance definidos antes de programar (perfiles de usuario, producto mínimo).
* Desarrollo iterativo: primer prototipo, análisis de mercado, rediseño y versión nativa con notificaciones.
* Separación de responsabilidades: modelo (`Tarea`), almacenamiento (`Almacen`), notificaciones (`Avisos`), interpretación de texto (`interpretar`) y pantallas.
* Validación al importar copias de seguridad y tolerancia a datos dañados.
* Privacidad por diseño: sin cuentas, sin servidor y sin analítica.
* Accesibilidad: etiquetas semánticas, contraste del tema Material 3 y tema oscuro.
* Control de versiones con Git y GitHub.

## Pruebas realizadas

* App Flutter: 4 pruebas automáticas (`flutter test`) sobre la interpretación de texto y las repeticiones de tareas, todas correctas, y `flutter analyze` sin errores.

## Limitaciones

* Solo Android. Para iOS haría falta un Mac con Xcode y una cuenta de desarrollador de Apple.
* Sin sincronización entre dispositivos ni cuentas.
* En algunos teléfonos (Xiaomi, Huawei, Samsung) el ahorro de batería puede bloquear avisos con la app cerrada.
* La copia de seguridad se hace por portapapeles, no por archivo.

## Estructura del repositorio

```
lib/main.dart            código de la app
test/widget\_test.dart    pruebas automáticas
android/                 configuración de Android
apk/agenda-diaria.apk    aplicación instalable
docs/PROMPTS.md          prompts y herramientas de IA usados
pubspec.yaml             dependencias
```

