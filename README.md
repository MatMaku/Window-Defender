# Window Defender

Juego en Godot 4 con una interfaz inspirada en Windows 98. El escritorio es, al
mismo tiempo, la interfaz principal, el espacio donde se abren aplicaciones y el
campo de batalla en el que virus atacan a `System.exe`.

Esta documentación describe el estado observado en el código. No reemplaza las
decisiones de diseño que todavía deben confirmarse.

## Estado de la documentación

Estado verificado el 2026-07-29.

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
  minería, economía, tienda, mejoras, integridad del sistema, enemigos, reloj
  ficticio, oleadas diarias, modo infinito, disparo, munición, recarga activa,
  reparación, pausa desde el menú Inicio y retorno a MainMenu desde Shut Down.
- **Implementado:** perfiles locales, guardado atómico, snapshot semántico y
  restauración coordinada de una partida por perfil. Crear una partida genera
  inmediatamente un save inicial cargable antes de que avance el gameplay.
- **Implementado:** menú principal funcional para crear y borrar perfiles,
  iniciar una partida, cargar un save y salir. `Shut Down` vuelve a ese menú
  sin guardar automáticamente.
- **Implementado:** `Firewall.exe` se compra en Shop, admite múltiples
  instancias con RAM independiente y puede establecer paredes dinámicas que
  obligan a los virus a rodearlas sin permitir bloquear todas las rutas a
  `System.exe`.
- **Implementado:** `turret.exe` se compra una vez y permite abrir múltiples
  ventanas-torreta con RAM independiente. Cada instancia adquiere un virus
  visible, lo sigue durante su cooldown y dispara sin atravesar ventanas.
- **Implementado:** `overclock.exe` ofrece un minijuego de tipeo singleton cuyo
  éxito activa temporalmente un multiplicador global de ingresos productivos de
  crypto y virus data, persistente aunque la ventana se cierre.
- **Parcialmente implementado:** fin de partida, feedback de algunos rechazos,
  cambio de resolución con reacomodo y presentación del ciclo diario.
- **Planeado:** diseño visual definitivo del menú principal, efectos runtime de
  presión de RAM y acciones adicionales del menú Inicio.
- **Desconocido:** balance definitivo, condición de victoria, plataformas
  soportadas y varias reglas de interacción están pendientes de decisión.

## Requisitos observados

- Godot 4.8, según `config/features` en `project.godot`.
- GDScript tipado.
- Renderer Forward Plus y D3D12 configurado para Windows.
- Escena principal: `Scenes/MainMenu/MainMenu.tscn`.
- Escena de gameplay: `Scenes/Desktop/Desktop.tscn`.
- Autoload de estado jugable: `Scenes/Autoload/GameState.tscn`, registrado como
  `GameState`.
- Autoload de perfiles e intención de sesión entre escenas:
  `Scenes/Autoload/ProfileService.tscn`, registrado como `ProfileService`.
- `GameState` es el contenedor estable de la sesión: carga `GameStartData`,
  resetea la run y expone referencias tipadas a estados especializados.
- Managers y ventanas conservan solamente las referencias de estado de los
  dominios que utilizan; comandos, consultas y señales viven en esos estados.

No hay todavía instrucciones verificadas de exportación, distribución o pruebas
automatizadas.

## Abrir el proyecto

Abrir `project.godot` desde Godot 4.8 y ejecutar la escena principal configurada.
Las validaciones automatizadas disponibles se ejecutan en modo headless; la
disposición y las transiciones visuales deben comprobarse también en el editor o
en una ejecución gráfica.

## Estructura

```text
Apps/       Ventanas de aplicaciones y sus ProgramData/shortcuts.
Data/       Resources para estado inicial, programas, tienda, enemigos, waves y registro persistente.
Scenes/     Escenas base: desktop, autoload, taskbar, virus y ventanas.
Scripts/    Lógica organizada por dominio.
Shop/       Ofertas de aplicaciones y mejoras.
Stages/     Configuración editable de arquetipos y oleadas diarias.
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
- `Scenes/MainMenu/MainMenu.tscn`
- `Scripts/MainMenu/MainMenu.gd`
- `Scripts/MainMenu/MainMenuWindow.gd`
- `Scripts/Transitions/DesktopWindowRevealController.gd`
- `Scenes/Desktop/Desktop.tscn`
- `Scripts/Desktop/Desktop.gd`
- `Scenes/Autoload/GameState.tscn`
- `Scripts/Autoload/GameState.gd`
- `Scripts/Autoload/GameSystemState.gd` y los demás estados de dominio de
  `Scripts/Autoload/`
- `Scripts/Autoload/GameClockState.gd`
- `Scripts/GameClock/GameClockManager.gd`
- `Scenes/Autoload/ProfileService.tscn`
- `Scripts/Persistence/ProfileService.gd`
- `Scripts/Persistence/DesktopSaveCoordinator.gd`
- `Data/Persistence/GameContentRegistry.tres`
- `Scripts/Firewall/FirewallWindow.gd`
- `Scripts/Firewall/FirewallNavigationManager.gd`
- `Apps/Firewall/FirewallWindow.tscn`
- `Scripts/Turret/TurretWindow.gd`
- `Apps/Turret/TurretWindow.tscn`
- `Scripts/Autoload/GameOverclockState.gd`
- `Scripts/Overclock/OverclockManager.gd`
- `Scripts/Overclock/OverclockWindow.gd`
- `Apps/Overclock/OverclockWindow.tscn`
- `Stages/Daily/DailyWaveSequence.tres`
- `Data/GameState/GameStart.tres`

## Limitaciones conocidas

- **Parcialmente implementado:** llegar a cero de integridad detiene el director
  de spawns, pero no inicia una pantalla de derrota ni un reinicio.
- **Implementado:** el menú Inicio pausa el `SceneTree`, presenta el overlay de
  pausa y permite volver a MainMenu mediante Shut Down.
- **Implementado:** Save Game guarda atómicamente en el perfil activo y muestra
  una ventana compacta de confirmación que se cierra con OK o X; sin perfil
  devuelve `no_active_profile` y no escribe una ruta genérica.
- **Implementado:** la carga existe exclusivamente en MainMenu; Taskbar no
  contiene un botón Load Game.
- **Implementado:** el menú principal enumera perfiles por su ID estable,
  presenta errores de `PersistenceResult` y usa `ProfileService` para nueva
  partida, carga y borrado confirmado.
- **Implementado:** los perfiles permanecen en
  `user://profiles/<profile_id>/`. Mover o reinstalar la carpeta del juego en la
  misma computadora no los mueve ni elimina mientras se conserve la misma
  configuración de `user://`; otra computadora requiere copiar manualmente la
  carpeta de datos de usuario.
- **Parcialmente implementado:** la estética del menú principal es provisional
  y sus texturas, distribución y dimensiones están preparadas para edición.
- **Parcialmente implementado:** la RAM ralentiza la animación de apertura; la API
  de ralentización runtime no tiene consumidores.
- **Desconocido:** consultar los registros de preguntas de cada documento antes
  de decidir comportamiento no respaldado por el código.

## Reglas de cambio

Antes de modificar código, escenas o Resources, leer `AGENTS.md` y el documento
del dominio correspondiente. Las preguntas marcadas como **Desconocido** no deben
resolverse por suposición: deben consultarse cuando una tarea dependa de ellas.
