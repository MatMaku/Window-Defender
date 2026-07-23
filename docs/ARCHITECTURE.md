# Architecture

## 1. Alcance

Este documento registra la arquitectura observada. Las reglas obligatorias para
futuros cambios siguen estando en `AGENTS.md`.

## 2. Arranque

`project.godot` configura:

- `Scenes/Desktop/Desktop.tscn` como `run/main_scene`.
- `Scenes/Autoload/GameState.tscn` como único autoload, con nombre `GameState`.

Flujo aproximado:

```text
GameState._ready()
  -> reset_run()
  -> estados de dominio restaurados desde GameStart.tres

Desktop.tscn
  -> managers conectan dependencias y señales
  -> Desktop._ready() crea shortcuts
  -> SystemManager registra System.exe
  -> EnemySpawnDirector inicia diferidamente
```

- **Implementado:** este flujo está conectado en escenas y scripts.
- **Desconocido (Q-ARCH-001):** no hay contrato documentado para depender del
  orden de `_ready()` más allá de la composición actual.

## 3. Escena principal

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
- `EnemyManager`
- `EnemySpawnDirector`
- `UpgradeManager`
- `RepairManager`

- **Implementado:** las referencias críticas están exportadas y asignadas en la
  escena.
- **Implementado:** muchos managers incluyen resolución relativa como fallback.
- **Riesgo:** varios fallbacks dependen de una jerarquía concreta y no coinciden
  necesariamente con la ruta real fuera de `Desktop.tscn`.

## 4. Estado compartido

`Scripts/Autoload/GameState.gd` (`RuntimeGameState`) es el contenedor estable de
la sesión. `Scenes/Autoload/GameState.tscn` sigue siendo el único autoload y
compone diez nodos especializados.

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
| `GameRunState` | Tiempo, stage y presupuesto |
| `GameEnemySnapshotState` | Array de snapshots futuros |

- **Implementado:** `GameState` sólo conserva `start_data`, referencias tipadas,
  `reset_run()` e inicialización privada. No replica propiedades, comandos ni
  señales de dominio.
- **Implementado:** sistema, arma, recarga, minería, economía, RAM, desktop y
  upgrades protegen sus datos mediante backing fields, exponen consultas y
  comandos explícitos, y emiten sus propias señales.
- **Implementado:** los consumidores resuelven una sola vez los estados que
  necesitan desde `GameState` y conservan referencias tipadas específicas.
- **Parcialmente implementado:** `GameRunState` y
  `GameEnemySnapshotState` son propietarios y emisores de sus eventos, pero sus
  campos runtime siguen expuestos y su diseño queda pendiente del futuro flujo
  de persistencia.
- **Riesgo:** el acceso inicial sigue siendo global. Es un acoplamiento aceptado
  en esta etapa, limitado a localización de sesión durante `_ready()`.

API pública final del contenedor:

- `start_data`
- `system_state`, `weapon_state`, `reload_stats_state`, `miner_state`
- `economy_state`, `ram_state`, `desktop_state`, `upgrade_state`
- `run_state`, `enemy_snapshot_state`
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
| `ShootingManager` | Ventana Shooting activa, cooldown y lock de recarga |
| `ReloadManager` | Máquina de estados y timers de recarga |
| `EnemyManager` | Array de enemigos vivos |
| `EnemySpawnDirector` | Progreso temporal antes de sincronizarlo |
| `RepairManager` | Ventana activa y progreso de tick |
| `ShopManager` | Ventanas Shop activas |
| `SystemManager` | Referencias al shortcut y ventana System |
| `MinerWindow` | Timer de minería por instancia |

- **Implementado:** el estado compartido y el transitorio están separados en la
  mayoría de los sistemas.
- **Riesgo:** `Desktop`/`GameDesktopState` y
  `EnemySpawnDirector`/`GameRunState` mantienen representaciones relacionadas
  que pueden divergir si se agregan flujos de carga.

## 6. Dependencias principales

```text
GameState -> estados especializados

Desktop -> GameDesktopState
DesktopExecutable -> WindowManager -> RamManager -> GameRamState

EnemySpawnDirector -> GameRunState
                   -> EnemyManager -> GameEconomyState
                                   -> DesktopVirus/BasicVirus
                                   -> SystemManager -> GameSystemState

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
- **Implementado:** los errores de RAM usan `SystemErrorWindow` sin costo.
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

## 9. Persistencia

- **Implementado:** `GameDesktopState`, `GameUpgradeState`, `GameRunState` y
  `GameEnemySnapshotState` producen snapshots parciales en memoria.
- **Planeado:** `GameEnemySnapshotState` reserva un Array para enemigos.
- **Planeado:** el director tiene una API de restauración.
- **Parcialmente implementado:** no existe serializador, archivo de guardado,
  versionado ni restauración coordinada.
- **Riesgo:** el autostart actual llama `start_director()` con reset por defecto,
  por lo que descartaría progreso cargado si no se coordina el arranque.

## 10. Escalabilidad y riesgos

- `GameState` sigue siendo el punto global de localización inicial, aunque ya no
  participa en la lógica interna de los consumidores.
- `UpgradeManager` necesita siete estados porque aplica efectos de varios
  dominios; es coordinación explícita, pero sigue siendo un punto de alto
  acoplamiento que debe vigilarse al agregar nuevos efectos.
- El reset de estados persistentes no reconstruye ventanas, enemigos ni otros
  objetos runtime; ese alcance permanece fuera de este refactor.
- `EnemyManager` separa enemigos en O(n²) por frame; Stage 8 permite 100.
- Bloqueo de disparos y reparación recorre ventanas y no usa el helper de ventanas
  superiores.
- IDs y requisitos se conectan manualmente con `StringName`.
- Resources no tienen una validación global de unicidad o consistencia.
- Métodos de layout son invocados opcionalmente por nombre desde
  `DisplayManager`.
- No hay pruebas automatizadas que documenten contratos de escenas o Resources.

## 11. Funciones parciales o planeadas

- **Parcialmente implementado:** reacomodo tras cambiar resolución.
- **Planeado:** ralentización runtime por RAM.
- **Planeado:** guardado/carga y snapshots de enemigos.
- **Parcialmente implementado:** game over.
- **Planeado:** acciones del menú Inicio.

## 12. Registro de preguntas arquitectónicas

- **Q-ARCH-001:** ¿qué orden de inicialización debe considerarse contractual?
- **Q-ARCH-002:** ¿la taskbar debe minimizar/restaurar además de enfocar?
- **Q-ARCH-003:** ¿Miner y Virus deben separar lógica de sus nodos de UI?
- **Resuelto (Q-ARCH-004):** `GameState` no conserva API de fachada; sólo
  localización tipada, carga inicial y reset de estados.
- **Q-ARCH-005:** ¿qué manager coordinará guardado, carga y restauración?
- **Q-ARCH-006:** ¿se desea determinismo o persistencia del RNG de los stages?
- **Q-ARCH-007:** ¿qué referencias de escena deben considerarse API estable?
