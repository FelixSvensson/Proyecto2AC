# Proyecto 2 — Juego de Reflejos sobre Pochoco SoC

**Arquitectura de Computadores — 2026-2**  
**Universidad de los Andes**

Este repositorio implementa un juego de reflejos sobre **Pochoco SoC** y **Espino Core** para la FPGA **Lattice iCE40 HX1K / Nandland Go Board**.

El juego se ejecuta completamente en Assembly sobre el procesador Espino Core. El programa se ensambla con un **assembler propio desarrollado en Python**, se convierte a `sw/game.hex`, se carga en la memoria del SoC y finalmente se sintetiza como `game_top.bin`.

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
7. Si la respuesta es correcta:
   - se calcula el tiempo de reacción;
   - se muestra en los displays de 7 segmentos en **décimas de segundo**;
   - se incrementa el número de rondas correctas.
8. Si el botón es incorrecto:
   - se muestra `EE` en los displays;
   - la ronda actual se reinicia;
   - las rondas correctas anteriores se conservan.
9. Al completar **10 rondas correctas**, se calcula y muestra el tiempo de reacción promedio.

---

## 2. Flujo completo del proyecto

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
Yosys
    |
    v
nextpnr-ice40
    |
    v
icepack
    |
    v
game_top.bin
    |
    v
Nandland Go Board
