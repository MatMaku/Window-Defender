# Vertical Slice Balance

## 1. Alcance y estado

Este documento registra la primera configuración jugable de aproximadamente diez
minutos activos seguida por supervivencia infinita. Los valores están
implementados en Resources, pero el balance continúa **parcialmente implementado**
hasta completar sesiones manuales con distintos estilos de juego.

Fuentes principales:

- `Data/GameState/GameStart.tres`
- `Shop/Apps/*.tres`
- `Shop/Upgrades/*.tres`
- `Stages/Daily/DailyWaveSequence.tres`
- `Stages/Daily/Days/Day01.tres` a `Day06.tres`
- `Stages/Daily/InfiniteWave.tres`
- `Stages/Daily/Archetypes/*.tres`
- `Scenes/Desktop/Desktop.tscn`

## 2. Supuestos del modelo

- El reloj comienza a 14,4 minutos ficticios por segundo real. Un día ficticio
  dura 100 segundos activos y seis días duran 600 segundos.
- La pausa de Inicio detiene el reloj, por lo que no consume tiempo de slice.
- El jugador usa dos Miners durante buena parte de la partida, compra mejoras de
  minería pronto y mantiene actividad manual razonable.
- Overclock se compra hacia la mitad y se completa correctamente una vez. El
  modelo no supone uptime perfecto.
- Los kills quedan por debajo de los spawns al final para permitir una población
  simultánea creciente.
- Crypto y data son cifras aproximadas. Las recompensas dependen de la selección
  ponderada, la precisión, las ventanas abiertas y el uso de Overclock.

Base minera:

```text
1 Miner: 3 crypto / 5 s = 36 crypto/min
2 Miners: 72 crypto/min
3 Miners + System + Shop: 100 RAM exactas, sin espacio para Shooting
```

Por eso dos Miners son el máximo práctico inicial sin imponer un límite de
instancias. Con las seis primeras mejoras de cantidad y todas las de intervalo,
un Miner puede alcanzar aproximadamente 486 crypto/min; esa aceleración financia
la segunda mitad y los niveles finales quedan para infinito.

## 3. Proyección minuto a minuto

| Minuto | Spawn esperado | Kills esperados | Crypto del tramo | Crypto acumulado, incluido inicio | Data del tramo | Data acumulada | Gasto crypto acumulado | Gasto data acumulado | Compras y progreso probable | RAM aprox. | Defensas disponibles |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| 0 | 0 | 0 | 0 | 50 | 0 | 0 | 0 | 0 | Abrir Miner y Shop | 100 | Ninguna |
| 1 | 5 | 3 | 85 | 135 | 6 | 6 | 70 | 0 | Shooting, Ammo, Reload; daño/Miner inicial | 100 | Disparo manual |
| 2 | 5 | 4 | 150 | 285 | 7 | 13 | 220 | 5 | Firewall y RAM I; primeros cooldown/ammo | 120 | Firewall |
| 3 | 8 | 6 | 220 | 505 | 10 | 23 | 450 | 18 | Repair, minería, daño y recarga | 140 | Firewall + Repair |
| 4 | 12 | 10 | 300 | 805 | 18 | 41 | 750 | 35 | Slowdown y expansión inicial | 160 | Firewall + Slowdown |
| 5 | 16 | 13 | 430 | 1.235 | 24 | 65 | 1.150 | 58 | Overclock y mejoras medias | 180 | Firewall + Slowdown |
| 6 | 20 | 17 | 760 | 1.995 | 32 | 97 | 1.750 | 90 | RAM, Miner, daño/cadencia; Auto Reload posible | 200 | Defensas manuales consolidadas |
| 7 | 18 | 16 | 1.100 | 3.095 | 42 | 139 | 2.500 | 130 | Primera Turret y sus primeros niveles | 220 | Firewall + Slowdown + Turret |
| 8 | 24 | 21 | 780 | 3.875 | 45 | 184 | 3.300 | 180 | Segunda instancia defensiva, Auto Fire | 220–240 | Varias ventanas defensivas |
| 9 | 35 | 30 | 930 | 4.805 | 70 | 254 | 4.200 | 240 | Area Shot y niveles 5–7 de líneas elegidas | 240 | Sinergia completa |
| 10 | 40 | 35 | 1.100 | 5.905 | 85 | 339 | 5.300 | 300 | Mayoría de niveles útiles; finales caros pendientes | 240–260 | Carga defensiva alta |

La tabla representa una ruta activa, no una garantía. Un jugador que mantenga un
solo Miner, falle Overclock o deje vivos muchos Brute progresará más lento; el
modo infinito conserva tiempo para completar lo pendiente.

## 4. Precios de aplicaciones

| Aplicación | Crypto | RAM por ventana | Rol de pacing |
|---|---:|---:|---|
| Ammo | 5 | 6 | Evita soft-lock inicial de información de munición |
| Reload | 10 | 12 | Recarga accesible junto con Shooting |
| Shooting | 20 | 18 | Combate manual del primer minuto |
| Repair | 90 | 20 | Sostén temprano/medio |
| Firewall | 120 | 32 | Primera defensa importante, minuto 2–3 |
| Slowdown | 260 | 32 | Segunda defensa, minuto 4–5 |
| Overclock | 320 | 16 | Acelerador secundario de la mitad de la slice |
| Turret | 650 | 24 | Daño automático, minuto 6–7 |

El orden defensivo surge de precio, RAM y crecimiento de ingresos: Firewall,
Slowdown y Turret. No existen prerequisites rígidos nuevos.

## 5. Curvas de upgrades

Los pares se expresan como `crypto / data` por nivel.

| Línea | Niveles | Costos por nivel | Efecto por compra | Resultado máximo |
|---|---:|---|---|---|
| Damage | 8 | `12/0, 20/1, 32/2, 50/4, 75/7, 110/12, 170/20, 260/35` | +0,5 daño | 5,0 daño |
| Cooldown | 8 | `15/0, 25/1, 40/2, 60/4, 90/7, 135/12, 200/20, 300/35` | ×`0,92, 0,92, 0,90, 0,90, 0,88, 0,88, 0,86, 0,84` | ≈0,384 s |
| Ammo | 8 | `8/0, 14/0, 22/1, 35/2, 55/4, 85/7, 130/12, 210/20` | +`2,2,2,3,3,4,4,5` | 31 balas |
| Reload | 7 | `10/0, 18/1, 30/2, 48/4, 75/7, 120/12, 190/20` | ×0,90 | ≈0,693 s normal |
| Miner output | 8 | `10/0, 18/0, 30/1, 48/2, 75/4, 115/7, 175/12, 270/20` | +2/tick | 19/tick |
| Miner interval | 6 | `18/0, 30/1, 50/2, 80/4, 130/7, 210/12` | −`0,40, 0,45, 0,50, 0,55, 0,60, 0,65` s | 1,85 s |
| RAM | 8 | `25/1, 40/2, 65/3, 100/5, 150/8, 225/13, 340/21, 520/34` | +20 | 260 RAM |
| Firewall Expansion | 6 | `35/1, 60/2, 95/4, 145/7, 220/12, 340/20` | ratio hasta 1,0 | 460×190 / 220×430 |
| Slowdown Strength | 6 | `50/2, 80/3, 125/5, 190/8, 285/13, 430/22` | multiplicador `0,61…0,35` | 35% velocidad |
| Turret Performance | 6 | `75/3, 120/5, 180/8, 270/13, 410/21, 620/34` | daño/rango/fire rate | `2,0× / 1,3× / 1,55×` |

Mejoras especializadas que conservan su cantidad de niveles:

| Mejora | Costo crypto/data | Resultado |
|---|---:|---|
| Resolution I–III | `70/8, 160/20, 300/45` | Avanza un tier por compra |
| Auto Reload | `120/15` | Desbloquea recarga automática |
| Auto Fire | `150/20` | Requiere Cooldown II |
| Area Shot | `260/45` | Requiere Auto Fire |

## 6. RAM y ventanas

La RAM inicial permanece en 100. Cada nivel suma 20 hasta 260.

| Programa | RAM | Instancias |
|---|---:|---|
| System | 8 | Una |
| Shop | 8 | Una |
| Miner | 28 | Múltiples |
| Shooting | 18 | Una |
| Ammo | 6 | Una |
| Reload | 12 | Una |
| Repair | 20 | Una |
| Firewall | 32 | Múltiples |
| Slowdown | 32 | Múltiples |
| Turret | 24 | Múltiples |
| Overclock | 16 | Una |
| SpamWindow | 16 | Múltiples, generadas por Adware |

La mejora amplía opciones, pero Spam y las defensas multiinstancia conservan la
decisión de cerrar Miners u otras ventanas.

## 7. Arquetipos

| ID persistente | Escena | Vida | Velocidad | Daño / intervalo | Data | Coste spawn | Escala | Papel |
|---|---|---:|---:|---|---:|---:|---:|---|
| `basic_virus` | `BasicVirus.tscn` | 2 | 48 | 0,50 / 1,25 s | 2 | 1,00 | 1,00 | Presión estándar |
| `runner_virus` | `BasicVirus.tscn` | 0,75, tope 1 | 85 | 0,20 / 1,50 s | 1 | 0,65 | 0,72 | Volumen y velocidad; muere con un disparo base |
| `brute_virus` | `BasicVirus.tscn` | 12 | 30 | 0,65 / 1,50 s | 6 | 3,00 | 1,40 | Objetivo resistente para disparo y drag |
| `adware_virus` | `AdwareVirus.tscn` | 3 | 42 | No ataca System | 4 | 3,00 | 1,00 | Caos y presión de RAM, aparición escasa |

Runner usa modulación verde y Brute violeta. La raíz interactiva cambia junto
con la presentación, de modo que hitbox y drag mantienen una escala coherente.
El tope opcional de salud escalada está desactivado por defecto y sólo Runner lo
fija en 1, por lo que también continúa siendo de un disparo en infinito.
Los cuatro IDs están registrados en `GameContentRegistry.tres`; el save conserva
el mismo schema y persiste sólo el ID y stats runtime finales.

## 8. Configuración de los seis tramos

Cada tramo dura aproximadamente 100 segundos activos. La cifra de spawns es el
máximo temporal aproximado antes de límites, presupuesto y frame de frontera.

| Tramo | Intervalo real | Grupo | Presupuesto | Máx. activo | Mezcla ponderada | Multiplicadores | Spawns potenciales |
|---:|---:|---:|---:|---:|---|---|---:|
| 1 | 10 s | 1 | 10 | 6 | Basic 1 | Base | ≈9 |
| 2 | 8 s | 1 | 16 | 9 | Basic 3; Runner 2,5 | Base | ≈12 |
| 3 | 7 s | 2 | 34 | 12 | Basic 3; Runner 4; Brute 0,7 | Base | ≈28 |
| 4 | 6 s | 2 | 48 | 16 | Basic 3; Runner 5; Brute 1; Adware 0,12 | Vida 1,05; velocidad 1,02 | ≈32 |
| 5 | 5 s | 2 | 75 | 22 | Basic 3; Runner 6; Brute 1,5; Adware 0,14 | Vida 1,10; velocidad 1,04; daño 1,05 | ≈38 |
| 6 | 4 s | 3 | 125 | 30 | Basic 3; Runner 8; Brute 2,2; Adware 0,16 | Vida 1,15; velocidad 1,06; daño 1,08 | ≈72 |

Los máximos de Adware son uno en los tramos 4–5 y dos en el tramo 6. Brute queda
limitado a 2, 3, 4 y 6 desde su introducción.

Comparación aproximada de presión:

| Tramo | Vida enemiga generada/s | DPS manual esperado | Apoyo esperado |
|---:|---:|---:|---|
| 1 | 0,20 | 0,7–1,0 efectivo | Drag |
| 2 | 0,18 | 1,3–2,0 | Drag + Firewall temprano |
| 3 | 0,65 | 2,0–3,0 | Firewall |
| 4 | 0,85 | 3,0–5,0 | Firewall + Slowdown |
| 5 | 1,20 | 4,5–7,0 | Varias defensas manuales |
| 6 | 2,50 | 6,0–10,0 | Primera Turret y automatizaciones |

El DPS efectivo contempla fallos, recarga, bloqueo por ventanas y selección de
objetivo; Firewall/Slowdown no agregan daño, pero amplían el tiempo disponible.

## 9. Modo infinito

Al alcanzar `total_game_minutes = 8640`, `EnemySpawnDirector` cambia
`GameRunState.spawn_mode` a `INFINITE`. No hay pantalla de victoria ni pausa.
La configuración inicial infinita usa grupo 3, presupuesto 170, intervalo 50,4
minutos ficticios (3,5 s), máximo 40 y todos los arquetipos.

Para cada ciclo ficticio completo después del cambio, con índice `c`:

```text
presupuesto = 170 + 30 × c
vida adicional = 1,10 ^ c
daño adicional = 1,05 ^ c
intervalo = max(21,6; 50,4 × 0,94 ^ c) minutos ficticios
máximo activo = min(64; 40 + 2 × c)
```

La configuración base infinita ya aplica vida 1,20, daño 1,10, velocidad 1,08 y
ataque 0,96. Adware tiene peso 0,18 frente a 14,18 totales y máximo dos. Cuando
se alcanza el límite activo, el timestamp del intento avanza: no se crea cola ni
una ráfaga al liberarse espacio.

## 10. Valores a revisar en la segunda pasada

- Tiempo real de compra de Firewall, Slowdown, Overclock y Turret con jugadores
  que no conocen la ruta económica.
- Cantidad de Miners que se mantienen abiertos frente a presión de RAM y Spam.
- Frecuencia real de kills, especialmente con grupos solapados y Area Shot.
- Si 72 spawns potenciales en el último tramo sostienen rendimiento y claridad.
- Ritmo de escalado de Brute y del máximo activo durante ciclos infinitos largos.
- Si las dos monedas terminan equilibradas o queda data/crypto sin uso.
- Porcentaje real de niveles comprados al minuto diez. El objetivo es 75–90% de
  los niveles útiles elegidos, no completar todas las líneas simultáneamente.
