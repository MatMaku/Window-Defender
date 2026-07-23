# Window Defender

Juego en Godot 4 con una interfaz inspirada en Windows 98. El escritorio es, al
mismo tiempo, la interfaz principal, el espacio donde se abren aplicaciones y el
campo de batalla en el que virus atacan a `System.exe`.

Esta documentación describe el estado observado en el código. No reemplaza las
decisiones de diseño que todavía deben confirmarse.

## Estado de la documentación

Estado verificado el 2026-07-22 sobre la base Git `223d385`.

Las etiquetas usadas en todos los documentos significan:

- **Implementado:** existe un flujo conectado y respaldado por código, escena o
  Resource actualmente referenciado.
- **Parcialmente implementado:** existe una parte funcional, pero faltan
  integraciones, presentación o cierre del flujo.
- **Planeado:** existe scaffolding explícito, una API marcada para uso futuro o
  UI que anticipa la función. El alcance todavía puede requerir confirmación.
- **Desconocido:** el código no permite determinar la intención. Está registrado
  como pregunta para consultar cuando se trabaje en esa área.

## Estado actual resumido

- **Implementado:** escritorio, accesos directos, ventanas, foco, RAM, taskbar,
  minería, economía, tienda, mejoras, integridad del sistema, enemigos, stages,
  disparo, munición, recarga activa y reparación.
- **Parcialmente implementado:** fin de partida, feedback de algunos rechazos,
  cambio de resolución con reacomodo, persistencia del progreso y presentación
  de stages.
- **Planeado:** guardado/carga, snapshots de enemigos, efectos runtime de presión
  de RAM y acciones adicionales del menú Inicio tienen scaffolding visible.
- **Desconocido:** balance definitivo, condición de victoria, plataformas
  soportadas y varias reglas de interacción están pendientes de decisión.

## Requisitos observados

- Godot 4.7, según `config/features` en `project.godot`.
- GDScript tipado.
- Renderer Forward Plus y D3D12 configurado para Windows.
- Escena principal: `Scenes/Desktop/Desktop.tscn`.
- Único autoload: `Scenes/Autoload/GameState.tscn`, registrado como
  `GameState`.
- `GameState` es el contenedor estable de la sesión: carga `GameStartData`,
  resetea la run y expone referencias tipadas a estados especializados.
- Managers y ventanas conservan solamente las referencias de estado de los
  dominios que utilizan; comandos, consultas y señales viven en esos estados.

No hay todavía instrucciones verificadas de exportación, distribución o pruebas
automatizadas.

## Abrir el proyecto

Abrir `project.godot` desde Godot 4.7 y ejecutar la escena principal configurada.
La auditoría que originó estos documentos fue de solo lectura y no incluyó una
ejecución del juego.

## Estructura

```text
Apps/       Ventanas de aplicaciones y sus ProgramData/shortcuts.
Data/       Clases Resource para estado inicial, programas, tienda y stages.
Scenes/     Escenas base: desktop, autoload, taskbar, virus y ventanas.
Scripts/    Lógica organizada por dominio.
Shop/       Ofertas de aplicaciones y mejoras.
Stages/     Enemigos y progresión de stages configurados como Resources.
Sprites/    Recursos gráficos.
Fonts/      Tipografías.
docs/       Documentación funcional y técnica.
```

## Documentación

- [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md): concepto, loop y
  alcance actual.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): composición, propietarios de
  estado y dependencias.
- [`docs/GAMEPLAY_SYSTEMS.md`](docs/GAMEPLAY_SYSTEMS.md): reglas de cada sistema
  jugable.
- [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md): Resources, IDs y estado runtime.
- [`docs/SIGNALS.md`](docs/SIGNALS.md): contratos de señales y consumidores.
- [`AGENTS.md`](AGENTS.md): reglas obligatorias para trabajar en el proyecto.

## Puntos de entrada relevantes

- `project.godot`
- `Scenes/Desktop/Desktop.tscn`
- `Scripts/Desktop/Desktop.gd`
- `Scenes/Autoload/GameState.tscn`
- `Scripts/Autoload/GameState.gd`
- `Scripts/Autoload/GameSystemState.gd` y los demás estados de dominio de
  `Scripts/Autoload/`
- `Data/GameState/GameStart.tres`

## Limitaciones conocidas

- **Parcialmente implementado:** llegar a cero de integridad detiene el director
  de spawns, pero no inicia una pantalla de derrota ni un reinicio.
- **Planeado:** el menú Inicio muestra Load Game, Save Game, Options y Shut Down,
  pero esos botones no tienen comportamiento conectado.
- **Planeado:** hay estado para progreso de run y snapshots de enemigos, pero no
  persistencia a disco.
- **Parcialmente implementado:** la RAM ralentiza la animación de apertura; la API
  de ralentización runtime no tiene consumidores.
- **Desconocido:** consultar los registros de preguntas de cada documento antes
  de decidir comportamiento no respaldado por el código.

## Reglas de cambio

Antes de modificar código, escenas o Resources, leer `AGENTS.md` y el documento
del dominio correspondiente. Las preguntas marcadas como **Desconocido** no deben
resolverse por suposición: deben consultarse cuando una tarea dependa de ellas.
