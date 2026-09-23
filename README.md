# Proyecto 2 — Juego de Reflejos sobre Pochoco SoC

**Arquitectura de Computadores — 2026-2**  
**Universidad de los Andes**

Este repositorio implementa un juego de reflejos sobre **Pochoco SoC** y **Espino Core** para la FPGA **Lattice iCE40 HX1K / Nandland Go Board**.

El juego se ejecuta completamente en Assembly sobre Espino Core. El programa se ensambla con un **assembler propio desarrollado en Python**, se convierte a `sw/game.hex`, se carga en la memoria del SoC y finalmente se sintetiza como `game_top.bin`.

Base del proyecto: `nic0villegasc/pochoco_soc`

![Pochoco SoC Architecture](pochoco_soc.svg)

---

## 1. Funcionamiento del juego

Cada ronda funciona de la siguiente forma:

1. Se encienden los cuatro LEDs durante al menos **3 segundos**.
2. Se espera a que no haya ningún botón presionado.
3. Se selecciona pseudoaleatoriamente uno de los cuatro LEDs.
4. Se enciende solamente el LED objetivo.
5. En el mismo evento de escritura del LED, el hardware guarda el ciclo exacto de inicio de la medición.
6. El jugador debe presionar el botón correspondiente.
7. Si la respuesta es correcta, se calcula el tiempo de reacción, se muestra en los displays en **décimas de segundo** y se incrementa el número de rondas correctas.
8. Si el botón es incorrecto, se muestra `EE`, la ronda actual se reinicia y las rondas correctas anteriores se conservan.
9. Al completar **10 rondas correctas**, se calcula y muestra el tiempo de reacción promedio.

---

## 2. Flujo completo

```text
sw/game.s
    |
    v
assembler/assembler.py
    |
    v
sw/game.hex
    |
    v
rtl/game_top.v
    |
    v
Pochoco SoC
    |
    v
Espino Core
    |
    v
Yosys -> nextpnr-ice40 -> icepack
    |
    v
game_top.bin
    |
    v
Nandland Go Board
```

No se utiliza un assembler RISC-V externo para generar `game.hex`.

---

## 3. Archivos principales

```text
Proyecto2AC/
├── assembler/
│   ├── assembler.py
│   └── test_assembler.py
├── rtl/
│   ├── game_top.v
│   ├── pochoco_soc.v
│   ├── pochoco_periph.v
│   ├── pochoco_ram.v
│   ├── pochoco_spi_slave.v
│   └── espino_core/
├── sim/
│   └── pochoco_periph_tb.v
├── sw/
│   ├── game.s
│   └── game.hex
├── goboard.pcf
├── Makefile
└── README.md
```

- `sw/game.s`: lógica completa del juego.
- `sw/game.hex`: código máquina generado por el assembler.
- `assembler/assembler.py`: assembler propio.
- `assembler/test_assembler.py`: pruebas automáticas del assembler.
- `rtl/game_top.v`: top-level del proyecto.
- `rtl/pochoco_periph.v`: periféricos y extensiones de temporización.
- `sim/pochoco_periph_tb.v`: testbench del periférico.
- `Makefile`: automatiza generación, pruebas, síntesis y programación.

---

## 4. Top-level

El módulo superior es `game_top`.

Instancia Pochoco SoC de la siguiente forma:

```verilog
pochoco_soc #(
    .MemFile("sw/game.hex")
)
```

Así, Espino Core ejecuta directamente el programa generado desde `sw/game.s`.

---

## 5. Mapa de memoria

| Dirección | Acceso | Función |
|---|---|---|
| `0x0000_0000...` | R/W | RAM unificada |
| `0x8000_0000` | W | Displays de 7 segmentos |
| `0x8000_0004` | W | LEDs |
| `0x8000_0008` | R | Botones |
| `0x8000_000C` | R | Contador libre de ciclos |
| `0x8000_0010` | R | Ciclo de la última escritura a LEDs |
| `0x8001_0000...` | R/W | Periférico SPI original |

En `pochoco_periph.v` se agregaron:

- `cycle_q`: contador de 32 bits que aumenta en cada ciclo de reloj.
- `led_cycle_q`: guarda el ciclo correspondiente a la última escritura al registro de LEDs.

Cuando el software escribe en `0x8000_0004`, el hardware actualiza en el mismo evento:

```text
led_q       <- nuevo valor de LEDs
led_cycle_q <- cycle_q
```

Esto permite que el inicio de la medición coincida con el instante lógico en que aparece el LED objetivo.

---

## 6. Temporización

El reloj utilizado es de **12 MHz**.

```text
12 000 000 ciclos = 1 segundo
36 000 000 ciclos = 3 segundos
 1 200 000 ciclos = 0,1 segundos
```

La espera inicial de cada ronda termina cuando:

```text
ciclo_actual - ciclo_inicial >= 36 000 000
```

El tiempo de reacción se obtiene como:

```text
tiempo_reaccion = ciclo_actual - ciclo_inicio_LED
```

Para convertir el resultado a décimas de segundo se utilizan restas sucesivas de `1 200 000`, evitando depender de una instrucción de división.

---

## 7. Promedio de 10 rondas

Los tiempos correctos se acumulan en ciclos.

Después de 10 rondas:

```text
promedio en décimas
= total_ciclos / (10 * 1 200 000)
= total_ciclos / 12 000 000
```

El programa realiza esta conversión mediante restas sucesivas de `12 000 000`.

El valor mostrado se limita a dos dígitos (`00` a `99` décimas).

---

## 8. Selección pseudoaleatoria

La selección del objetivo usa información dinámica:

```text
valor = ciclo_actual XOR tiempo_acumulado
valor = valor + rondas_correctas
objetivo = valor AND 3
```

El resultado `0..3` se convierte en una máscara one-hot:

| Objetivo | LED |
|---:|---:|
| 0 | `0001` |
| 1 | `0010` |
| 2 | `0100` |
| 3 | `1000` |

El contador de ciclos y el tiempo de respuesta del jugador introducen variación entre rondas.

---

## 9. Assembler propio

El assembler se encuentra en:

```text
assembler/assembler.py
```

Uso directo:

```bash
python3 assembler/assembler.py sw/game.s sw/game.hex
```

Genera **una palabra hexadecimal de 32 bits por línea**.

Ejemplo:

```asm
addi x1, x0, 5
```

produce:

```text
00500093
```

### Registros

El diseño utiliza RV32E, por lo que se aceptan los registros:

```text
x0 ... x15
```

### Instrucciones soportadas

- U-type: `lui`, `auipc`
- Inmediatas: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`
- Registro-registro: `add`, `sub`, `slt`, `sltu`, `xor`, `or`, `and`
- Loads: `lb`, `lh`, `lw`, `lbu`, `lhu`
- Stores: `sb`, `sh`, `sw`
- Branches: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
- Saltos: `jal`, `jalr`

Las instrucciones de shift (`sll`, `srl`, `sra`, `slli`, `srli`, `srai`) no se aceptan porque los shifts están deshabilitados en la ALU del Espino Core utilizado.

El assembler resuelve labels mediante dos pasadas y valida registros, inmediatos, alineamiento, etiquetas duplicadas e instrucciones no soportadas.

---

## 10. Pruebas automáticas

Ejecutar:

```bash
make test
```

Este comando corre:

### Tests del assembler

`assembler/test_assembler.py`

Comprueban:

- programa válido;
- registro inválido;
- inmediato fuera de rango;
- instrucción no soportada;
- label duplicado;
- shift deshabilitado.

### Testbench del periférico

`sim/pochoco_periph_tb.v`

Comprueba:

- incremento del contador;
- escritura de LEDs;
- captura del timestamp;
- lectura de botones;
- actualización del timestamp;
- displays de 7 segmentos.

La simulación genera:

```text
sim/pochoco_periph_tb.vcd
```

Puede visualizarse con:

```bash
gtkwave sim/pochoco_periph_tb.vcd
```

---

## 11. Requisitos

- Python 3
- Make
- Yosys
- nextpnr-ice40
- Project IceStorm
- Icarus Verilog
- GTKWave

En Ubuntu/WSL:

```bash
sudo apt update
sudo apt install python3 make yosys nextpnr-ice40 fpga-icestorm iverilog gtkwave
```

---

## 12. Generar `game.hex`

```bash
make game
```

También puede ejecutarse:

```bash
python3 assembler/assembler.py sw/game.s sw/game.hex
```

El `Makefile` regenera `game.hex` automáticamente si cambia `game.s` o `assembler.py`.

---

## 13. Sintetizar

```bash
make
```

o:

```bash
make all
```

El flujo es:

```text
Yosys -> nextpnr-ice40 -> icepack -> game_top.bin
```

Dispositivo objetivo:

```text
Lattice iCE40 HX1K
package VQ100
```

Para limpiar archivos de síntesis:

```bash
make clean
```

---

## 14. Programar la FPGA

Con la Go Board conectada:

```bash
make prog
```

Esto genera el bitstream si es necesario y ejecuta:

```text
iceprog game_top.bin
```

Si se trabaja desde WSL, el dispositivo USB debe estar disponible dentro de Linux antes de utilizar `iceprog`.

---

## 15. Modificación rápida durante la evaluación

Si se modifica `sw/game.s`:

```bash
nano sw/game.s
make game
make test
make
make prog
```

Esto demuestra el flujo completo:

```text
Assembly modificado
    -> assembler propio
    -> game.hex
    -> síntesis
    -> programación FPGA
```

---

## 16. Modificaciones respecto al Pochoco SoC base

1. `rtl/game_top.v`
   - top-level propio;
   - carga `sw/game.hex`.

2. `rtl/pochoco_periph.v`
   - contador libre de 32 bits;
   - timestamp de última escritura a LEDs;
   - nuevas direcciones `0x8000_000C` y `0x8000_0010`.

3. `sw/game.s`
   - juego completo;
   - temporización;
   - selección pseudoaleatoria;
   - comprobación de botones;
   - conversión a décimas;
   - promedio de 10 rondas.

4. `assembler/assembler.py`
   - assembler propio compatible con el subconjunto utilizado por Espino Core.

5. `assembler/test_assembler.py`
   - pruebas automáticas del assembler.

6. `sim/pochoco_periph_tb.v`
   - verificación de periféricos y temporización.

7. `Makefile`
   - generación automática de `game.hex`;
   - pruebas automáticas;
   - síntesis;
   - programación.

---

## 17. Comandos principales

```bash
make game      # genera sw/game.hex
make test      # ejecuta todas las pruebas
make           # sintetiza y genera game_top.bin
make prog      # programa la FPGA
make clean     # limpia archivos generados
```
