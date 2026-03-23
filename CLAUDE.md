# CLAUDE.md — WorkTimer

## Proyecto
App de temporizador de bloques de trabajo para iOS/iPadOS.
El usuario define la duración, añade una etiqueta de tarea, y la app
registra un historial de sesiones completadas del día.

## Stack técnico
- SwiftUI (no UIKit)
- SwiftData para persistencia local
- Swift 6
- Formato .swiftpm (compatible con Swift Playgrounds en iPad)

## Restricciones de entorno — MUY IMPORTANTE
No hay Mac ni Xcode en este flujo. El código se ejecuta en
Swift Playgrounds en iPadOS. Por tanto:
- Sin App Extensions (widgets, share extensions, etc.)
- Sin Info.plist personalizado
- Sin dependencias externas de Swift Package Manager
- Sin xcodebuild ni scripts de build
- Todo el proyecto debe funcionar como un único .swiftpm válido

## Scope v1
- Pantalla principal: configurar duración (libre) + etiqueta de tarea
- Timer con estados: idle → corriendo → pausado → completado
- Historial del día (tarea, duración, hora) persistido con SwiftData
- UI nativa, limpia, sin librerías de terceros

## Fuera de scope v1
- Notificaciones push o locales
- Estadísticas semanales o historial extendido
- Categorías o perfiles múltiples
- Sincronización o backend

## Convenciones de código
- Comentarios en inglés explicando el "por qué", no el "qué"
- Commits atómicos y descriptivos
- Código legible para alguien aprendiendo SwiftUI por primera vez
- Preferir soluciones simples sobre elegantes cuando hay conflicto
