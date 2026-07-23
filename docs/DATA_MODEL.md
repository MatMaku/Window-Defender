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
| `EnemySpawnEntryData` | `Data/Stages/EnemySpawnEntryData.gd` | Escena, costo y stats de enemigo | Implementado |
| `EnemySpawnStageData` | `Data/Stages/EnemySpawnStageData.gd` | Reglas de una etapa | Implementado |

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
| test | 20 | Sí | No integrado |

Fuentes: `Apps/*/*Program.tres`.

Shortcuts iniciales activos:

- `Apps/System/SystemShortcut.tres`
- `Apps/Miner/MinerShortcut.tres`
- `Apps/Shop/ShopShortcut.tres`

Los shortcuts de Shooting, Ammo, Reload, Repair y Test existen, pero no están
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
- **Riesgo:** no existe validación central de IDs, arrays o efectos `NONE`.

## 7. Datos de enemigos

Resources en `Stages/Prueba/Enemigos/`:

- `Basic Probe.tres`
- `Basic T1.tres`
- `Basic T2.tres`
- `Basic T3.tres`
- `Basic T4.tres`
- `Basic T5.tres`
- `Basic Swarm.tres`

Cada entrada puede definir:

- ID, nombre y escena;
- costo de amenaza y peso;
- tiempo mínimo;
- salud, velocidad y ataque;
- distancias de llegada/overlap;
- recompensa de datos.

- **Implementado:** valores omitidos heredan defaults del script Resource.
- **Riesgo confirmado:** Probe y T1 comparten `enemy_id = "basic_virus T1"`.
- **Riesgo confirmado:** T5 no sobrescribe `enemy_id` y conserva
  `basic_virus`.
- **Riesgo confirmado:** otros IDs incluyen espacios.
- **Desconocido (Q-DATA-003):** definir identidad canónica de cada variante.

## 8. Datos de stages

| Stage | Duración | Amenaza/s | Máximo vivos | Máximo presupuesto |
|---|---:|---:|---:|---:|
| 0 | 90 s | 0,35 | 4 | 8 |
| 1 | 120 s | 0,55 | 6 | 10 |
| 2 | 150 s | 80,0 | 8 | 14 |
| 3 | 180 s | 1,15 | 12 | 20 |
| 4 | 210 s | 1,55 | 16 | 28 |
| 5 | 240 s | 2,1 | 24 | 38 |
| 6 | 240 s | 3,0 | 34 | 52 |
| 7 | 300 s | 4,4 | 55 | 70 |
| 8 | Infinito | 6,5 | 100 | 100 |

Fuentes: `Stages/Prueba/Stages/*.tres`.

- **Implementado:** duración menor o igual a cero significa stage infinito.
- **Implementado:** el pool es un Array de `EnemySpawnEntryData`.
- **Riesgo confirmado:** los pools repiten Resources aunque cada entrada ya tiene
  un campo `weight`.
- **Desconocido (Q-DATA-004):** confirmar si la repetición es la forma deseada de
  ponderación.
- **Desconocido (Q-DATA-005):** confirmar el valor 80,0 de Stage 2.

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
| Progreso de run | `GameRunState` | `set_run_progress()` |
| Snapshots de enemigos | `GameEnemySnapshotState` | comandos de snapshots |

- **Implementado:** los primeros ocho estados usan backing fields privados para
  los datos sensibles y devuelven copias de sus contenedores.
- **Implementado:** no hay escritores directos confirmados sobre esos backing
  fields; managers y ventanas usan comandos del propietario.
- **Parcialmente implementado:** run y snapshots conservan su modelo previo; se
  les trasladaron sus señales para retirar los relays de `GameState`, sin
  rediseñar persistencia.

Snapshots disponibles en memoria:

- `GameDesktopState.get_desktop_shortcuts_snapshot()` devuelve `Dictionary`.
- `GameUpgradeState.get_upgrade_purchase_counts_snapshot()` devuelve
  `Dictionary`.
- `GameRunState.get_run_progress_snapshot()` devuelve tiempo, stage, tiempo de
  stage y presupuesto.
- `GameEnemySnapshotState.get_enemy_snapshots()` devuelve `Array` sin esquema.

- **Implementado:** copias profundas evitan exponer directamente shortcuts,
  contadores de upgrades y snapshots de enemigos.
- **Parcialmente implementado:** no existe snapshot completo de partida.
- **Planeado:** estado de enemigos y run preparan una futura restauración.
- **Desconocido (Q-DATA-006):** definir esquema y versionado de archivos de
  guardado.

## 10. Validaciones existentes

- Mínimos y clamps en estados de sistema, arma, RAM, minería y reload.
- Consultas read-only y comandos explícitos para los dominios migrados.
- Emisión de eventos desde el estado propietario después de una mutación válida.
- Rechazo de Resources nulos o escenas que no heredan la clase esperada.
- Requisitos de programa y upgrade antes de comprar.
- Límites de índice para costos y efectos.
- Chequeo de existencia de todas las rutas explícitas `res://` durante la
  auditoría.

## 11. Validaciones faltantes

- Unicidad de `program_id`, `offer_id` y `enemy_id`.
- Coherencia entre cantidad de niveles, costos y valores de efecto.
- Rechazo transaccional de upgrades sin efecto válido.
- Validación de pools duplicados.
- Versionado/migración de snapshots.
- Validación automatizada de dependencias de escenas y Resources.

## 12. Registro de preguntas de datos

- **Q-DATA-001:** ¿los recursos iniciales son de desarrollo o definitivos?
- **Q-DATA-002:** ¿qué convención de mayúsculas deben usar los programas?
- **Q-DATA-003:** ¿cuáles son los IDs correctos de las variantes de virus?
- **Q-DATA-004:** ¿pool duplicado, `weight` o ambos deben ponderar spawns?
- **Q-DATA-005:** ¿Stage 2 debe generar 80 de amenaza por segundo?
- **Q-DATA-006:** ¿cuál será el esquema/versionado de guardado?
- **Q-DATA-007:** ¿deben conservarse los shortcut Resources no referenciados?
- **Q-DATA-008:** ¿Area Shot tendrá upgrades de cantidad de objetivos?
