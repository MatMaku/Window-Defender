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
- **Implementado:** el drag de un shortcut se corta cuando el cursor entra sobre
  una `AppWindow` visible. El shortcut conserva la última posición que alcanzó,
  sin proyectarse artificialmente hacia otro borde.
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
- **Implementado:** Shut Down cierra el menú Inicio, normaliza la pausa y vuelve
  a MainMenu sin guardar automáticamente.
- **Implementado:** `TimeLabel` y `DateLabel` presentan el reloj ficticio de la
  partida desde `GameClockState`; no consultan la fecha ni la hora del sistema
  operativo.
- **Implementado:** la Taskbar actualiza el reloj únicamente cuando cambia el
  minuto o el día y conserva el último valor visible durante la pausa.
- **Parcialmente implementado:** los botones de taskbar no minimizan.
- **Implementado:** Save solicita una captura coherente para el perfil activo.
- **Implementado:** Taskbar no ofrece Load; la carga se realiza exclusivamente
  desde MainMenu. Options permanece sin handler.

## 4. RAM

Fuentes:

- `Scripts/RAM/RamManager.gd`
- `Scripts/Autoload/GameRamState.gd`
- `Scripts/Windows/WindowManager.gd`
- `Apps/*/*Program.tres`

- **Implementado:** cada ventana reserva su `ram_cost` al abrir.
- **Implementado:** una apertura solicitada por el jugador sin RAM disponible
  muestra error; el intento periódico de Adware es la excepción silenciosa.
- **Implementado:** menor RAM disponible aumenta la duración de apertura.
- **Implementado:** cerrar una ventana devuelve la RAM asignada.
- **Implementado:** cada instancia de Firewall reserva 32 RAM durante toda su
  vida; establecerla o rotarla no cambia ese costo.
- **Implementado:** cada instancia de Turret reserva 24 RAM durante toda su vida;
  cerrar una torreta no afecta el shortcut ni las demás instancias.
- **Implementado:** Overclock es de instancia única y reserva 16 RAM únicamente
  mientras su ventana está abierta; cerrar la ventana no cancela efecto ni cooldown.
- **Implementado:** cada instancia de Slowdown reserva 32 RAM; cerrar una antena
  libera sólo su reserva y no elimina el shortcut ni las demás instancias.
- **Implementado:** cada SpamWindow reserva 16 RAM. Si Adware intenta crearla sin
  RAM disponible, el intento se descarta silenciosamente hasta el próximo
  intervalo y no se acumulan aperturas atrasadas.
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
- **Configuración de slice:** cada Miner comienza en 3 crypto cada 5 segundos,
  equivalente a 36 crypto por minuto activo. Dos instancias base producen 72;
  sus mejoras elevan cantidad y reducen intervalo sin crear otro timer global.
- **Implementado:** Miner empieza después de terminar su animación de apertura.
- **Implementado:** upgrades pueden cambiar cantidad e intervalo.
- **Implementado:** matar un virus entrega datos y aumenta muertes totales.
- **Implementado:** `GameEconomyState` aplica el multiplicador activo de
  Overclock al acreditar crypto, virus data o recompensas de enemigos. Usa
  `floor(base × multiplier)` y nunca entrega menos que la cantidad base.
- **Implementado:** gastos, refunds administrativos, valores iniciales y restore
  no reciben el multiplicador.
- **Implementado:** cada Miner abierto conserva si estaba activo y el tiempo
  transcurrido hasta su siguiente tick.
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
- **Implementado:** upgrades con requisitos incumplidos se ocultan. Las tres
  mejoras defensivas repetibles conservan su fila al llegar al máximo y muestran
  nivel actual/máximo, precio siguiente y estado `MAX`; las ofertas anteriores
  mantienen su comportamiento de ocultarse al completarse.
- **Configuración de slice:** las líneas principales tienen entre seis y ocho
  niveles con curvas progresivas. Los precios completos y el pacing esperado
  están en `docs/VERTICAL_SLICE_BALANCE.md`.
- **Parcialmente implementado:** no se presenta un estado vacío aunque existe un
  helper no utilizado para crearlo.
- **Riesgo:** una mejora con efecto `NONE` puede cobrar recursos y contar la
  compra; solo genera un warning.

### 6.1 overclock.exe

Fuentes:

- `Data/Overclock/OverclockConfig.tres`
- `Scripts/Autoload/GameOverclockState.gd`
- `Scripts/Overclock/OverclockManager.gd`
- `Scripts/Overclock/OverclockWindow.gd`
- `Apps/Overclock/OverclockWindow.tscn`

- **Implementado:** se compra por 320 crypto provisional, crea un shortcut
  persistente y usa una ventana singleton de 16 RAM con superficie CMD.
- **Implementado:** comienza con cooldown y alterna
  `COOLDOWN → READY → TYPING → ACTIVE → COOLDOWN`; un intento incorrecto vuelve
  directamente a cooldown sin bonus.
- **Implementado:** Enter compara exactamente la línea completa, con mayúsculas,
  espacios y símbolos. Shift+Enter no envía. El input completo es verde mientras
  coincide con el prefijo y rojo desde la primera discrepancia.
- **Implementado:** las instrucciones se seleccionan desde un Resource y no se
  repite inmediatamente la anterior cuando existen alternativas.
- **Implementado:** cerrar la ventana descarta el texto parcial sin considerarlo
  fallo, conserva la instrucción y no detiene efecto ni cooldown.
- **Implementado:** el manager avanza en segundos de gameplay y se detiene con
  `SceneTree.paused`; el SystemTray mantiene un borde/tint verde mientras el
  efecto está activo.
- **Configuración provisional:** cooldown inicial 30 s, efecto 120 s, cooldown
  normal 180 s y multiplicador 2,0×. No constituye balance definitivo.
- **Implementado:** fase, tiempos, multiplicador e instrucción se guardan. El
  historial, texto parcial, foco y colores se normalizan al cargar.

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
- `Scripts/Virus/AdwareVirus.gd`
- `Scripts/Virus/EnemyManager.gd`
- `Scenes/Virus/BasicVirus.tscn`
- `Scenes/Virus/AdwareVirus.tscn`
- `Data/Enemies/EnemyArchetypeData.gd`
- `Data/Enemies/EnemyRuntimeStats.gd`
- `Stages/Daily/Archetypes/BasicVirus.tres`
- `Stages/Daily/Archetypes/AdwareVirus.tres`
- `Stages/Daily/Archetypes/RunnerVirus.tres`
- `Stages/Daily/Archetypes/BruteVirus.tres`

- **Implementado:** spawn desde un borde aleatorio.
- **Implementado:** salud, daño, muerte y recompensa.
- **Implementado:** BasicVirus avanza hacia el rectángulo de System y ataca por
  intervalos.
- **Implementado:** RunnerVirus y BruteVirus reutilizan esa misma escena y
  comportamiento. Runner es pequeño, rápido, tiene 0,75 de vida y muere con el
  disparo base; Brute es grande, lento y conserva 12 de vida base para requerir
  varios impactos durante toda la slice.
- **Implementado:** AdwareVirus nunca ataca System. Elige la ventana elegible más
  cercana, conserva ese objetivo, sigue un punto interior seguro y sólo se marca
  oculto con al menos 90% de cobertura.
- **Implementado:** oculto permanece inmóvil y genera Spam cada 12 ± 2 segundos
  provisionales. Mover/cerrar la cobertura o arrastrar el Adware cancela el estado
  oculto; expuesto no genera Spam.
- **Implementado:** Firewall, Turret, Slowdown, Overclock y Spam no son escondites.
  Las ventanas normales no se agregan al mapa de navegación; los Firewalls
  establecidos siguen siendo obstáculos durante la aproximación.
- **Implementado:** los virus pueden arrastrarse con el mouse.
- **Implementado:** el arrastre se corta cuando el cursor entra sobre una ventana.
- **Implementado:** separación entre pares evita acumulación excesiva.
- **Implementado:** un disparo daña todos los enemigos que contienen el punto.
- **Implementado:** cada arquetipo referencia una `PackedScene`, sus estadísticas
  base y presentación opcional. Varios arquetipos pueden compartir escena sin
  mutar esa escena ni el Resource.
- **Implementado:** cada instancia recibe un `EnemyRuntimeStats` nuevo calculado
  desde arquetipo × modificadores diarios × modificadores de entrada; los
  Resources compartidos no se modifican durante el spawn.
- **Implementado:** cada enemigo vivo guarda arquetipo, posición, salud, stats
  finales y estado de comportamiento. Basic conserva cooldown de ataque; Adware
  conserva fase y tiempo hasta Spam. La restauración no entrega recompensa ni
  emite un nuevo evento de spawn.
- **Desconocido (Q-GAME-003):** confirmar si arrastrar virus es una mecánica
  definitiva.
- **Desconocido (Q-GAME-004):** confirmar si dañar todos los enemigos superpuestos
  es intencional.

### 8.1 Firewall y movimiento con rutas

Fuentes:

- `Scripts/Firewall/FirewallWindow.gd`
- `Scripts/Firewall/FirewallNavigationManager.gd`
- `Scripts/Virus/DesktopVirus.gd`
- `Scripts/Virus/BasicVirus.gd`

- **Implementado:** un Firewall móvil es una ventana normal para enemigos; su
  imagen es semitransparente y puede alternar dimensiones horizontal/vertical.
- **Implementado:** Establecer usa el rectángulo global completo como pared,
  oculta los botones, vuelve opaca la imagen y sitúa la ventana debajo de las
  ventanas normales, pero encima del Desktop.
- **Implementado:** se rechaza establecer si existe intersección parcial con un
  virus, shortcut u otro Firewall establecido. Tocar bordes entre paredes sí es
  válido.
- **Implementado:** se rechaza una pared que elimine la ruta desde cualquier
  muestra relevante del perímetro de spawn hasta `System.exe`.
- **Implementado:** los virus usan paths de `NavigationServer2D` y sólo
  recalculan cuando cambia la revisión del mapa o se mueve su destino; las
  ventanas normales no desvían enemigos.
- **Implementado:** un cambio de Firewall mantiene las consultas de navegación
  pendientes hasta la sincronización del siguiente frame de física. La revisión
  se publica recién entonces, evitando que spawn o restore cacheen el mapa
  anterior.
- **Implementado:** al cambiar los obstáculos, todos los virus descartan
  inmediatamente su path y permanecen detenidos hasta poder consultar la nueva
  revisión. La carga tampoco reanuda gameplay hasta que esa revisión existe.
- **Implementado:** el manager conserva los rectángulos exactos asociados al
  mapa sincronizado y rechaza paths o tramos de movimiento que crucen esas
  paredes; una ruta inválida detiene al virus en lugar de habilitar movimiento
  directo.
- **Implementado:** el bake conserva un margen configurable adicional alrededor
  de las paredes y el seguimiento admite una tolerancia de waypoint configurable
  para reducir roces y oscilaciones en esquinas.
- **Implementado:** al finalizar el drag de un virus, si su centro quedó fuera
  del área navegable por rozar una pared, se recupera una sola vez al punto
  navegable más cercano. La separación entre virus también se proyecta sobre el
  mapa y conserva el path mientras su siguiente tramo siga siendo válido, para
  evitar empujes contra paredes y recálculos continuos en las esquinas.
- **Implementado:** un clic o movimiento menor al umbral conserva la pared. Al
  superar el umbral desde la barra de título se desregistra antes de mover el
  primer píxel y el drag continúa sin salto.
- **Implementado:** móvil o establecido, Firewall conserva `blocks_shots` y
  provoca la liberación del drag de un virus igual que cualquier `AppWindow`.
  Los virus no lo atacan ni puede recibir daño.
- **Implementado:** `Firewall Expansion` interpola en seis niveles con ratios
  `[0,15; 0,30; 0,46; 0,62; 0,80; 1,00]` desde 340×150 hasta 460×190 en
  horizontal y desde 180×310 hasta 220×430 en vertical.
  Una compra conserva orientación y centro, hace clamp y actualiza todas las
  instancias abiertas sin cambiar sus 32 RAM.
- **Implementado:** una pared establecida se retira temporalmente del registro al
  crecer y se vuelve a validar contra virus, shortcuts, otras paredes y caminos.
  Si falla queda móvil; si es válida se reincorpora y los rebuilds diferidos se
  agrupan por frame.

### 8.2 turret.exe

Fuentes:

- `Apps/Turret/TurretProgram.tres`
- `Apps/Turret/TurretWindow.tscn`
- `Scripts/Turret/TurretWindow.gd`
- `Scripts/Turret/TurretShotTracer.gd`
- `Scripts/Windows/WindowManager.gd`
- `Scripts/Virus/EnemyManager.gd`

- **Implementado:** la torreta es la propia ventana; comprarla crea un shortcut
  estable y cada apertura crea una defensa independiente. Cerrar una instancia
  elimina esa defensa y libera únicamente sus 24 RAM.
- **Implementado:** conserva el virus válido actual durante el cooldown y sólo
  busca el más cercano cuando pierde target. El target debe seguir registrado,
  vivo, dentro del rango base de 200 píxeles medido desde `AimOrigin` y visible desde
  `MuzzlePoint`.
- **Implementado:** `AimOrigin` coincide con el centro fijo de la textura. La
  torreta rota suavemente alrededor de ese punto incluso durante el cooldown,
  mientras `MuzzlePoint` gira con el cañón y conserva el origen visual del
  proyectil. La orientación base se deriva del vector entre ambos marcadores y
  admite un offset angular adicional editable desde la escena.
- **Implementado:** al terminar el cooldown, el disparo espera hasta que la
  dirección real del cañón esté alineada con el enemigo dentro de la tolerancia
  angular configurable; el tiempo empleado en apuntar no reinicia el cooldown.
- **Implementado:** `WindowManager` comprueba el segmento completo entre boca e
  impacto. Cualquier `AppWindow` visible con `blocks_shots`, incluidas Firewall
  y otras Turret, bloquea; la propia ventana emisora se ignora.
- **Implementado:** el daño 2 se aplica inmediatamente mediante
  `DesktopVirus.receive_damage()`. No consume munición ni comparte cooldown,
  Auto Fire o Area Shot con Shooting.
- **Implementado:** cada disparo crea un tracer visual independiente en
  `WindowLayer`; su extremo inicial avanza hasta el impacto fijo y el nodo se
  autodestruye. Ventanas con mayor z-order lo cubren normalmente.
- **Implementado:** el recoil mueve sólo `RecoilContainer`, cancela el tween
  anterior y siempre vuelve a su posición base; no altera la ventana,
  `MuzzlePoint` ni la posición persistida.
- **Implementado:** durante drag y animación de apertura se suspenden targeting,
  rotación, disparo y avance del cooldown. Al soltar se busca un target nuevo.
- **Implementado:** cada instancia persiste sólo `cooldown_remaining`; target,
  ángulo, tracer, recoil y drag se normalizan al cargar.
- **Implementado:** `Turret Performance` tiene seis niveles y deriva daño/rango/
  fire rate. Sus multiplicadores finales son `2,0×`, `1,3×` y `1,55×`; el
  cooldown efectivo es el cooldown base dividido por fire rate y respeta un
  mínimo configurable de 0,35 s.
- **Implementado:** comprar un nivel actualiza todas las torretas abiertas y
  conserva la fracción restante de su cooldown; no altera target, rotación,
  línea de visión, tracer, recoil, RAM ni tamaño.
- **Configuración provisional:** precio 650, RAM 24, daño 2, rango 200 y cooldown
  1,25 segundos son valores editables y no constituyen balance definitivo.
- **Planeado:** mejoras adicionales de rotación, RAM y feedback visual. No
  existen todavía variantes ni prioridades configurables.

### 8.3 slowdown.exe

Fuentes:

- `Apps/Slowdown/SlowdownProgram.tres`
- `Apps/Slowdown/SlowdownWindow.tscn`
- `Data/Slowdown/SlowdownEffect.tres`
- `Scripts/Slowdown/SlowdownWindow.gd`
- `Scripts/Virus/EnemyManager.gd`
- `Scripts/Virus/DesktopVirus.gd`
- `Scripts/Virus/BasicVirus.gd`

- **Implementado:** comprar la app crea un shortcut estable y cada apertura crea
  una antena independiente si puede reservar sus 32 RAM. No existe límite de
  instancias adicional.
- **Implementado:** `EffectOrigin` define el centro global del área. La posición
  se consulta desde la ventana cada 0,05 s, de modo que el área acompaña el drag
  sin volver a registrar la fuente.
- **Implementado:** todo virus cuyo centro global queda dentro del radio recibe
  un multiplicador temporal de desplazamiento. Varias áreas superpuestas usan el
  menor multiplicador, no un producto acumulativo.
- **Implementado:** cerrar una instancia la desregistra y recalcula los efectos;
  al salir de la última área el multiplicador vuelve a 1,0.
- **Implementado:** el efecto atraviesa todas las ventanas, no consulta z-order
  ni línea de visión, no bloquea disparos y no registra obstáculos de navegación.
  Tampoco cambia vida, daño, ataque, cooldown, recompensa ni arrastre.
- **Implementado:** posición, z-order y RAM usan el snapshot genérico de ventanas.
  El registro, la lista de afectados y los multiplicadores derivados no se
  serializan; al cargar se reconstruyen desde las ventanas restauradas.
- **Configuración provisional:** precio 260, RAM 32, radio 180 píxeles y
  multiplicador 0,65 son editables y no constituyen balance definitivo. Radio y
  multiplicador base viven en un `SlowdownEffectData` compartido; cada instancia
  deriva el valor efectivo desde el nivel persistente.
- **Implementado:** `Slowdown Strength` conserva el radio y reduce el
  multiplicador efectivo en seis niveles a 0,61, 0,57, 0,52, 0,47, 0,41 y 0,35.
  Todas las ventanas y virus actualmente afectados se recalculan al comprar; las
  áreas superpuestas siguen eligiendo sólo el menor multiplicador.
- **Planeado:** upgrades de radio y RAM. No hay daño,
  congelamiento, pulsos, activación manual ni visualización permanente del área.

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
  `DailyWaveData`. La configuración de producción usa seis días de unos 100
  segundos activos y un Resource infinito separado.
- **Implementado:** el intervalo se expresa en minutos ficticios y se controla
  mediante timestamps del mismo reloj, sin un timer paralelo.
- **Implementado:** la selección ponderada considera coste, límite global y
  `max_alive` por entrada.
- **Implementado:** una evaluación puede crear un grupo configurado; aplica el
  límite global después de cada instancia y nunca acumula grupos pendientes.
- **Implementado:** al alcanzar un límite no se consume presupuesto ni se
  acumulan intentos; al liberarse espacio puede ocurrir como máximo un spawn en
  el siguiente intervalo válido.
- **Implementado:** durante el descanso sólo se detienen nuevos spawns; enemigos
  vivos, minería, reparaciones y el reloj siguen activos.
- **Implementado:** reloj y run se guardan y restauran antes de reactivar el
  director; el timestamp impide un spawn inmediato de recuperación.
- **Implementado:** al llegar al minuto ficticio 8.640 el modo cambia
  automáticamente a `INFINITE`. Con la velocidad inicial de 14,4 minutos
  ficticios por segundo ocurre a los 600 segundos activos; la pausa no cuenta.
- **Implementado:** cada ciclo infinito aumenta presupuesto, salud, daño y límite
  activo, reduce el intervalo hasta un mínimo y mantiene Adware con peso y máximo
  bajos. La presión no tiene cola de recuperación ni pantalla de victoria.
- **Parcialmente implementado:** los valores son una primera pasada de balance;
  no existe selector manual de modo.

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
- **Implementado:** munición y cooldown restante se restauran; una selección
  Area Shot pendiente se descarta y vuelve a evaluarse normalmente.
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
- **Implementado:** estado, progreso normal, penalización, final perfecto y lock
  de recarga se conservan al guardar/cargar.
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
- **Implementado:** si Repair estaba en contacto válido, conserva el progreso
  hasta el siguiente tick; el estado visible se deriva nuevamente de la
  geometría restaurada.
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

## 14. Perfiles, guardado y carga

Fuentes:

- `Scripts/Persistence/ProfileService.gd`
- `Scripts/Persistence/ProfileStore.gd`
- `Scripts/Persistence/DesktopSaveCoordinator.gd`
- `Data/Persistence/GameContentRegistry.tres`
- `Scenes/MainMenu/MainMenu.tscn`
- `Scripts/MainMenu/MainMenu.gd`
- `Scripts/MainMenu/MainMenuWindow.gd`
- `Scripts/Transitions/DesktopWindowRevealController.gd`

- **Implementado:** perfiles con ID estable, nombre visible, fechas y una única
  partida.
- **Implementado:** nueva partida resetea estado y runtime, crea shortcuts
  iniciales, guarda automáticamente el instante cero y recién después arranca
  reloj/director.
- **Implementado:** carga valida el archivo antes de cambiar a Desktop y
  reconstruye estados, shortcuts, ventanas, enemigos y procesos sin compras,
  costos, recompensas o animaciones de apertura.
- **Implementado:** Guardar pausa temporalmente el árbol, conserva el estado de
  pausa previo y captura un único instante lógico.
- **Implementado:** un guardado manual exitoso muestra una ventana compacta
  titulada `Windows 98`, con el mismo marco que los errores del sistema. Vive
  sobre el filtro de pausa, no consume RAM, no forma parte del snapshot y
  permanece abierta hasta cerrarla mediante OK o X.
- **Implementado:** si Save se pulsa desde el menú Inicio, el menú continúa
  abierto y el árbol permanece pausado al terminar; esa pausa no se serializa.
- **Implementado:** los errores son `PersistenceResult` con código y mensaje;
  no cierran la aplicación.
- **Implementado:** MainMenu presenta perfiles por nombre visible, conserva el
  `profile_id` estable como metadata y muestra los mensajes de error de la API.
- **Implementado:** MainMenu usa una resolución lógica fija de 2560×1440; las
  mejoras de resolución de una partida no alteran el layout del menú al volver.
- **Implementado:** Cargar sólo se habilita para un perfil seleccionado con save
  válido; Nueva partida vuelve a validar, crea el perfil e inicia Desktop.
- **Implementado:** Salir y el botón X comparten el cierre directo de la
  aplicación.
- **Implementado:** Borrar usuario confirma la operación y elimina mediante
  `ProfileService` la carpeta completa del perfil inactivo seleccionado.
- **Implementado:** LoginWindow usa una apertura/cierre local breve. Desktop no
  queda cubierto por un overlay; después de `restore_finished`, las ventanas
  restauradas se revelan por z-order sin repetir costos, RAM ni señales
  funcionales de apertura.
- **Implementado:** Shut Down de Desktop vuelve a MainMenu, normaliza la pausa y
  no guarda automáticamente.
- **Parcialmente implementado:** el aspecto del menú es provisional.
- **Planeado:** múltiples slots, autosave, renombrado y migraciones.

## 15. Fin de partida y funciones futuras

- **Parcialmente implementado:** destrucción del sistema.
- **Implementado:** UI básica de perfiles, nueva partida y carga.
- **Parcialmente implementado:** diseño visual definitivo del menú.
- **Planeado:** Options.
- **Planeado:** efecto runtime de RAM.
- **Parcialmente implementado:** presentación de fase diaria, presupuesto y
  errores de disparo.

## 16. Registro de preguntas de gameplay

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
