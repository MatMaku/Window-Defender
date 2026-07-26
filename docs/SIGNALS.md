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
| `GameRamState` | `ram_changed(used, max)` | `TaskbarSystemTray` | Implementado |
| `GameDesktopState` | `desktop_resolution_changed(resolution, tier)` | `DisplayManager` | Implementado |
| `GameDesktopState` | `desktop_shortcuts_changed(snapshot)` | Ninguno | Planeado |
| `GameUpgradeState` | `upgrade_purchase_counts_changed(snapshot)` | `ShopWindow` | Implementado |
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
- **Desconocido (Q-SIG-001):** definir si el orden entre señales de distintos
  estados durante reset o futura carga debe ser contractual.

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

Managers que consumen `window_opened/window_closed`:

- `SystemManager`
- `ShootingManager`
- `ReloadManager`
- `RepairManager`
- `ShopManager`
- `TaskbarManager`

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
| `dragging_changed(virus, active)` | `DesktopVirus` | Ninguno | Desconocido |
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

El handler de inicio de drag contiene `pass`; el movimiento y fin realizan el
reordenamiento, por lo que el flujo funciona sin una acción de inicio adicional.

## 9. Conexiones dinámicas

- `WindowManager` conecta `focus_requested` y `close_requested` al instanciar.
- `ShootingManager` conecta/desconecta Shooting y AmmoWindows según apertura.
- `ReloadManager` conecta ReloadWindow al descubrirla.
- `ShopManager` registra cada ShopWindow y sus solicitudes.
- `ShopWindow` conecta dinámicamente cada fila creada.
- `TaskbarManager` crea botones y conecta foco/reordenamiento.
- `EnemyManager` conecta `died` para cada enemigo generado.
- `TaskbarSystemTray` conecta el tiempo y el día del `GameClockState` que resolvió
  al inicializarse.
- `EnemySpawnDirector` conecta cambios de modo de `GameRunState` y consulta el
  `GameClockState` que resolvió al inicializarse.

- **Implementado:** los bindings de ventana se limpian explícitamente en varios
  managers o desaparecen al liberar el emisor.
- **Implementado:** managers y ventanas conectan al estado específico resuelto en
  `_ready()`; no hay conexiones globales a señales de `GameState`.
- **Riesgo:** no existe todavía una política general de desconexión para nodos
  que puedan sobrevivir al emisor; en la composición actual los estados duran
  toda la sesión.

## 10. Señales planeadas o sin consumidor

No debe asumirse que una señal sin consumidor está obsoleta. Antes de eliminar o
integrar cualquiera, consultar su propósito.

Grupos pendientes:

- Feedback de arma y recarga.
- HUD de fase diaria, día y presupuesto.
- Salud/drag/spawn de enemigos.
- Eventos de reparación.
- Persistencia de shortcuts, run y enemigos.
- Telemetría de upgrades y muertes.

## 11. Registro de preguntas sobre señales

- **Q-SIG-001:** ¿el orden de señales durante reset/carga es contractual?
- **Q-SIG-002:** ¿qué consumidores futuros tendrán las señales de arma/recarga?
- **Q-SIG-003:** ¿fase diaria, día y presupuesto deben mostrarse en HUD?
- **Q-SIG-004:** ¿las señales relay de SystemManager deben conservarse?
- **Q-SIG-005:** ¿qué señales son API pública estable?
- **Resuelto (Q-SIG-006):** los consumidores conectan directamente al estado
  propietario conservado durante la sesión; no conectan al contenedor
  `GameState`.
- **Q-SIG-007:** ¿eventos sin consumidor deben documentarse como extensiones o
  convertirse en llamadas directas?
