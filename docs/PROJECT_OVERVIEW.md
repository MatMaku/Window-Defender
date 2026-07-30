# Project Overview

## 1. Propósito

Este documento describe qué experiencia ofrece actualmente Window Defender y
qué partes de esa experiencia todavía no están cerradas. La arquitectura técnica
se documenta en `docs/ARCHITECTURE.md`.

## 2. Concepto

Window Defender presenta un sistema operativo ficticio inspirado en Windows 98.
El jugador administra aplicaciones y recursos en un escritorio que también es el
campo de batalla.

- **Implementado:** ventanas y accesos directos son objetos interactivos del
  gameplay, no solamente navegación de UI.
- **Implementado:** los virus aparecen en el escritorio, avanzan hacia
  `System.exe` y reducen la integridad del sistema.
- **Implementado:** el jugador genera recursos, compra herramientas y mejora sus
  estadísticas para responder a una amenaza creciente.
- **Desconocido:** no hay una condición de victoria demostrable en el código.

Fuentes principales:

- `Scenes/Desktop/Desktop.tscn`
- `Scripts/Desktop/Desktop.gd`
- `Scripts/System/SystemManager.gd`
- `Scripts/Virus/EnemyManager.gd`
- `Scripts/Virus/EnemySpawnDirector.gd`

## 3. Loop actual

1. `MainMenu.tscn` enumera perfiles mediante `ProfileService`.
2. Nueva partida o carga prepara una intención de sesión y cambia a Desktop.
3. `GameState` carga `Data/GameState/GameStart.tres` y reinicia sus estados
   especializados.
4. `Desktop.tscn` crea managers, capas visuales, taskbar y accesos directos.
5. El jugador abre `Miner.exe` para producir criptomonedas.
6. `Shop.exe` permite comprar aplicaciones y mejoras.
7. El reloj ficticio avanza y `EnemySpawnDirector` alterna descanso/actividad,
   consume presupuesto diario y genera virus.
8. Los virus se desplazan hasta `System.exe` y atacan su integridad.
9. `Shooting.exe` consume munición para dañarlos.
10. Las muertes entregan datos de virus.
11. Criptomonedas y datos financian mejoras.
12. `Reload.exe`, `Ammo.exe` y `Repair.exe` amplían las opciones defensivas.
13. `Firewall.exe` permite gastar RAM en paredes reubicables que desvían a los
    virus sin cerrar todas las entradas hacia `System.exe`.

Estado del loop:

- **Implementado:** pasos 1 a 11 tienen flujos conectados.
- **Parcialmente implementado:** el paso 12 depende de comprar, abrir y posicionar
  aplicaciones; algunos estados de error no tienen feedback conectado.
- **Parcialmente implementado:** la destrucción del sistema detiene nuevos
  spawns, pero no cierra la partida.

## 4. Estado inicial

`Data/GameState/GameStart.tres` sobrescribe parte de los defaults definidos en
`Data/GameState/GameStartData.gd`.

- Integridad máxima: 100.
- Daño por disparo: 1.
- Cooldown: 1 segundo.
- Munición máxima: 6.
- Recarga normal: 1,45 segundos.
- Producción minera: 1 criptomoneda cada 5 segundos por instancia abierta.
- RAM máxima: 100.
- Resolución lógica inicial: 1280 × 720.
- Fecha y hora inicial: 01/01/1998 00:00.
- Criptomonedas iniciales: 10.000.
- Datos de virus iniciales: 10.000.

Accesos directos iniciales definidos en `Scenes/Desktop/Desktop.tscn`:

- `System.exe`
- `Miner.exe`
- `Shop.exe`

- **Implementado:** estos valores se aplican en `GameState.reset_run()`.
- **Desconocido (Q-PROD-001):** confirmar si los 10.000 recursos iniciales son
  balance objetivo o configuración de desarrollo.

## 5. Aplicaciones

| Aplicación | Disponibilidad | Función | Estado |
|---|---|---|---|
| System | Inicial | Objetivo e indicador de integridad | Implementado |
| Miner | Inicial | Genera criptomonedas por instancia | Implementado |
| Shop | Inicial | Compra aplicaciones y mejoras | Implementado |
| Shooting | Tienda | Disparo manual/automático/de área | Implementado |
| Ammo | Tienda | Visualiza munición actual/máxima | Implementado |
| Reload | Tienda | Recarga normal, activa y automática | Implementado |
| Repair | Tienda | Cura por contacto con System | Implementado |
| Firewall | Tienda | Pared multiinstancia y navegación dinámica | Implementado |
| Test | No integrado | Ventana de prueba | Desconocido |

Fuentes:

- `Apps/*/*Program.tres`
- `Apps/*/*Window.tscn`
- `Shop/Apps/*.tres`
- `Apps/Test/`

## 6. Progresión y economía

- **Implementado:** Miner genera criptomonedas.
- **Implementado:** matar virus aumenta el contador de muertes y entrega datos.
- **Implementado:** aplicaciones cuestan criptomonedas.
- **Implementado:** upgrades pueden costar criptomonedas y datos.
- **Implementado:** los upgrades modifican arma, recarga, minería, RAM,
  resolución y automatizaciones.
- **Implementado:** perfiles locales conservan una partida por perfil mediante
  snapshot semántico versionado.
- **Parcialmente implementado:** no hay metaprogresión, autosave, múltiples
  slots ni renombrado de perfiles. El borrado confirmado desde MainMenu sí está
  implementado.

Fuentes:

- `Scripts/Autoload/GameEconomyState.gd`
- `Scripts/Miner/MinerWindow.gd`
- `Scripts/Shop/ShopManager.gd`
- `Scripts/Shop/UpgradeManager.gd`
- `Shop/Apps/`
- `Shop/Upgrades/`

## 7. Reloj, amenaza y oleadas diarias

`GameClockState` conserva minutos ficticios desde `01/01/1998 00:00`.
`GameClockManager` lo hace avanzar con una velocidad editable en
`Scenes/Desktop/Desktop.tscn`; la pausa del `SceneTree` detiene automáticamente
ese procesamiento.

La configuración activa es `Stages/Daily/DailyWaveSequence.tres`.

- **Implementado:** `DAILY_CYCLE` alterna descanso y actividad según minutos del
  día; el horario común inicial es 02:00–00:00.
- **Implementado:** horarios que cruzan medianoche usan inicio inclusivo y fin
  exclusivo.
- **Implementado:** `INFINITE` mantiene la fase activa durante todo el día, pero
  sigue respetando presupuesto, intervalo y límite activo.
- **Implementado:** cada spawn descuenta un coste de un presupuesto diario
  finito; no existe acumulación de amenaza por segundo.
- **Implementado:** los intentos bloqueados por el límite activo se descartan y
  no producen ráfagas posteriores.
- **Implementado:** cada arquetipo referencia su propia `PackedScene`; los stats
  finales se calculan por instancia sin mutar Resources compartidos.
- **Implementado:** al superar la lista `days`, se reutiliza la última
  configuración.
- **Parcialmente implementado:** existe una sola configuración provisional de
  prueba y no hay UI para elegir o desbloquear `INFINITE`.

## 8. Fallo y final de partida

- **Implementado:** integridad cero marca el sistema como destruido.
- **Implementado:** `SystemManager` puede presentar `SYSTEM FAILURE` si la
  ventana System está abierta.
- **Implementado:** `EnemySpawnDirector` se detiene.
- **Parcialmente implementado:** los enemigos existentes permanecen y no hay
  transición de escena, resumen, reinicio ni menú de derrota.
- **Desconocido (Q-PROD-002):** definir el flujo deseado después de system
  failure.
- **Desconocido (Q-PROD-003):** definir si existe condición de victoria y cómo se
  relaciona con los modos diario e infinito.

## 9. Funciones visibles y alcance actual

Las opciones incompletas tienen scaffolding, pero su alcance no debe inferirse
sin consulta:

- **Implementado:** Save Game, visible en `Scenes/Taskbar/Taskbar.tscn`, guarda
  la partida del perfil activo.
- **Implementado:** la carga se presenta exclusivamente desde MainMenu; el menú
  Inicio de Taskbar ya no contiene Load Game.
- **Planeado:** Options, visible en la misma escena.
- **Implementado:** abrir el menú Inicio pausa el `SceneTree`; Shut Down cierra
  el menú, normaliza la pausa y vuelve a MainMenu sin autosave mediante
  `ProfileService.return_to_main_menu()`.
- **Implementado:** `DesktopSaveCoordinator` captura estados, ventanas,
  shortcuts, procesos y enemigos; `ProfileService` valida y persiste el archivo.
- **Implementado:** `Scenes/MainMenu/MainMenu.tscn` enumera perfiles, valida
  nombres, inicia nueva partida, carga saves, elimina perfiles con confirmación
  y cierra la aplicación.
- **Parcialmente implementado:** la presentación visual del menú es deliberadamente
  básica y todavía no constituye el diseño definitivo.

## 10. Registro de preguntas de producto

Estas preguntas deben formularse cuando una tarea dependa de ellas:

- **Q-PROD-001:** ¿los 10.000 recursos iniciales son configuración de pruebas?
- **Q-PROD-002:** ¿cuál es el flujo exacto de derrota, reinicio o continuación?
- **Q-PROD-003:** ¿cómo concluye el modo diario y qué relación tiene con la
  supervivencia infinita?
- **Q-PROD-004:** ¿múltiples instancias de Miner son una estrategia definitiva?
- **Resuelto (Q-PROD-005):** Save Game preserva consecuencias productivas,
  ventanas, shortcuts, enemigos y procesos temporales documentados en
  `docs/DATA_MODEL.md`; normaliza feedback y animación puramente visual.
- **Q-PROD-006:** ¿`Apps/Test` debe conservarse, integrarse o eliminarse?
- **Q-PROD-007:** ¿cuáles son los controles y plataformas objetivo oficiales?
