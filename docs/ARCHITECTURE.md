# Architecture

## 1. Alcance

Este documento registra la arquitectura observada. Las reglas obligatorias para
futuros cambios siguen estando en `AGENTS.md`.

## 2. Arranque

`project.godot` configura:

- `Scenes/MainMenu/MainMenu.tscn` como `run/main_scene`.
- `Scenes/Autoload/GameState.tscn` como contenedor de estado jugable, con nombre
  `GameState`.
- `Scenes/Autoload/ProfileService.tscn` como servicio de perfiles, archivos e
  intención pendiente de nueva partida/carga, con nombre `ProfileService`.

Flujo aproximado:

```text
GameState._ready()
  -> reset_run()
  -> estados de dominio restaurados desde GameStart.tres

MainMenu.tscn
  -> consulta perfiles mediante ProfileService
  -> valida/crea/selecciona por profile_id estable
  -> cierra localmente LoginWindow
  -> solicita nueva partida o carga a ProfileService

Desktop.tscn
  -> managers conectan dependencias y señales
  -> DesktopSaveCoordinator detiene procesamiento
  -> consume la intención pendiente de ProfileService
  -> resetea una partida nueva o restaura un snapshot validado
  -> crea/restaura shortcuts, ventanas y enemigos
  -> restaura procesos temporales
  -> si es nueva, persiste el snapshot inicial en tiempo cero
  -> inicia GameClockManager y EnemySpawnDirector
  -> emite restore_finished
  -> DesktopWindowRevealController mantiene la pausa
  -> WindowManager revela ventanas restauradas de atrás hacia adelante
  -> reanuda gameplay
```

- **Implementado:** este flujo está conectado en escenas y scripts.
- **Implementado:** `GameClockManager` y `EnemySpawnDirector` tienen
  `autostart = false` en Desktop; sólo el coordinador los inicia cuando la
  sesión es coherente.
- **Resuelto (Q-ARCH-001):** `DesktopSaveCoordinator` está después de Taskbar y
  managers, pausa el árbol al entrar y ejecuta la inicialización diferida. El
  controlador visual se conecta antes de esa llamada diferida y espera
  `restore_finished`.

## 3. Escenas principales

`Scenes/MainMenu/MainMenu.tscn` contiene fondo, una ventana de acceso compacta y
una confirmación modal de borrado. No instancia Desktop, Taskbar, shortcuts,
managers ni aplicaciones. `MainMenuWindow` implementa arrastre, clamp al
viewport, solicitud de cierre y una animación local breve de apertura/cierre;
no hereda de `AppWindow` ni participa en RAM o `WindowManager`.
Al entrar, `MainMenu.gd` restablece una resolución lógica fija de 2560×1440 sin
mutar `GameDesktopState`; Desktop vuelve a aplicar la resolución propia de la
partida mediante `DisplayManager`.

La lista muestra `display_name`, pero conserva `profile_id` como metadata de cada
ítem. `MainMenu.gd` limita su responsabilidad a estado de controles, llamadas a
la API pública de `ProfileService` y presentación de `PersistenceResult`.

`Scenes/Desktop/Desktop.tscn` contiene cuatro capas:

| Capa | Responsabilidad |
|---|---|
| `IconLayer` | Accesos directos del escritorio |
| `PlayfieldLayer` | Virus activos |
| `WindowLayer` | Ventanas de aplicaciones |
| `StatusLayer` | Taskbar y estado permanente |

El nodo `Managers` contiene:

- `WindowManager`
- `SystemManager`
- `ShootingManager`
- `ReloadManager`
- `RamManager`
- `TaskbarManager`
- `ShopManager`
- `DisplayManager`
- `GameClockManager`
- `EnemyManager`
- `EnemySpawnDirector`
- `UpgradeManager`
- `RepairManager`

`DesktopSaveCoordinator` es un hijo directo de Desktop. Se mantiene fuera de
`Managers` para que su `_ready()` ocurra después de Taskbar y pueda cerrar el
ciclo de inicialización/restore.

- **Implementado:** las referencias críticas están exportadas y asignadas en la
  escena.
- **Implementado:** muchos managers incluyen resolución relativa como fallback.
- **Riesgo:** varios fallbacks dependen de una jerarquía concreta y no coinciden
  necesariamente con la ruta real fuera de `Desktop.tscn`.

## 4. Estado compartido

`Scripts/Autoload/GameState.gd` (`RuntimeGameState`) es el contenedor estable del
estado jugable. `Scenes/Autoload/GameState.tscn` compone once nodos
especializados; no conoce perfiles ni archivos.

| Componente | Estado propietario |
|---|---|
| `GameSystemState` | Integridad y destrucción |
| `GameWeaponState` | Daño, cooldown y munición |
| `GameReloadStatsState` | Tiempos de recarga |
| `GameMinerState` | Producción e intervalo |
| `GameEconomyState` | Criptomonedas, datos y muertes |
| `GameRamState` | RAM máxima y utilizada |
| `GameDesktopState` | Resolución y posiciones de shortcuts |
| `GameUpgradeState` | Compras y automatizaciones |
| `GameClockState` | Fecha, hora, minutos ficticios y velocidad |
| `GameRunState` | Modo, fase, día, presupuesto y timestamp de spawn |
| `GameEnemySnapshotState` | Array de snapshots futuros |

- **Implementado:** `GameState` sólo conserva `start_data`, referencias tipadas,
  `reset_run()` e inicialización privada. No replica propiedades, comandos ni
  señales de dominio.
- **Implementado:** sistema, arma, recarga, minería, economía, RAM, desktop y
  upgrades protegen sus datos mediante backing fields, exponen consultas y
  comandos explícitos, y emiten sus propias señales.
- **Implementado:** los consumidores resuelven una sola vez los estados que
  necesitan desde `GameState` y conservan referencias tipadas específicas.
- **Implementado:** `GameClockState` y `GameRunState` protegen sus campos,
  exponen comandos y producen snapshots formados únicamente por valores
  serializables.
- **Parcialmente implementado:** `GameEnemySnapshotState` conserva un Array sin
  esquema de enemigo definitivo.
- **Riesgo:** el acceso inicial sigue siendo global. Es un acoplamiento aceptado
  en esta etapa, limitado a localización de sesión durante `_ready()`.

API pública final del contenedor:

- `start_data`
- `system_state`, `weapon_state`, `reload_stats_state`, `miner_state`
- `economy_state`, `ram_state`, `desktop_state`, `upgrade_state`
- `clock_state`, `run_state`, `enemy_snapshot_state`
- `reset_run()`

`_ready()` y `_ensure_start_data()` son implementación privada de
inicialización. Agregar proxies o relays a esta API contradice la frontera
arquitectónica actual.

## 5. Estado transitorio de sesión

| Propietario | Estado local |
|---|---|
| `Desktop` | Ejecutables por `program_id` |
| `WindowManager` | Ventanas únicas, error activo y z-index |
| `TaskbarManager` | Botones por instancia y ventana enfocada |
| `GameClockManager` | Estado activo/inactivo del avance del reloj |
| `ShootingManager` | Ventana Shooting activa, cooldown y lock de recarga |
| `ReloadManager` | Máquina de estados y timers de recarga |
| `EnemyManager` | Array de enemigos vivos |
| `EnemySpawnDirector` | Día observado y RNG; el progreso pertenece a `GameRunState` |
| `RepairManager` | Ventana activa y progreso de tick |
| `ShopManager` | Ventanas Shop activas |
| `SystemManager` | Referencias al shortcut y ventana System |
| `MinerWindow` | Timer de minería por instancia |
| `ProfileService` | Perfil activo e intención pendiente de nueva/carga |
| `DesktopSaveCoordinator` | Captura coherente y secuencia de restauración |

- **Implementado:** el estado compartido y el transitorio están separados en la
  mayoría de los sistemas.
- **Implementado:** el director no mantiene un reloj, presupuesto ni timer
  temporal paralelo; consulta `GameClockState` y muta `GameRunState`.
- **Implementado:** `ProfileService` sobrevive a cambios de escena, pero no
  conserva estado jugable; el snapshot pendiente se consume una sola vez al
  crear Desktop.

## 6. Dependencias principales

```text
GameState -> estados especializados

MainMenu -> ProfileService -> ProfileStore -> user://profiles/
                         `-> GameContentRegistry

MainMenu -> MainMenuWindow
DesktopWindowRevealController -> DesktopSaveCoordinator.restore_finished
                              -> WindowManager -> AppWindow

DesktopSaveCoordinator -> estados especializados
                       -> Desktop / WindowManager / EnemyManager
                       -> ShootingManager / ReloadManager / RepairManager
                       -> ProfileService

Desktop -> GameDesktopState
DesktopExecutable -> WindowManager -> RamManager -> GameRamState

GameClockManager -> GameClockState

EnemySpawnDirector -> GameClockState
                   -> GameRunState
                   -> WaveSequenceData
                   -> EnemyManager -> GameEconomyState
                                   -> DesktopVirus/BasicVirus
                                   -> SystemManager -> GameSystemState

FirewallWindow -> FirewallNavigationManager -> NavigationServer2D
                                      |-> Desktop / EnemyManager / SystemManager
                                      `-> WindowManager

DesktopVirus -> FirewallNavigationManager

ShootingWindow -> ShootingManager -> EnemyManager
                         |-> GameWeaponState
                         `-> GameUpgradeState
ReloadWindow   -> ReloadManager   -> ShootingManager
                         |-> GameWeaponState
                         |-> GameReloadStatsState
                         `-> GameUpgradeState
RepairWindow   -> RepairManager   -> SystemManager

ShopWindow -> ShopManager -> GameEconomyState
                         -> UpgradeManager -> estados de dominio requeridos
TaskbarManager <- WindowManager
DisplayManager <- GameDesktopState
```

Fuentes:

- `Scripts/Desktop/Desktop.gd`
- `Scripts/Windows/WindowManager.gd`
- `Scripts/Virus/EnemyManager.gd`
- `Scripts/Virus/EnemySpawnDirector.gd`
- `Scripts/GameClock/GameClockManager.gd`
- `Scripts/Shooting/ShootingManager.gd`
- `Scripts/Shooting/ReloadManager.gd`
- `Scripts/Shop/ShopManager.gd`
- `Scripts/Shop/UpgradeManager.gd`

## 7. Ventanas y aplicaciones

`Data/Programs/ProgramData.gd` configura identidad, escena, tamaño, multiplicidad
y costo de RAM. `WindowManager.open_program()`:

1. valida el Resource;
2. enfoca una instancia existente cuando corresponde;
3. verifica y reserva RAM;
4. instancia un `AppWindow`;
5. conecta foco y cierre;
6. registra la ventana;
7. inicia la animación y emite `window_opened`.

- **Implementado:** la RAM se libera al cerrar y durante `_exit_tree()`.
- **Implementado:** `restore_windows()` reconstruye por `program_id`, reserva
  RAM sin ejecutar compras, restaura posición y z-order, y emite
  `window_opened` una vez para los bindings existentes. Luego prepara las
  ventanas ocultas para un revelado visual que no emite señales de apertura ni
  vuelve a reservar RAM.
- **Implementado:** los errores de RAM usan `SystemErrorWindow` sin costo.
- **Implementado:** `Firewall` reutiliza `allow_multiple_instances`; cada
  instancia se registra y reserva RAM por el mismo flujo que las demás apps.
  `WindowManager` mantiene una banda inferior localizada para Firewalls
  establecidos, sin alterar el orden relativo de las ventanas normales.
- **Implementado:** `DesktopExecutable` conserva una referencia explícita a
  `WindowManager` y finaliza el drag al entrar el cursor sobre una ventana
  visible. `Desktop` sólo persiste la última posición alcanzada; no existe una
  segunda ruta de proyección al soltar.
- **Parcialmente implementado:** taskbar enfoca ventanas, pero no minimiza.
- **Desconocido (Q-ARCH-002):** confirmar si minimizar debe formar parte del
  ciclo de vida de ventanas.

## 8. Lógica y presentación

- **Implementado:** Shooting, Reload, Repair, Shop y System separan mayormente
  managers de ventanas de presentación.
- **Parcialmente implementado:** `MinerWindow` contiene el timer y muta economía
  directamente.
- **Parcialmente implementado:** `DesktopVirus` y `BasicVirus` combinan estado,
  movimiento, ataque, arrastre y feedback visual en nodos `Control`.
- **Desconocido (Q-ARCH-003):** confirmar si esos sistemas deben migrar a
  controladores/modelos separados o si la composición actual es deliberada.

### 8.1 Firewall y navegación

`Scripts/Firewall/FirewallNavigationManager.gd` vive dentro de
`Scenes/Desktop/Desktop.tscn`; no es autoload. Es la única colección runtime de
Firewall establecidos y construye un `NavigationPolygon` procedural para
`EnemyNavigationRegion` mediante `NavigationMeshSourceGeometryData2D` y
`NavigationServer2D`.

El contorno transitable es el rectángulo global de `PlayfieldLayer`, que ya
excluye la Taskbar. Sólo el rectángulo completo de cada Firewall establecido se
agrega como obstrucción; las ventanas normales y los Firewall móviles no forman
parte del mapa. `DesktopVirus` conserva el path y la revisión de navegación;
`BasicVirus` consume únicamente el siguiente waypoint.

Antes de establecer, el manager valida de forma atómica intersecciones con
enemigos, shortcuts y otras paredes, hornea un `NavigationPolygon` con el
candidato y comprueba directamente la conectividad de sus polígonos desde el
perímetro de spawn hasta el destino real de `System.exe`. Los cambios aceptados
agrupan un único rebuild diferido del mapa vivo. El manager conserva el rebuild
como pendiente hasta el siguiente frame de física, cuando `NavigationServer2D`
ya sincronizó la región; sólo entonces incrementa la revisión que observan los
enemigos y reemplaza el snapshot de rectángulos asociado a esa revisión.
`EnemyManager` invalida explícitamente todas las rutas al recibir
`firewall_obstacles_changed`; mientras el rebuild está pendiente, los virus se
detienen en vez de consultar o cachear el mapa anterior. Cada path y segmento
seguido se contrasta con el snapshot sincronizado para fallar cerrado ante una
ruta inválida. Un resize de `PlayfieldLayer` agenda el rebuild después del
relayout de ventanas para que el mapa y las paredes ya ajustadas usen la nueva
resolución lógica.

El `NavigationPolygon` usa el mayor radio soportado y un margen de obstáculo
configurable. `DesktopVirus` mantiene una tolerancia configurable para consumir
waypoints sin oscilar sobre una esquina exacta. Al terminar un drag, el propio
virus proyecta su centro al punto navegable más cercano si quedó dentro del
margen excluido. Los empujes de separación se restringen al mismo mapa y sólo
descartan el path cacheado cuando el próximo tramo deja de ser transitable.

## 9. Persistencia

- **Implementado:** `ProfileStore` administra
  `user://profiles/<profile_id>/profile.json` y `savegame.json`, ambos con
  `schema_version = 1`.
- **Implementado:** `project.godot` usa `application/config/name =
  "Window Defender"` y no configura un directorio de usuario personalizado.
  Los perfiles permanecen fuera de `res://`; sobreviven a mover la carpeta del
  proyecto en la misma computadora, pero otra PC requiere copiar manualmente el
  directorio de datos de usuario. Exportar/importar perfiles sigue planeado.
- **Implementado:** las escrituras usan `.tmp`, preservan el archivo previo como
  `.bak`, reemplazan el principal, realizan rollback si falla el reemplazo y
  recuperan un backup dejado por una interrupción.
- **Implementado:** `PersistenceResult` devuelve `success`, `code`, `message` y
  datos duplicados para la UI.
- **Implementado:** `GameContentRegistry` valida unicidad y resuelve programas,
  upgrades y arquetipos por IDs estables.
- **Implementado:** cada estado especializado produce/restaura su sección;
  ventanas, procesos y enemigos usan contratos semánticos propios.
- **Implementado:** cada `FirewallWindow` persiste orientación y estado
  establecido dentro de `app_state`. El registro y el mapa de navegación no se
  serializan: `FirewallNavigationManager` los reconstruye en bloque desde las
  ventanas restauradas y `DesktopSaveCoordinator` espera la revisión
  sincronizada antes de completar la carga o reanudar gameplay.
- **Implementado:** la RAM usada no se duplica: se restaura el máximo y las
  ventanas reconstruyen el uso al reservar sus costos actuales.
- **Implementado:** la captura preserva el estado previo de pausa y no serializa
  el menú Inicio. Una partida cargada siempre es reanudable.
- **Implementado:** la inicialización de una partida nueva usa la misma captura
  semántica y ruta de `ProfileService` que el guardado manual, pero la ejecuta
  antes de arrancar reloj y director. No constituye autosave periódico ni se
  ejecuta al volver a MainMenu.
- **Implementado:** `Taskbar` consume `save_finished` y presenta
  `Scenes/Windows/SaveSuccessWindow.tscn`, una variante compacta de
  `SystemErrorWindow` alojada dentro del `CanvasLayer` de Taskbar. No se
  registra como aplicación, no reserva RAM y se cierra explícitamente mediante
  OK o X.
- **Implementado:** la restauración valida todo el snapshot antes de mutar y
  mantiene reloj/director detenidos hasta el final. Un fallo runtime limpia la
  restauración parcial y deja un estado inicial detenido.
- **Implementado:** MainMenu muestra perfiles y errores, y ejecuta nueva partida
  o carga sin acceder directamente a archivos.
- **Implementado:** MainMenu puede borrar un perfil inactivo; `ProfileStore`
  valida el ID, confina la ruta a `user://profiles/` y elimina la carpeta
  completa, incluidos temporales y backups.
- **Implementado:** la carga se inicia exclusivamente desde MainMenu; Taskbar no
  contiene un control de carga.
- **Planeado:** migraciones entre versiones. Actualmente una versión
  incompatible se rechaza.

API pública consumida por MainMenu:

- `get_profiles()`
- `validate_new_profile_name(name)`
- `create_profile(name)`
- `delete_profile(profile_id)`
- `get_profiles_directory_path()`
- `select_profile(profile_id)`
- `profile_has_save(profile_id)`
- `start_new_game(profile_id)`
- `load_profile_game(profile_id)`
- `return_to_main_menu()`

Todas las operaciones devuelven `PersistenceResult`; la consulta de ruta devuelve
la ruta globalizada de `user://profiles`. `return_to_main_menu()` está conectado
a Shut Down de Taskbar y no guarda automáticamente.

## 10. Transición de escenas

La transición no usa un overlay global. `MainMenuWindow` se abre y cierra con dos
pasos locales: expansión/contracción horizontal y vertical alrededor de su
posición actual. `ProfileService` conserva la decisión de sesión y el destino;
no conoce Tween ni detalles visuales.

En Desktop, `DesktopWindowRevealController` escucha
`DesktopSaveCoordinator.restore_finished`, pausa antes del siguiente frame y
solicita a `WindowManager` revelar las ventanas restauradas de menor a mayor
z-order. `AppWindow.play_restore_reveal_animation()` es exclusivamente visual:
no emite `opening_started`/`opening_finished`, no ejecuta setup funcional y no
reserva RAM. El input de GUI queda deshabilitado durante ese tramo; los enemigos
restaurados aparecen directamente. El gameplay se reanuda después de terminar
el revelado breve.

## 11. Escalabilidad y riesgos

- `GameState` sigue siendo el punto global de localización inicial, aunque ya no
  participa en la lógica interna de los consumidores.
- `UpgradeManager` necesita siete estados porque aplica efectos de varios
  dominios; es coordinación explícita, pero sigue siendo un punto de alto
  acoplamiento que debe vigilarse al agregar nuevos efectos.
- La restauración de una versión incompatible se rechaza; todavía no hay
  migraciones.
- `EnemyManager` separa enemigos en O(n²) por frame; los Resources diarios deben
  mantener límites activos razonables.
- El bake de navegación de Firewall ocurre sólo ante cambios de obstáculos,
  pero su costo crece con la cantidad de paredes. La validación de cierre de
  rutas muestrea el perímetro de spawn con separación configurable y usa el
  mayor radio de enemigo soportado como criterio conservador.
- Bloqueo de disparos y reparación recorre ventanas y no usa el helper de ventanas
  superiores.
- IDs y requisitos se conectan manualmente con `StringName`; el registro valida
  los IDs persistentes, pero no toda la coherencia editorial de ofertas/waves.
- Métodos de layout son invocados opcionalmente por nombre desde
  `DisplayManager`.
- No hay pruebas automatizadas que documenten contratos de escenas o Resources.

## 12. Funciones parciales o planeadas

- **Parcialmente implementado:** reacomodo tras cambiar resolución.
- **Planeado:** ralentización runtime por RAM.
- **Implementado:** perfiles, guardado/carga, snapshots de enemigos y
  restauración coordinada.
- **Parcialmente implementado:** game over.
- **Implementado:** pausa del `SceneTree` y retorno a MainMenu desde el menú
  Inicio, coordinados por Taskbar, `DesktopSaveCoordinator` y `ProfileService`.
- **Implementado:** Save Game del menú Inicio.
- **Implementado:** Load Game existe únicamente en MainMenu.
- **Implementado:** menú principal funcional, borrado de perfiles y transiciones
  locales de ventana entre MainMenu y Desktop.
- **Parcialmente implementado:** diseño visual definitivo del menú principal.
- **Planeado:** Options.

## 13. Registro de preguntas arquitectónicas

- **Resuelto (Q-ARCH-001):** el coordinador se ejecuta después de Taskbar y
  managers; reloj/director arrancan al finalizar nueva partida o restore.
- **Q-ARCH-002:** ¿la taskbar debe minimizar/restaurar además de enfocar?
- **Q-ARCH-003:** ¿Miner y Virus deben separar lógica de sus nodos de UI?
- **Resuelto (Q-ARCH-004):** `GameState` no conserva API de fachada; sólo
  localización tipada, carga inicial y reset de estados.
- **Resuelto (Q-ARCH-005):** `DesktopSaveCoordinator` coordina el snapshot
  jugable; `ProfileService` y `ProfileStore` administran sesión de perfil y
  archivos.
- **Q-ARCH-006:** ¿se desea determinismo o persistencia del RNG de las oleadas?
- **Q-ARCH-007:** ¿qué referencias de escena deben considerarse API estable?
