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

1. `GameState` carga `Data/GameState/GameStart.tres` y reinicia sus estados
   especializados.
2. `Desktop.tscn` crea managers, capas visuales, taskbar y accesos directos.
3. El jugador abre `Miner.exe` para producir criptomonedas.
4. `Shop.exe` permite comprar aplicaciones y mejoras.
5. `EnemySpawnDirector` acumula presupuesto de amenaza y genera virus.
6. Los virus se desplazan hasta `System.exe` y atacan su integridad.
7. `Shooting.exe` consume munición para dañarlos.
8. Las muertes entregan datos de virus.
9. Criptomonedas y datos financian mejoras.
10. `Reload.exe`, `Ammo.exe` y `Repair.exe` amplían las opciones defensivas.

Estado del loop:

- **Implementado:** pasos 1 a 9 tienen flujos conectados.
- **Parcialmente implementado:** el paso 10 depende de comprar, abrir y posicionar
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
- **Parcialmente implementado:** no hay metaprogresión ni persistencia entre
  ejecuciones.

Fuentes:

- `Scripts/Autoload/GameEconomyState.gd`
- `Scripts/Miner/MinerWindow.gd`
- `Scripts/Shop/ShopManager.gd`
- `Scripts/Shop/UpgradeManager.gd`
- `Shop/Apps/`
- `Shop/Upgrades/`

## 7. Amenaza y stages

Hay nueve Resources en `Stages/Prueba/Stages/`, cargados en orden por
`Scenes/Desktop/Desktop.tscn`.

- **Implementado:** Stage 0 a Stage 7 tienen duración finita.
- **Implementado:** Stage 8 tiene duración 0 y se interpreta como infinito.
- **Implementado:** cada stage define amenaza por segundo, intervalo de chequeo,
  máximo de enemigos, presupuesto y pool.
- **Implementado:** el director resuelve `GameRunState` al inicializarse y
  sincroniza allí tiempo, índice y presupuesto cada 0,25 segundos.
- **Parcialmente implementado:** ese progreso no se restaura al iniciar.
- **Parcialmente implementado:** no existe UI conectada a `stage_changed` o
  `spawn_budget_changed`.

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
  relaciona con Stage 8.

## 9. Funciones visibles y alcance actual

Las opciones incompletas tienen scaffolding, pero su alcance no debe inferirse
sin consulta:

- **Planeado:** Save Game y Load Game, visibles en
  `Scenes/Taskbar/Taskbar.tscn`.
- **Planeado:** Options, visible en la misma escena.
- **Implementado:** abrir el menú Inicio pausa el `SceneTree`; Shut Down cierra
  directamente la aplicación desde `Scripts/Taskbar/Taskbar.gd`.
- **Planeado:** snapshots de enemigos en
  `Scripts/Autoload/GameEnemySnapshotState.gd`.
- **Planeado:** restauración del director mediante
  `EnemySpawnDirector.apply_run_progress_from_game_state()`; el nombre conserva
  compatibilidad, pero la fuente runtime es `GameRunState`.

## 10. Registro de preguntas de producto

Estas preguntas deben formularse cuando una tarea dependa de ellas:

- **Q-PROD-001:** ¿los 10.000 recursos iniciales son configuración de pruebas?
- **Q-PROD-002:** ¿cuál es el flujo exacto de derrota, reinicio o continuación?
- **Q-PROD-003:** ¿hay victoria, supervivencia infinita o ambas modalidades?
- **Q-PROD-004:** ¿múltiples instancias de Miner son una estrategia definitiva?
- **Q-PROD-005:** ¿qué estados debe preservar Save Game?
- **Q-PROD-006:** ¿`Apps/Test` debe conservarse, integrarse o eliminarse?
- **Q-PROD-007:** ¿cuáles son los controles y plataformas objetivo oficiales?
