<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Icono de Talis"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

Escribe con claridad. Después, pásalo a la IA.

Talis es un espacio de trabajo de prompts para macOS. Anota una idea, crea un prompt que puedas seguir editando y cópialo en la herramienta de IA que ya usas. Puedes responder preguntas para completar datos importantes o guardar requisitos frecuentes como plantillas personales.

Las revisiones consecutivas usan como contexto las últimas 3 rondas. Abre **Historial de revisiones** para consultar las entradas y resultados de la sesión actual. Pulsa **Borrar** para empezar otra tarea.

## Instalación

### Instalar desde el DMG

Descarga [Talis v1.0.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.0.1/talis-v1.0.1-macos-arm64-build42.dmg). Abre la imagen de disco, arrastra `Talis.app` a **Aplicaciones** y ejecuta la app desde allí. Requiere un Mac con Apple Silicon y macOS 13 o posterior.

La app tiene firma ad-hoc y Apple no la ha notarizado. Si macOS bloquea el primer inicio, confirma que descargaste la app de este repositorio y, si aparece la opción, elige **Abrir igualmente** en **Ajustes del Sistema → Privacidad y seguridad**. Consulta las [instrucciones de Apple para abrir apps](https://support.apple.com/en-us/102445).

Para compilar desde el código se necesitan las herramientas de Xcode 26 o posterior, incluido el SDK de macOS 26 o posterior. La compilación está verificada en Apple Silicon; Intel no se ha verificado. No hace falta una membresía de pago de Apple Developer. No hay dependencias de Swift Package de terceros.

### Instalar desde el código fuente

En Terminal:

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

Si faltan las herramientas de Apple, ejecuta `xcode-select --install` y completa el aviso del sistema. Si Talis está abierto, guarda tu texto y cierra la app antes de instalar. Las plantillas personales y los ajustes se conservan fuera del paquete de la app.

## Primer uso

Puedes editar y copiar prompts sin configurar una API Key:

1. Abre Talis y pulsa `Option + Space`.
2. Escribe tu petición, pulsa `Command + Return` para copiarla y pégala en tu herramienta de IA.

Para revisar el texto con IA, abre **Ajustes del servicio de IA** desde el botón de engranaje. Elige **API Key** o **Suscripción**, selecciona un servicio y una región y guarda los ajustes. Después puedes usar **Refinar**, **Reescribir** o **Pregúntame**. El resultado sigue siendo editable; pulsa **Copiar Prompt Cmd+Return** cuando esté listo.

## Servicios de IA y datos

La edición, la selección de plantillas y la copia funcionan sin conexión. Refinar, reescribir, preguntar y generar plantillas con IA requieren un servicio disponible. Los proveedores con API Key cobran según sus propias condiciones. El modo Suscripción usa la suscripción del producto de IA que ya está iniciada en este Mac y no requiere una API Key aparte.

Las API Key se guardan en el Llavero de macOS, separadas por proveedor. El modo Suscripción utiliza el producto ya iniciado localmente y no copia ni guarda su token OAuth. La disponibilidad de modelos, cuentas, regiones y cuotas depende de cada servicio. Consulta [servicios de IA](docs/ai-services.en.md) y [privacidad y datos](docs/privacy.en.md).

Talis copia texto al portapapeles. No envía solicitudes en tu nombre ni transfiere archivos adjuntos. El Servicio Prompt y Talis Codex no forman parte de esta versión de escritorio.

## Comentarios y licencia

Para informar de un problema, abre un [GitHub Issue](https://github.com/viowai/7viow-talis/issues) e incluye la versión de la app, la versión de macOS, el tipo de chip, los pasos y el error. Elimina antes las API Key y cualquier dato privado.

Mantenedor: Viow. El código fuente y la documentación original usan [Apache License 2.0](LICENSE), Copyright 2026 Wenbin Li. Consulta [NOTICE](NOTICE) y [avisos de terceros](THIRD-PARTY-NOTICES.md). Montserrat se distribuye bajo SIL Open Font License 1.1.
