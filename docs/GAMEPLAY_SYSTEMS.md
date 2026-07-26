# Gameplay Systems

## 1. Alcance

Este documento registra las reglas observables de gameplay. Los valores exactos
configurados en Resources están catalogados en `docs/DATA_MODEL.md`.

## 2. Desktop y accesos directos

Fuentes:

- `Scripts/Desktop/Desktop.gd`
- `Scripts/Desktop/DesktopExecutable.gd`
- `Scenes/Desktop/Desktop.tscn`
- `Scenes/Desktop/DesktopExecutable.tscn`

- **Implementado:** doble clic solicita abrir el `ProgramData` asociado.
- **Implementado:** los shortcuts pueden arrastrarse y quedan limitados al
  `IconLayer`.
- **Implementado:** posiciones se registran mediante comandos de
  `GameDesktopState`; `Desktop` conserva esa referencia tipada.
- **Implementado:** programas comprados se agregan en la primera posición libre.
- **Parcialmente implementado:** al cambiar resolución no existe
  `clamp_all_shortcuts_inside_icon_layer()`, aunque `DisplayManager` intenta
  invocarlo si está disponible.

## 3. Ventanas y taskbar

Fuentes:

- `Scripts/Windows/AppWindow.gd`
- `Scripts/Windows/WindowManager.gd`
- `Scripts/Taskbar/Taskbar.gd`
- `Scripts/Taskbar/TaskbarManager.gd`
- `Scripts/Taskbar/TaskbarAppButton.gd`
- `Scenes/Taskbar/Taskbar.tscn`

- **Implementado:** ventanas arrastrables, cierre, foco y z-order.
- **Implementado:** instancia única salvo que `ProgramData` permita múltiples.
- **Implementado:** botones de taskbar por ventana, foco y reordenamiento.
- **Implementado:** menú Inicio animado.
- **Implementado:** el menú Inicio pausa el `SceneTree`, muestra un overlay y
  permanece interactivo para reanudar o ejecutar Shut Down.
- **Implementado:** Shut Down cierra directamente la aplicación.
- **Implementado:** `TimeLabel` y `DateLabel` presentan el reloj ficticio de la
  partida desde `GameClockState`; no consultan la fecha ni la hora del sistema
  operativo.
- **Implementado:** la Taskbar actualiza el reloj únicamente cuando cambia el
  minuto o el día y conserva el último valor visible durante la pausa.
- **Parcialmente implementado:** los botones de taskbar no minimizan.
- **Planeado:** Load, Save y Options existen visualmente, sin handlers.

## 4. RAM

Fuentes:

- `Scripts/RAM/RamManager.gd`
- `Scripts/Autoload/GameRamState.gd`
- `Scripts/Windows/WindowManager.gd`
- `Apps/*/*Program.tres`

- **Implementado:** cada ventana reserva su `ram_cost` al abrir.
- **Implementado:** una apertura sin RAM disponible muestra error.
- **Implementado:** menor RAM disponible aumenta la duración de apertura.
- **Implementado:** cerrar una ventana devuelve la RAM asignada.
- **Planeado:** `get_runtime_speed_multiplier()` calcula una penalización de
  velocidad, pero no tiene consumidores.
- **Desconocido (Q-GAME-001):** definir qué procesos deben ralentizarse por
  presión de RAM.

## 5. Economía y minería

Fuentes:

- `Scripts/Autoload/GameEconomyState.gd`
- `Scripts/Autoload/GameMinerState.gd`
- `Scripts/Miner/MinerWindow.gd`
- `Apps/Miner/MinerProgram.tres`

- **Implementado:** cada instancia abierta de Miner genera criptomonedas de forma
  independiente.
- **Implementado:** Miner empieza después de terminar su animación de apertura.
- **Implementado:** upgrades pueden cambiar cantidad e intervalo.
- **Implementado:** matar un virus entrega datos y aumenta muertes totales.
- **Desconocido (Q-GAME-002):** confirmar si la multiplicación lineal por
  múltiples Miners es comportamiento final.

## 6. Tienda y upgrades

Fuentes:

- `Scripts/Shop/ShopManager.gd`
- `Scripts/Shop/ShopWindow.gd`
- `Scripts/Shop/ShopOfferRow.gd`
- `Scripts/Shop/UpgradeManager.gd`
- `Shop/Apps/`
- `Shop/Upgrades/`

- **Implementado:** tabs de aplicaciones y upgrades.
- **Implementado:** ofertas ordenadas por costo actual.
- **Implementado:** aplicaciones ya instaladas se ocultan.
- **Implementado:** compras validan recursos y requisitos.
- **Implementado:** una compra de aplicación fallida reembolsa criptomonedas.
- **Implementado:** upgrades maxeados o con requisitos incumplidos se ocultan.
- **Parcialmente implementado:** no se presenta un estado vacío aunque existe un
  helper no utilizado para crearlo.
- **Riesgo:** una mejora con efecto `NONE` puede cobrar recursos y contar la
  compra; solo genera un warning.

## 7. Integridad y System.exe

Fuentes:

- `Scripts/Autoload/GameSystemState.gd`
- `Scripts/System/SystemManager.gd`
- `Scripts/System/SystemWindow.gd`
- `Apps/System/SystemWindow.tscn`

- **Implementado:** el shortcut de System es el objetivo de ataque.
- **Implementado:** daño y curación se aplican mediante comandos de
  `GameSystemState`; `SystemManager` conserva la referencia tipada y retransmite
  sólo sus eventos de coordinación actuales.
- **Implementado:** SystemWindow muestra porcentaje y barra de integridad.
- **Implementado:** después de destrucción no se acepta más daño ni curación.
- **Parcialmente implementado:** system failure no concluye la partida.

## 8. Enemigos

Fuentes:

- `Scripts/Virus/DesktopVirus.gd`
- `Scripts/Virus/BasicVirus.gd`
- `Scripts/Virus/EnemyManager.gd`
- `Scenes/Virus/BasicVirus.tscn`
- `Data/Enemies/EnemyArchetypeData.gd`
- `Data/Enemies/EnemyRuntimeStats.gd`
- `Stages/Daily/Archetypes/BasicVirus.tres`

- **Implementado:** spawn desde un borde aleatorio.
- **Implementado:** salud, daño, muerte y recompensa.
- **Implementado:** BasicVirus avanza hacia el rectángulo de System y ataca por
  intervalos.
- **Implementado:** los virus pueden arrastrarse con el mouse.
- **Implementado:** el arrastre se corta cuando el cursor entra sobre una ventana.
- **Implementado:** separación entre pares evita acumulación excesiva.
- **Implementado:** un disparo daña todos los enemigos que contienen el punto.
- **Implementado:** cada arquetipo referencia su propia `PackedScene` y sus
  estadísticas base.
- **Implementado:** cada instancia recibe un `EnemyRuntimeStats` nuevo calculado
  desde arquetipo × modificadores diarios × modificadores de entrada; los
  Resources compartidos no se modifican durante el spawn.
- **Desconocido (Q-GAME-003):** confirmar si arrastrar virus es una mecánica
  definitiva.
- **Desconocido (Q-GAME-004):** confirmar si dañar todos los enemigos superpuestos
  es intencional.

## 9. Reloj de partida, ciclos diarios y spawn

Fuentes:

- `Scripts/Autoload/GameClockState.gd`
- `Scripts/GameClock/GameClockManager.gd`
- `Scripts/Autoload/GameRunState.gd`
- `Scripts/Virus/EnemySpawnDirector.gd`
- `Data/Waves/WaveSequenceData.gd`
- `Data/Waves/DailyWaveData.gd`
- `Data/Waves/WaveEnemyEntry.gd`
- `Stages/Daily/DailyWaveSequence.tres`

- **Implementado:** el reloj comienza en `01/01/1998 00:00`, usa minutos
  numéricos desde ese origen y maneja calendario gregoriano, incluidos años
  bisiestos.
- **Implementado:** `GameClockManager` es el único componente que avanza el
  reloj con `delta`; se detiene con la pausa normal del `SceneTree` y cuando
  System es destruido.
- **Implementado:** `DAILY_CYCLE` alterna descanso y periodo activo según un
  horario configurable. El inicio es inclusivo, el final exclusivo y los
  horarios que cruzan medianoche son válidos.
- **Implementado:** `INFINITE` conserva la fase activa durante todo el día, sin
  omitir presupuesto, intervalo ni límites de enemigos.
- **Implementado:** cada día reinicia su presupuesto y selecciona una
  `DailyWaveData`; al superar la secuencia se conserva la última configuración.
- **Implementado:** el intervalo se expresa en minutos ficticios y se controla
  mediante timestamps del mismo reloj, sin un timer paralelo.
- **Implementado:** la selección ponderada considera coste, límite global y
  `max_alive` por entrada.
- **Implementado:** al alcanzar un límite no se consume presupuesto ni se
  acumulan intentos; al liberarse espacio puede ocurrir como máximo un spawn en
  el siguiente intervalo válido.
- **Implementado:** durante el descanso sólo se detienen nuevos spawns; enemigos
  vivos, minería, reparaciones y el reloj siguen activos.
- **Parcialmente implementado:** `GameClockState` y `GameRunState` exponen
  snapshots primitivos y restauración controlada, pero no existe guardado en
  disco ni un flujo de carga.
- **Planeado:** selección y desbloqueo de `INFINITE` desde UI.
- **Configuración provisional:** el Resource de prueba usa `02:00–00:00`, un
  único día repetible y sólo el enemigo básico. Sus tiempos y presupuesto no son
  balance definitivo.

## 10. Disparo y munición

Fuentes:

- `Scripts/Shooting/ShootingManager.gd`
- `Scripts/Shooting/ShootingWindow.gd`
- `Scripts/Shooting/AmmoWindow.gd`
- `Scripts/Windows/WindowManager.gd`

- **Implementado:** el botón Shoot dispara en el centro de la mira.
- **Implementado:** cada disparo consume una munición e inicia cooldown.
- **Implementado:** `ShootingManager` consulta y muta `GameWeaponState`, y
  consulta automatizaciones en `GameUpgradeState` sin usar proxies globales.
- **Implementado:** el jugador posiciona la ventana/mira sobre el enemigo.
- **Implementado:** otras ventanas con `blocks_shots` pueden bloquear el punto.
- **Implementado:** AmmoWindow refleja cambios y anima su etiqueta.
- **Implementado:** Auto Shoot intenta disparar continuamente al centro cuando
  existe un enemigo bajo la mira.
- **Implementado:** Area Shoot selecciona enemigos cuyo centro está dentro del
  área y consume una sola munición por volley.
- **Parcialmente implementado:** rechazo por munición, cooldown o recarga emite
  señal, pero no tiene presentación conectada.
- **Desconocido (Q-GAME-006):** confirmar si deben bloquear solo ventanas por
  encima de Shooting; el helper `get_windows_above()` no se usa.

## 11. Recarga

Fuentes:

- `Scripts/Shooting/ReloadManager.gd`
- `Scripts/Shooting/ReloadWindow.gd`
- `Apps/Reload/ReloadWindow.tscn`

- **Implementado:** estados Idle, Reloading, Penalty y Perfect Finish.
- **Implementado:** pulsar Reload inicia si falta munición y el arma está libre.
- **Implementado:** volver a pulsar dentro de la zona completa una recarga
  perfecta tras un delay corto.
- **Implementado:** pulsar fuera de la zona aplica penalización y luego continúa.
- **Implementado:** desbloquear Auto Reload inicia recarga al llegar a cero.
- **Implementado:** `ReloadManager` observa directamente `GameWeaponState`,
  `GameReloadStatsState` y `GameUpgradeState`.
- **Parcialmente implementado:** la recarga automática requiere una ReloadWindow
  válida y abierta.
- **Desconocido (Q-GAME-007):** confirmar si Auto Reload debe depender de que la
  aplicación permanezca abierta.

## 12. Reparación

Fuentes:

- `Scripts/Repair/RepairManager.gd`
- `Scripts/Repair/RepairWindow.gd`
- `Apps/Repair/RepairWindow.tscn`

- **Implementado:** Repair necesita intersección mínima con el shortcut System.
- **Implementado:** repara 1 % de integridad máxima cada 5 segundos.
- **Implementado:** si todos los puntos de contacto están cubiertos por otras
  ventanas, la reparación queda bloqueada.
- **Implementado:** presenta Idle, Repairing, Blocked, Full y No Target.
- **Desconocido (Q-GAME-008):** confirmar si cualquier ventana debe bloquear el
  contacto independientemente de su orden visual.

## 13. Resolución

Fuentes:

- `Scripts/Desktop/DisplayManager.gd`
- `Scripts/Autoload/GameDesktopState.gd`
- `Shop/Upgrades/Resolution.tres`
- `project.godot`

- **Implementado:** cuatro tiers: 1280×720, 1600×900, 1920×1080 y 2560×1440.
- **Implementado:** la mejora avanza un tier y DisplayManager aplica content scale.
- **Parcialmente implementado:** ventanas y shortcuts no se reclampan porque los
  métodos de notificación esperados no existen.

## 14. Fin de partida y funciones futuras

- **Parcialmente implementado:** destrucción del sistema.
- **Planeado:** guardado/carga.
- **Planeado:** Options.
- **Planeado:** efecto runtime de RAM.
- **Parcialmente implementado:** presentación de fase diaria, presupuesto y
  errores de disparo.

## 15. Registro de preguntas de gameplay

- **Q-GAME-001:** ¿qué procesos debe ralentizar la RAM?
- **Q-GAME-002:** ¿múltiples Miners deben apilar producción linealmente?
- **Q-GAME-003:** ¿arrastrar enemigos es parte del diseño final?
- **Q-GAME-004:** ¿un disparo debe dañar todos los enemigos superpuestos?
- **Resuelto (Q-GAME-005):** la configuración antigua de amenaza fue reemplazada
  por oleadas diarias editables.
- **Q-GAME-006:** ¿qué ventanas deben bloquear disparos según z-order?
- **Q-GAME-007:** ¿Auto Reload requiere Reload.exe abierto?
- **Q-GAME-008:** ¿qué ventanas deben bloquear contacto de Repair?
- **Q-GAME-009:** ¿cuáles son los valores de balance objetivo?
