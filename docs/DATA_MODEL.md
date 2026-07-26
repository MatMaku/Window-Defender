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
- **Parcialmente implementado:** snapshots de enemigos conservan su modelo sin
  esquema.

Snapshots disponibles en memoria:

- `GameDesktopState.get_desktop_shortcuts_snapshot()` devuelve `Dictionary`.
- `GameUpgradeState.get_upgrade_purchase_counts_snapshot()` devuelve
  `Dictionary`.
- `GameClockState.get_clock_snapshot()` devuelve minutos y velocidad.
- `GameRunState.get_run_progress_snapshot()` devuelve modo, fase, día,
  presupuesto, timestamp y estado de agotamiento.
- `GameEnemySnapshotState.get_enemy_snapshots()` devuelve `Array` sin esquema.

- **Implementado:** los snapshots de reloj y run contienen únicamente números y
  booleanos; no guardan nodos ni Resources.
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
- Validación editorial automatizada de secuencias, días y entradas.
- Versionado/migración de snapshots.
- Validación automatizada de dependencias de escenas y Resources.

## 12. Registro de preguntas de datos

- **Q-DATA-001:** ¿los recursos iniciales son de desarrollo o definitivos?
- **Q-DATA-002:** ¿qué convención de mayúsculas deben usar los programas?
- **Resuelto (Q-DATA-003):** el único arquetipo productivo actual usa
  `enemy_id = "basic_virus"`; variantes futuras tendrán Resources propios.
- **Resuelto (Q-DATA-004):** la selección usa exclusivamente `weight`; no se
  duplican entradas para ponderar.
- **Obsoleto (Q-DATA-005):** el valor atípico de amenaza desapareció junto con el
  modelo anterior.
- **Q-DATA-006:** ¿cuál será el esquema/versionado de guardado?
- **Q-DATA-007:** ¿deben conservarse los shortcut Resources no referenciados?
- **Q-DATA-008:** ¿Area Shot tendrá upgrades de cantidad de objetivos?
