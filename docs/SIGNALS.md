# Signals

## 1. Alcance

Este documento registra señales de dominio y coordinación. Las señales nativas de
Godot (`pressed`, `timeout`, `resized`, `gui_input`) se mencionan solo cuando
forman parte importante del flujo.

## 2. Convenciones observadas

- Los cambios de estado compartido se realizan mediante comandos del estado
  especializado propietario; ese mismo estado emite la señal de dominio.
- `GameState` no declara ni retransmite señales. Sólo permite resolver una vez
  las referencias tipadas durante la inicialización del consumidor.
- Managers escuchan `WindowManager` para descubrir ventanas por tipo concreto.
- Ventanas emiten solicitudes; managers deciden y mutan gameplay.
- Consultas síncronas usan llamadas directas.
- Varias señales funcionan como puntos de extensión y todavía no tienen
  consumidores.

## 3. Señales de estados especializados

| Emisor propietario | Señal | Consumidores actuales | Estado |
|---|---|---|---|
| `GameSystemState` | `system_integrity_changed(current, max)` | `SystemManager` | Implementado |
| `GameSystemState` | `system_destroyed()` | `SystemManager` | Implementado |
| `GameWeaponState` | `ammo_changed(current, max)` | `ShootingManager`, `ReloadManager` | Implementado |
| `GameWeaponState` | `weapon_stats_changed(damage, cooldown)` | Ninguno | Parcialmente implementado |
| `GameReloadStatsState` | `reload_stats_changed(normal, perfect, penalty)` | `ReloadManager` | Implementado |
| `GameMinerState` | `miner_stats_changed(amount, interval)` | `MinerWindow` | Implementado |
| `GameEconomyState` | `crypto_changed(current)` | `ShopWindow`, `TaskbarSystemTray` | Implementado |
| `GameEconomyState` | `virus_data_changed(current)` | `ShopWindow`, `TaskbarSystemTray` | Implementado |
| `GameEconomyState` | `enemy_kills_changed(total)` | Ninguno | Parcialmente implementado |
| `GameOverclockState` | `phase_changed(phase)` | `OverclockWindow`, `TaskbarSystemTray` | Implementado |
| `GameOverclockState` | `overclock_ready()` | Punto de extensión | Implementado |
| `GameOverclockState` | `overclock_started(multiplier, duration)` | Punto de extensión | Implementado |
| `GameOverclockState` | `overclock_time_changed(remaining)` | `OverclockWindow` | Implementado; sólo cambia por segundo visible |
| `GameOverclockState` | `overclock_finished()` | Punto de extensión | Implementado |
| `GameOverclockState` | `overclock_cooldown_changed(remaining)` | `OverclockWindow` | Implementado; sólo cambia por segundo visible |
| `GameOverclockState` | `attempt_resolved(success)` | `OverclockWindow` | Implementado |
| `GameRamState` | `ram_changed(used, max)` | `TaskbarSystemTray` | Implementado |
| `GameDesktopState` | `desktop_resolution_changed(resolution, tier)` | `DisplayManager` | Implementado |
| `GameDesktopState` | `desktop_shortcuts_changed(snapshot)` | Ninguno | Planeado |
| `GameUpgradeState` | `upgrade_purchase_counts_changed(snapshot)` | `ShopWindow`, `FirewallWindow`, `SlowdownWindow`, `TurretWindow` | Implementado |
| `GameUpgradeState` | `auto_reload_changed(enabled)` | `ReloadManager` | Implementado |
| `GameUpgradeState` | `auto_fire_changed(enabled)` | `ShootingManager` | Implementado |
| `GameUpgradeState` | `area_shot_changed(unlocked, max_targets)` | `ShootingManager` | Implementado |
| `GameClockState` | `time_changed(total_game_minutes)` | `TaskbarSystemTray` | Implementado |
| `GameClockState` | `hour_changed(hour)` | Ninguno | Punto de extensión |
| `GameClockState` | `day_changed(game_day_index)` | `TaskbarSystemTray` | Implementado |
| `GameClockState` | `clock_speed_changed(game_minutes_per_real_second)` | Ninguno | Punto de extensión |
| `GameRunState` | `spawn_mode_changed(mode)` | `EnemySpawnDirector` | Implementado |
| `GameRunState` | `spawn_phase_changed(phase)` | Ninguno | Punto de extensión |
| `GameRunState` | `wave_budget_changed(current, maximum)` | Ninguno | Punto de extensión |
| `GameRunState` | `run_progress_changed(snapshot)` | Ninguno | Preparación para persistencia |
| `GameEnemySnapshotState` | `enemy_snapshots_changed(snapshots)` | Ninguno | Planeado |

`GameState.reset_run()` invoca el reset de cada propietario. Cada estado emite su
propio valor actualizado; ya no existe `_emit_all_state()` ni un broadcast
global.

- **Implementado:** los consumidores activos consultan valores iniciales desde
  su estado cuando se crean.
- **Implementado:** el orden global de restauración es contractual en
  `DesktopSaveCoordinator`; dentro de cada estado, sus señales se emiten al
  terminar de aplicar su propia sección.

## 4. Desktop y ventanas

| Señal | Emisor | Consumidor | Propósito | Estado |
|---|---|---|---|---|
| `open_requested(program_data)` | `DesktopExecutable` | `Desktop` | Abrir app | Implementado |
| `moved(position)` | `DesktopExecutable` | `Desktop` | Persistir posición | Implementado |
| `executable_spawned(executable, data)` | `Desktop` | `SystemManager` | Registrar System | Implementado |
| `focus_requested(window)` | `AppWindow` | `WindowManager` | Subir foco | Implementado |
| `close_requested(window)` | `AppWindow` | `WindowManager` | Cerrar y liberar RAM | Implementado |
| `opening_started(window)` | `AppWindow` | Ninguno | Hook de animación | Desconocido |
| `opening_finished(window)` | `AppWindow` | `MinerWindow` | Iniciar minería | Implementado |
| `window_opened(window, data)` | `WindowManager` | Managers especializados | Bind | Implementado |
| `window_closed(window)` | `WindowManager` | Managers especializados | Unbind | Implementado |
| `window_focused(window)` | `WindowManager` | `TaskbarManager` | Botón activo | Implementado |
| `firewall_established(window)` | `FirewallNavigationManager` | Ninguno | Extensión tras registro atómico | Implementado |
| `firewall_unestablished(window)` | `FirewallNavigationManager` | Ninguno | Extensión tras desregistro | Implementado |
| `firewall_obstacles_changed()` | `FirewallNavigationManager` | `EnemyManager` | Invalidar todos los paths antes del rebuild | Implementado |
| `navigation_rebuilt(revision)` | `FirewallNavigationManager` | Ninguno directo | Publicar la revisión después de que `NavigationServer2D` sincroniza el mapa | Implementado |

Managers que consumen `window_opened/window_closed`:

- `SystemManager`
- `ShootingManager`
- `ReloadManager`
- `RepairManager`
- `ShopManager`
- `TaskbarManager`
- `FirewallNavigationManager`

Durante restore, `WindowManager` emite `window_opened` exactamente una vez por
ventana reconstruida para reutilizar esos bindings. No emite compras ni
animaciones de apertura.

`TurretWindow` no agrega señales públicas ni depende de los relays de Shooting.
`WindowManager` le inyecta `EnemyManager` y la referencia a sí mismo al
instanciarla; la torreta consulta enemigos registrados, línea de visión y aplica
daño mediante llamadas tipadas directas. El tracer y el recoil son feedback local
sin eventos de gameplay.

`SlowdownWindow` tampoco agrega señales públicas. Recibe `EnemyManager` por el
mismo contrato, registra/desregistra su fuente mediante llamadas tipadas y el
manager deriva el multiplicador efectivo. No se crean señales por frame ni una
conexión por pareja de ventana/enemigo.

Las tres defensas escuchan directamente
`GameUpgradeState.upgrade_purchase_counts_changed`: Firewall actualiza y
revalida geometría, Slowdown refresca su fuente ya registrada y Turret recalcula
stats conservando la proporción del cooldown. `UpgradeManager` no agrega relays.

`AdwareVirus` tampoco introduce señales globales. Consulta candidatos mediante
llamadas tipadas a `WindowManager`; la creación de Spam reutiliza
`window_opened/window_closed`, mientras `TaskbarManager` ignora esas instancias por
la capacidad `show_in_taskbar = false`.

## 5. Shooting y recarga

| Señal | Emisor | Consumidor | Estado |
|---|---|---|---|
| `fire_requested(shooter, position)` | `ShootingWindow` | `ShootingManager` | Implementado |
| `ammo_changed(current, max)` | `ShootingManager` | AmmoWindows vinculadas | Implementado |
| `shot_fired(position, damage)` | `ShootingManager` | `EnemyManager` | Implementado |
| `cooldown_started(duration)` | `ShootingManager` | Ninguno | Desconocido |
| `cooldown_finished()` | `ShootingManager` | Ninguno | Desconocido |
| `shot_blocked(position)` | `ShootingManager` | Ninguno | Parcialmente implementado |
| `shot_rejected(reason)` | `ShootingManager` | Ninguno | Parcialmente implementado |
| `reload_lock_changed(active)` | `ShootingManager` | Ninguno | Desconocido |
| `reload_input_requested(window)` | `ReloadWindow` | `ReloadManager` | Implementado |
| `reload_started()` | `ReloadManager` | Ninguno | Desconocido |
| `reload_penalty_started()` | `ReloadManager` | Ninguno | Desconocido |
| `perfect_reload_triggered()` | `ReloadManager` | Ninguno | Desconocido |
| `reload_completed()` | `ReloadManager` | Ninguno | Desconocido |
| `reload_rejected(reason)` | `ReloadManager` | Ninguno | Parcialmente implementado |

- **Parcialmente implementado:** las ventanas reciben presentación por llamadas
  directas, mientras las señales públicas de feedback no se consumen.
- **Desconocido (Q-SIG-002):** confirmar si esas señales están destinadas a
  audio, HUD, analytics o deben eliminarse.

## 6. Sistema, reparación y enemigos

| Señal | Emisor | Consumidor | Estado |
|---|---|---|---|
| `system_target_registered(executable)` | `SystemManager` | `EnemyManager` | Implementado |
| `system_integrity_changed(current, max)` | `SystemManager` | Ninguno | Desconocido |
| `system_destroyed()` | `SystemManager` | `EnemySpawnDirector`, `GameClockManager` | Implementado |
| `health_changed(current, max)` | `DesktopVirus` | Ninguno | Desconocido |
| `died(virus)` | `DesktopVirus` | `EnemyManager` | Implementado |
| `dragging_changed(virus, active)` | `DesktopVirus` | `AdwareVirus` (su propia instancia) | Implementado para cancelar ocultamiento |
| `enemy_spawned(enemy)` | `EnemyManager` | Ninguno | Desconocido |
| `enemy_removed(enemy)` | `EnemyManager` | Ninguno | Desconocido |
| `director_started()` | `EnemySpawnDirector` | Ninguno | Desconocido |
| `director_stopped()` | `EnemySpawnDirector` | Ninguno | Desconocido |
| `day_started(game_day, wave_configuration_index)` | `EnemySpawnDirector` | Ninguno | Punto de extensión |
| `active_period_started(game_day)` | `EnemySpawnDirector` | Ninguno | Punto de extensión |
| `rest_period_started(game_day)` | `EnemySpawnDirector` | Ninguno | Punto de extensión |
| `repair_started()` | `RepairManager` | Ninguno | Desconocido |
| `repair_stopped()` | `RepairManager` | Ninguno | Desconocido |
| `repair_tick(amount)` | `RepairManager` | Ninguno | Desconocido |

El cambio automático al infinito usa
`GameRunState.spawn_mode_changed(INFINITE)`. No se agregó una señal de stage ni
un evento por grupo: cada enemigo de spawn normal conserva una única emisión de
`EnemyManager.enemy_spawned`, mientras restore no la emite.

## 7. Shop y upgrades

| Señal | Emisor | Consumidor | Estado |
|---|---|---|---|
| `app_purchase_requested(shop, offer)` | `ShopWindow` | `ShopManager` | Implementado |
| `upgrade_purchase_requested(shop, offer)` | `ShopWindow` | `ShopManager` | Implementado |
| `app_purchase_requested(offer)` | `ShopOfferRow` | `ShopWindow` | Implementado |
| `upgrade_purchase_requested(offer)` | `ShopOfferRow` | `ShopWindow` | Implementado |
| `upgrade_purchased(offer, count)` | `UpgradeManager` | Ninguno | Desconocido |
| `upgrades_changed()` | `UpgradeManager` | `ShopManager`, `ShopWindow` | Implementado |

## 8. Taskbar

| Señal | Emisor | Consumidor | Estado |
|---|---|---|---|
| `focus_requested(window)` | `TaskbarAppButton` | `TaskbarManager` | Implementado |
| `reorder_drag_started(button)` | `TaskbarAppButton` | `TaskbarManager` | Parcialmente implementado |
| `reorder_drag_moved(button, position)` | `TaskbarAppButton` | `TaskbarManager` | Implementado |
| `reorder_drag_ended(button, position)` | `TaskbarAppButton` | `TaskbarManager` | Implementado |
| `save_requested()` | `Taskbar` | `DesktopSaveCoordinator` | Implementado |
| `return_to_main_menu_requested()` | `Taskbar` | `DesktopSaveCoordinator` | Implementado |

El handler de inicio de drag contiene `pass`; el movimiento y fin realizan el
reordenamiento, por lo que el flujo funciona sin una acción de inicio adicional.

Taskbar no contiene un control de carga. La carga pertenece exclusivamente al
menú principal.

## 9. Perfiles y persistencia

| Emisor | Señal | Consumidor actual | Estado |
|---|---|---|---|
| `ProfileService` | `profiles_changed()` | Ninguno; MainMenu usa resultado síncrono | Punto de extensión |
| `ProfileService` | `active_profile_changed(profile_id)` | Ninguno | Punto de extensión |
| `ProfileService` | `session_requested(mode, profile_id)` | Ninguno | Punto de extensión |
| `ProfileService` | `session_initialization_completed(result)` | Ninguno | Punto de extensión |
| `ProfileService` | `save_completed(result)` | Futuro feedback | Punto de extensión |
| `DesktopSaveCoordinator` | `save_finished(result)` | `Taskbar.present_save_result()` | Implementado; muestra feedback sólo si fue exitoso |
| `DesktopSaveCoordinator` | `restore_finished(result)` | `DesktopWindowRevealController` | Implementado |
| `MainMenuWindow` | `close_requested()` | `MainMenu` | Implementado |

`PersistenceResult` es el contrato síncrono principal del menú y mantiene la
lógica de archivos fuera de UI. El coordinador consume una intención pendiente
de `ProfileService` una sola vez. El revelado visual de Desktop espera
`restore_finished`; no infiere por su cuenta cuándo terminó la restauración ni
emite señales funcionales de apertura de ventana.

## 10. Conexiones dinámicas

- `WindowManager` conecta `focus_requested` y `close_requested` al instanciar.
- `WindowManager` entrega sus servicios runtime a cada `AppWindow`;
  `TurretWindow` y `SlowdownWindow` consumen actualmente `EnemyManager` mediante
  ese contrato.
- `ShootingManager` conecta/desconecta Shooting y AmmoWindows según apertura.
- `ReloadManager` conecta ReloadWindow al descubrirla.
- `ShopManager` registra cada ShopWindow y sus solicitudes.
- `ShopWindow` conecta dinámicamente cada fila creada.
- `TaskbarManager` crea botones y conecta foco/reordenamiento.
- `EnemyManager` conecta `died` para cada enemigo generado.
- `FirewallNavigationManager` conecta apertura/cierre de ventanas, vincula sólo
  las instancias Firewall y publica una revisión después de la sincronización
  física de cada rebuild. `EnemyManager` escucha el cambio agregado para
  invalidar rutas; los enemigos no se conectan a cada Firewall.
- `TaskbarSystemTray` conecta el tiempo y el día del `GameClockState` que resolvió
  al inicializarse.
- `OverclockManager` conecta las intenciones de la única `OverclockWindow` al
  abrirla y normaliza `TYPING` al cerrarla; el estado y sus timers no pertenecen
  a la ventana.
- `TaskbarSystemTray` conecta `phase_changed` de `GameOverclockState` y actualiza
  el indicador sin polling por frame.
- `EnemySpawnDirector` conecta cambios de modo de `GameRunState` y consulta el
  `GameClockState` que resolvió al inicializarse.
- `DesktopSaveCoordinator` conecta `Taskbar.save_requested` y
  `Taskbar.return_to_main_menu_requested` después de que la escena completa está
  lista.

- **Implementado:** los bindings de ventana se limpian explícitamente en varios
  managers o desaparecen al liberar el emisor.
- **Implementado:** managers y ventanas conectan al estado específico resuelto en
  `_ready()`; no hay conexiones globales a señales de `GameState`.
- **Riesgo:** no existe todavía una política general de desconexión para nodos
  que puedan sobrevivir al emisor; en la composición actual los estados duran
  toda la sesión.

## 11. Señales planeadas o sin consumidor

No debe asumirse que una señal sin consumidor está obsoleta. Antes de eliminar o
integrar cualquiera, consultar su propósito.

Grupos pendientes:

- Feedback de arma y recarga.
- HUD de fase diaria, día y presupuesto.
- Salud/drag/spawn de enemigos.
- Eventos de reparación.
- Feedback visual de éxito/error de perfiles, save y load.
- Telemetría de upgrades y muertes.

## 12. Registro de preguntas sobre señales

- **Resuelto (Q-SIG-001):** restore ocurre con gameplay detenido; estados,
  shortcuts, ventanas, enemigos y procesos se restauran en ese orden antes de
  arrancar reloj/director y emitir finalización.
- **Q-SIG-002:** ¿qué consumidores futuros tendrán las señales de arma/recarga?
- **Q-SIG-003:** ¿fase diaria, día y presupuesto deben mostrarse en HUD?
- **Q-SIG-004:** ¿las señales relay de SystemManager deben conservarse?
- **Q-SIG-005:** ¿qué señales son API pública estable?
- **Resuelto (Q-SIG-006):** los consumidores conectan directamente al estado
  propietario conservado durante la sesión; no conectan al contenedor
  `GameState`.
- **Q-SIG-007:** ¿eventos sin consumidor deben documentarse como extensiones o
  convertirse en llamadas directas?
