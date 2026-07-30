# Data Model

## 1. Alcance

Este documento registra los Resources, el estado runtime y las convenciones de
identidad observadas. Las rutas `.tres` son parte de la configuración jugable.

## 2. Resources de configuración

| Tipo | Script | Responsabilidad | Estado |
|---|---|---|---|
| `GameStartData` | `Data/GameState/GameStartData.gd` | Valores iniciales | Implementado |
| `ProgramData` | `Data/Programs/ProgramData.gd` | Identidad y ventana de una app | Implementado |
| `DesktopShortcutData` | `Data/Programs/DesktopShortcutData.gd` | App y posición inicial | Implementado |
| `ShopAppOfferData` | `Data/Shop/ShopAppOfferData.gd` | Oferta de aplicación | Implementado |
| `ShopUpgradeOfferData` | `Data/Shop/ShopUpgradeOfferData.gd` | Costos, requisitos y efecto | Implementado |
| `EnemyArchetypeData` | `Data/Enemies/EnemyArchetypeData.gd` | Escena y stats base de un arquetipo | Implementado |
| `WaveEnemyEntry` | `Data/Waves/WaveEnemyEntry.gd` | Peso, coste, límite y multiplicadores | Implementado |
| `DailyWaveData` | `Data/Waves/DailyWaveData.gd` | Presupuesto y reglas de un día | Implementado |
| `WaveSequenceData` | `Data/Waves/WaveSequenceData.gd` | Horario común y secuencia de días | Implementado |
| `GameContentRegistry` | `Data/Persistence/GameContentRegistry.gd` | Registro de IDs persistentes | Implementado |

## 3. GameStartData

Recurso activo: `Data/GameState/GameStart.tres`.

Campos:

- Sistema: `max_system_integrity`.
- Arma: `shot_damage`, `fire_cooldown_seconds`, `max_ammo`.
- Recarga: duración normal, delay perfecto y penalización.
- Minería: cantidad por tick e intervalo.
- Economía: recursos iniciales.
- RAM: máximo inicial.
- Desktop: tier inicial y lista de resoluciones.

- **Implementado:** los estados especializados validan mínimos al resetear.
- **Riesgo:** el Resource no incluye versión de esquema.
- **Desconocido (Q-DATA-001):** confirmar si los overrides de 10.000 son datos de
  desarrollo.

## 4. ProgramData y shortcuts

`ProgramData` contiene:

- `program_id: StringName`
- `display_name`
- `icon`
- `window_scene`
- `allow_multiple_instances`
- posición y tamaño por defecto
- `ram_cost`

Programas actuales:

| ID | RAM | Múltiples instancias | Disponibilidad |
|---|---:|---|---|
| System | 8 | No | Inicial |
| Miner | 28 | Sí | Inicial |
| Shop | 8 | No | Inicial |
| Shooting | 18 | No | Tienda |
| Ammo | 6 | No | Tienda |
| Reload | 12 | No | Tienda |
| Repair | 20 | No | Tienda |
| Firewall | 32 | Sí | Tienda |
| test | 20 | Sí | No integrado |

Fuentes: `Apps/*/*Program.tres`.

Shortcuts iniciales activos:

- `Apps/System/SystemShortcut.tres`
- `Apps/Miner/MinerShortcut.tres`
- `Apps/Shop/ShopShortcut.tres`

Los shortcuts de Shooting, Ammo, Reload, Repair, Firewall y Test existen, pero no están
referenciados por `Desktop.tscn`; las compras crean `DesktopShortcutData` en
runtime a partir del `ProgramData`.

- **Implementado:** IDs se usan como claves de ventana, shortcut y requisitos.
- **Desconocido (Q-DATA-002):** definir convención canónica de mayúsculas para
  `program_id`.

## 5. Ofertas de aplicaciones

| Programa | Precio |
|---|---:|
| Ammo | 5 crypto |
| Reload | 15 crypto |
| Shooting | 20 crypto |
| Repair | 45 crypto |
| Firewall | 250 crypto (provisional) |

Fuentes: `Shop/Apps/*.tres`.

- **Implementado:** `offer_id` puede usar `program_id` como fallback.
- **Implementado:** nombre e icono pueden sobrescribirse.

## 6. Ofertas de upgrades

Tipos de efecto declarados en `Data/Shop/ShopUpgradeOfferData.gd`:

- sumar daño;
- multiplicar cooldown;
- sumar munición máxima;
- multiplicar duración de recarga;
- sumar producción minera;
- reducir intervalo minero;
- sumar RAM;
- avanzar resolución;
- desbloquear Auto Fire;
- desbloquear Area Shot;
- sumar objetivos de Area Shot;
- desbloquear Auto Reload.

Resources activos en `Apps/Shop/ShopWindow.tscn`:

- `Damage.tres`
- `Cooldown.tres`
- `Ammo.tres`
- `Reload.tres`
- `MinerTick.tres`
- `MinerTime.tres`
- `RAM.tres`
- `Resolution.tres`
- `AutoReload.tres`
- `AutoShoot.tres`
- `AreaShoot.tres`

- **Implementado:** costos por nivel usan el último valor si el índice excede el
  tamaño del Array.
- **Implementado:** algunos upgrades requieren programa u otro upgrade.
- **Parcialmente implementado:** `AREA_SHOT_TARGETS_ADD` no tiene una oferta
  configurada; Area Shot fuerza al menos un objetivo.
- **Implementado:** `GameContentRegistry.tres` valida unicidad de los
  `offer_id` persistidos.
- **Riesgo:** no existe validación central de coherencia entre arrays, niveles y
  efectos `NONE`.

## 7. Arquetipos y stats de enemigos

Arquetipo activo:

- `Stages/Daily/Archetypes/BasicVirus.tres`

`EnemyArchetypeData` define:

- ID, nombre y `PackedScene`;
- salud, velocidad, daño e intervalo de ataque base;
- distancias de llegada y overlap;
- recompensa base y coste de spawn por defecto.

`WaveEnemyEntry` agrega peso, override opcional de coste, máximo vivo por
`enemy_id` y multiplicadores de stats.

`EnemyRuntimeStats` (`Data/Enemies/EnemyRuntimeStats.gd`) es una estructura
`RefCounted` nueva por spawn. El valor final es:

```text
base del arquetipo × multiplicador del día × multiplicador de la entrada
```

- **Implementado:** la instancia copia esos valores antes de entrar al árbol.
- **Implementado:** no se mutan el arquetipo, el día ni la entrada compartidos.
- **Implementado:** el arquetipo Basic conserva los defaults actuales de
  `Scenes/Virus/BasicVirus.tscn`.
- **Planeado:** FastVirus y TankVirus podrán usar escenas y arquetipos propios;
  todavía no existen.

## 8. Secuencia y configuración diaria

Resource de producción:

- `Stages/Daily/DailyWaveSequence.tres`

Dependencias:

- `Stages/Daily/Days/Day01.tres`
- `Stages/Daily/Entries/BasicVirusEntry.tres`
- `Stages/Daily/Archetypes/BasicVirus.tres`

Configuración provisional:

| Campo | Valor editable |
|---|---:|
| Inicio activo común | 120 (02:00) |
| Fin activo común | 0 (00:00) |
| Presupuesto diario | 8 |
| Intervalo | 30 minutos ficticios |
| Máximo activo | 4 |
| Arquetipos | BasicVirus |

- **Implementado:** cada día puede usar el horario común o activar un override.
- **Implementado:** inicio igual a fin representa actividad todo el día.
- **Implementado:** horarios con inicio mayor que fin cruzan medianoche.
- **Implementado:** si el índice excede `days`, se mantiene el último Resource.
- **Implementado:** el peso se expresa una sola vez; no se duplican entradas en
  el Array.
- **Parcialmente implementado:** los valores son configuración de prueba, no
  balance final.

## 9. Estado runtime

`Scenes/Autoload/GameState.tscn` compone los propietarios descritos en
`docs/ARCHITECTURE.md`. `Scripts/Autoload/GameState.gd` sólo los inicializa,
resetea y expone como referencias tipadas.

| Datos | Propietario runtime | Mutación |
|---|---|---|
| Integridad y destrucción | `GameSystemState` | `take_damage()`, `heal()`, `set_max_integrity()` |
| Daño, cooldown y munición | `GameWeaponState` | comandos de arma y munición |
| Tiempos de recarga | `GameReloadStatsState` | setters con clamps |
| Producción minera | `GameMinerState` | comandos de cantidad e intervalo |
| Crypto, datos y muertes | `GameEconomyState` | comandos transaccionales de economía |
| RAM máxima y usada | `GameRamState` | reserva, liberación y cambio de máximo |
| Resolución y shortcuts | `GameDesktopState` | comandos de desktop |
| Compras y automatizaciones | `GameUpgradeState` | comandos de upgrades |
| Fecha, hora y velocidad | `GameClockState` | avance, velocidad y restauración |
| Progreso diario | `GameRunState` | comandos de modo, fase, día y presupuesto |
| Snapshots de enemigos | `GameEnemySnapshotState` | comandos de snapshots |

- **Implementado:** reloj y progreso diario también usan backing fields privados.
- **Implementado:** no hay escritores directos confirmados sobre esos backing
  fields; managers y ventanas usan comandos del propietario.
- **Implementado:** los estados productivos exponen `create_save_snapshot()` y
  `restore_from_save_snapshot()` con valores serializables y clamps.
- **Parcialmente implementado:** `GameEnemySnapshotState` conserva su Array
  histórico, pero el snapshot productivo de enemigos pertenece a
  `EnemyManager` y a cada `DesktopVirus`.

Snapshots auxiliares disponibles en memoria:

- `GameDesktopState.get_desktop_shortcuts_snapshot()` devuelve `Dictionary`.
- `GameUpgradeState.get_upgrade_purchase_counts_snapshot()` devuelve
  `Dictionary`.
- `GameClockState.get_clock_snapshot()` devuelve minutos y velocidad.
- `GameRunState.get_run_progress_snapshot()` devuelve modo, fase, día,
  presupuesto, timestamp y estado de agotamiento.
- `GameEnemySnapshotState.get_enemy_snapshots()` devuelve `Array` sin esquema.

- **Implementado:** todos los estados productivos tienen una sección semántica
  en el snapshot completo.
- **Implementado:** copias profundas evitan exponer directamente shortcuts,
  contadores de upgrades y snapshots de enemigos.
- **Implementado:** `DesktopSaveCoordinator.create_save_snapshot()` compone el
  snapshot completo sin Nodes, Resources, PackedScenes, Callables ni IDs de
  instancia.

## 10. Perfiles y formato persistente

Rutas:

```text
user://profiles/<profile_id>/profile.json
user://profiles/<profile_id>/savegame.json
```

`project.godot` no define `use_custom_user_dir` ni `custom_user_dir_name`, por lo
que Godot deriva la carpeta de datos del nombre de aplicación `Window Defender`.
Los archivos permanecen en la misma computadora aunque se mueva o reinstale la
carpeta del juego con esa configuración. No se transfieren automáticamente a
otra PC: actualmente es necesario copiar manualmente la carpeta de datos de
usuario. Exportación, importación y sincronización siguen fuera de alcance.

`profile_id` es un valor hexadecimal aleatorio de 128 bits y no deriva del
nombre visible. `profile.json` conserva:

- `schema_version = 1`;
- `profile_id`;
- `display_name`;
- `created_at`;
- `last_activity`;
- `has_save`.

`savegame.json` conserva:

```text
schema_version
saved_at
profile_id
game
  schema_version
  states
  desktop.shortcuts
  desktop.windows
  enemies
  processes
```

Ownership del snapshot:

| Sección | Propietario |
|---|---|
| `states.system` | `GameSystemState` |
| `states.weapon` | `GameWeaponState` |
| `states.reload_stats` | `GameReloadStatsState` |
| `states.miner` | `GameMinerState` |
| `states.economy` | `GameEconomyState` |
| `states.ram` | `GameRamState` (sólo máximo) |
| `states.desktop` | `GameDesktopState` (resolución/tier) |
| `states.upgrades` | `GameUpgradeState` |
| `states.clock` | `GameClockState` |
| `states.run` | `GameRunState` |
| `desktop.shortcuts` | `Desktop` |
| `desktop.windows` | `WindowManager` + `AppWindow` |
| `enemies` | `EnemyManager` + `DesktopVirus`/`BasicVirus` |
| `processes` | Shooting, Reload y Repair managers |

Los IDs persistentes registrados en
`Data/Persistence/GameContentRegistry.tres` son:

- `ProgramData.program_id` para apps, shortcuts y ventanas;
- `ShopUpgradeOfferData.offer_id` para contadores de mejoras;
- `EnemyArchetypeData.enemy_id` para enemigos.

No se persisten índices de Resources, nombres visibles como identidad ni
referencias a escenas.

Estado productivo conservado:

- integridad, arma, munición, economía, minería, upgrades y resolución;
- reloj ficticio, modo/fase/día, presupuesto y timestamp de spawn;
- shortcuts, posiciones de ventanas y z-order;
- cada instancia de Firewall guarda `orientation` (`horizontal` o `vertical`) e
  `is_established` dentro de `app_state`; el mapa y los RIDs de navegación se
  derivan y no se persisten;
- minería por ventana, cooldown, máquina de recarga y tick de reparación;
- arquetipo, posición, vida, stats runtime y cooldown de ataque de cada enemigo.

Estado normalizado:

- menú Inicio/pausa, foco temporal y drag activo;
- animaciones/tweens, flashes, hover y frame de animación;
- Area Shot pendiente se cancela y vuelve a evaluarse normalmente;
- ventanas se restauran funcionalmente sin costo de compra y luego se revelan
  mediante una animación local que no emite señales funcionales de apertura;
- un Miner capturado antes de iniciar su proceso restaura inactivo.
- llegada de un enemigo al sistema se deriva nuevamente de posición y distancias
  runtime; no se guarda un flag duplicado.

- **Implementado:** esquema de perfil, save y game en versión 1.
- **Implementado:** escritura atómica con temporal, backup, rollback y
  recuperación del backup tras una interrupción.
- **Implementado:** MainMenu elimina perfiles inactivos por `profile_id`.
  `ProfileStore` acepta únicamente 32 caracteres hexadecimales, comprueba que la
  carpeta sea hija directa de `user://profiles/`, la renombra antes de borrar y
  elimina todo su contenido, incluidos `.tmp` y `.bak`.
- **Parcialmente implementado:** no hay migraciones de schema; versiones
  desconocidas se rechazan.
- **Planeado:** múltiples slots, autosave, renombrado, recuperación de perfiles
  borrados, cifrado, exportación/importación y nube.

## 11. Validaciones existentes

- Mínimos y clamps en estados de sistema, arma, RAM, minería y reload.
- Consultas read-only y comandos explícitos para los dominios migrados.
- Emisión de eventos desde el estado propietario después de una mutación válida.
- Rechazo de Resources nulos o escenas que no heredan la clase esperada.
- Requisitos de programa y upgrade antes de comprar.
- Límites de índice para costos y efectos.
- Chequeo de existencia de todas las rutas explícitas `res://` durante la
  auditoría.
- Unicidad de IDs persistentes mediante `GameContentRegistry`.
- Validación de estructura, tipos, IDs, RAM, instancias únicas y valores básicos
  antes de restaurar.
- Validación de nombres de perfil vacíos, largos, duplicados sin distinguir
  mayúsculas y caracteres de control.
- Validación estricta y confinamiento de rutas antes de eliminar una carpeta de
  perfil; un perfil activo no puede borrarse.

## 12. Validaciones faltantes

- Coherencia entre cantidad de niveles, costos y valores de efecto.
- Rechazo transaccional de upgrades sin efecto válido.
- Validación editorial automatizada de secuencias, días y entradas.
- Migraciones de versiones antiguas de snapshots.
- Validación automatizada de dependencias de escenas y Resources.

## 13. Registro de preguntas de datos

- **Q-DATA-001:** ¿los recursos iniciales son de desarrollo o definitivos?
- **Q-DATA-002:** ¿qué convención de mayúsculas deben usar los programas?
- **Resuelto (Q-DATA-003):** el único arquetipo productivo actual usa
  `enemy_id = "basic_virus"`; variantes futuras tendrán Resources propios.
- **Resuelto (Q-DATA-004):** la selección usa exclusivamente `weight`; no se
  duplican entradas para ponderar.
- **Obsoleto (Q-DATA-005):** el valor atípico de amenaza desapareció junto con el
  modelo anterior.
- **Resuelto (Q-DATA-006):** perfil, save y snapshot jugable usan schema 1; una
  versión distinta se rechaza hasta implementar migraciones.
- **Q-DATA-007:** ¿deben conservarse los shortcut Resources no referenciados?
- **Q-DATA-008:** ¿Area Shot tendrá upgrades de cantidad de objetivos?
