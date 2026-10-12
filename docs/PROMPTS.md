# Prompts y herramientas de IA

**Herramienta:** Claude (Anthropic), modelo Claude Sonnet 5.5, en la interfaz de chat de claude.ai, con búsqueda web y ejecución de código activadas.

## Secuencia de prompts

| Paso | Prompt (resumen) | Resultado |
|---|---|---|
| 1 | Prompt inicial (texto completo más abajo): rol de desarrollador sénior, app de agenda diaria para Android e iOS y lista de temas a cubrir. | Guía de diseño, funciones, tecnología, privacidad, monetización, marketing y pruebas. |
| 2 | «Es un proyecto universitario de 1er semestre, solo para que el profesor lo descargue y lo vea.» | Se redujo el alcance a una app local, sin servidor ni cuentas. |
| 3 | «Crea la app.» | Primera versión funcional (prototipo inicial, que no forma parte de este repositorio). |
| 4 | «Busca errores, analiza el mercado de las aplicaciones de ese tipo y realiza los respectivos cambios; quiero el 5/5.» | Análisis de mercado; captura en lenguaje natural, prioridad, repetición y exportación; corrección de errores. |
| 5 | «Se ve mal eso, mejora los aspectos en general, todo el frontend» (con captura de pantalla). | Rediseño visual completo. |
| 6 | «Es muy lento si quiero ir a una fecha muy lejana, pon una opción para navegar mejor entre fechas.» | Calendario mensual para saltar por mes y por año. |
| 7 | «¿Qué más añadirías?» y «Añade las funciones necesarias para presentar una buena app.» | Materias, subtareas, búsqueda, resumen semanal, introducción, ajustes y copia de seguridad. |
| 8 | «El docente exige que sea una app nativa.» y «Solo hagámoslo en Android.» | Versión en Flutter para Android y guía de instalación de Flutter. |
| 9 | «Entrégame el código con todo lo que tenía la última versión web.» | Versión Flutter con todas las funciones del prototipo. |
| 10 | «Sí necesito que notifique y la explicación de uso, o sea, la introducción.» | Notificaciones locales programadas e introducción de tres pasos. |
| 11 | Mensajes con errores de compilación (capturas de PowerShell) y pedidos de pasos para copiar y pegar. | Corrección de la configuración de Gradle y guía de publicación. |

## Prompt inicial (texto completo)

> Como desarrollador de software sénior crear una aplicación de agenda diaria para Android e iOS. La aplicación deberá ayudar a los usuarios a organizar sus horarios de forma práctica y productiva, permitiéndoles realizar un seguimiento de sus tareas y compromisos desde cualquier lugar. Incluya los siguientes temas:
>
> * Principios de diseño de interfaz de usuario para una experiencia amigable e intuitiva.
> * Entre las características clave que debe incluir se encuentran la gestión de tareas, la integración con el calendario, los recordatorios y las notificaciones.
> * Buenas prácticas para el desarrollo multiplataforma que garanticen una experiencia fluida tanto en Android como en iOS.
> * Sugerencias de tecnologías y marcos de trabajo que se pueden utilizar para el desarrollo.
> * Consejos para estrategias de captación y retención de usuarios.
> * Consideraciones sobre accesibilidad e inclusión en el diseño de aplicaciones.
> * Posibles estrategias de monetización, si procede.
> * Mecanismos de prueba y retroalimentación para mejorar la aplicación después de su lanzamiento.
>
> Contexto adicional para la pregunta
>
> * Ejemplos de aplicaciones de planificación diaria exitosas y qué las hace efectivas.
> * Perfiles de usuario a tener en cuenta al diseñar la aplicación.
> * Errores comunes en el desarrollo de aplicaciones y cómo evitarlos.
> * Información relevante sobre la privacidad de los datos y las medidas de seguridad para la información del usuario.
> * Estrategias de marketing para promocionar la aplicación después de su lanzamiento.
> * Integración con servicios de terceros (por ejemplo, Google Calendar, herramientas de gestión de tareas).
> * Procesos de incorporación de usuarios para mejorar la experiencia de los usuarios que acceden por primera vez.
> * ¿Qué características específicas considera esenciales para una aplicación de agenda diaria? ¿Cómo podemos garantizar que la aplicación siga siendo fácil de usar al tiempo que incorpora funcionalidades avanzadas? ¿Cuáles son algunas formas efectivas de recopilar comentarios de los usuarios durante el proceso de desarrollo? ¿Cómo deberíamos enfocar la comercialización de la aplicación para llegar a nuestro público objetivo? ¿Cuáles son las mejores prácticas para mantener la privacidad y la seguridad de los datos de los usuarios en nuestra aplicación?
