.section .text
.global _start

# x1 guarda la base de perifericos 0x80000000
# x2 rodas correctas de 0 a 10
# x3 suma de ciclos de reaccion de las rondas correctas
# x4 ciclo de inicio
# x5 y x6 ciclos transcurridos y la constante 75000000
# x7 objetivo
# x8 botones leidos
# x9 temporal, lecturas del contador y constante
# x10 ciclos de reaccion de la rondas
# x12 divisor
# x13 valor para el displey


_start:

    lui  x1, 0x80000

    addi x2, x0, 0

    addi x3, x0, 0

    sw   x0, 4(x1)

    sw   x0, 0(x1)



round_start:

    addi x9, x0, 15
    sw   x9, 4(x1)

    lw   x4, 12(x1)

    lui  x6, 0xEE6b
    addi x6, x6, 640



wait_three_seconds: #repita hasta que pasen 75000000 ciclos desde el inicio de la ronda

    lw   x9, 12(x1)

    sub  x5, x9, x4

    bltu x5, x6, wait_three_seconds



wait_release:

    lw   x8, 8(x1)
    bne  x8, x0, wait_release #no elije innguno mientras haya un boton apretado
    sw   x0, 0(x1)



    lw   x9, 12(x1) # arma un numero del 0 al 3 con el contador de ciclos, la suma de tiempos y el numero de ronda
    xor  x9, x9, x3   # del 0 al 3, uno por cada led 
    add  x9, x9, x2
    andi x7, x9, 3



    beq  x7, x0, target_led_1
    addi x14, x0, 1
    beq  x7, x14, target_led_2  #convierte 0-3 en un solo bit encendido 1,2,4 o 8
    addi x14, x0, 2
    beq  x7, x14, target_led_4
    addi x7, x0, 8
    jal  x0, target_ready


target_led_1:
    addi x7, x0, 1
    jal  x0, target_ready
target_led_2:
    addi x7, x0, 2
    jal  x0, target_ready   #las etiquetas convierten el numero al azar (0a3) en el patron que prenda solo un led
target_led_4:
    addi x7, x0, 4
    jal  x0, target_ready



target_ready: #enciende el leed objetivo y lee el ciclo exacto en el que ocurrio
    sw   x7, 4(x1)
    lw   x4, 16(x1)



wait_button: #lee los botones hasta que alguno este apretado. entonces lee el contador calcula el tiempo y ve si el boton coincide
    lw   x8, 8(x1)
    beq  x8, x0, wait_button
    lw   x9, 12(x1)
    sub  x10, x9, x4
    bne  x8, x7, wrong_button



correct_button: #suma los ciclos de la ronda total antes de convertir nada
    add  x3, x3, x10
    addi x11, x0, 0
    add  x14, x10, x0
    lui  x12, 0x262
    addi x12, x12, 1440


reaction_to_tenths: #divide los ciclos por 2500000 restado de uuna decima con tope de 99
    bltu x14, x12, reaction_conversion_done
    sub  x14, x14, x12
    addi x11, x11, 1
    addi x9, x0, 99
    bgeu x11, x9, reaction_cap_99
    jal  x0, reaction_to_tenths


reaction_cap_99:
    addi x11, x0, 99

reaction_conversion_done:
    addi x13, x0, 0
    add  x14, x11, x0
    addi x15, x0, 0
    addi x9, x0, 10

reaction_bcd_loop:
    bltu x14, x9, reaction_bcd_done
    addi x14, x14, -10
    addi x15, x15, 1
    jal  x0, reaction_bcd_loop
reaction_bcd_done:               # separa el numero 0-99 en decenas y unidades y lo escribe como dos digitos
    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x14
    sw   x13, 0(x1)


    addi x2, x2, 1
    addi x9, x0, 10
    beq  x2, x9, game_finished    #suma una ronda correcta, con 10 va al final sino empieza otra ronda
    jal  x0, round_start



wrong_button:              #muestra ee y vuelve a empezar la ronda
    addi x9, x0, 238
    sw   x9, 0(x1)
    jal  x0, round_start


game_finished:
    sw   x0, 4(x1)
    addi x11, x0, 0
    add  x14, x3, x0    #apaga los leds , calcula el promedio y lo muestra
    lui  x12, 0x17D8
    addi x12, x12, -1984


average_to_tenths:
    bltu x14, x12, average_conversion_done   #divide restando, le quita 2500000 a x14 y le suma 1 en x11 hasta lque lo que queda es menor
    sub  x14, x14, x12
    addi x11, x11, 1
    addi x9, x0, 99
    bgeu x11, x9, average_cap_99
    jal  x0, average_to_tenths

average_cap_99:
    addi x11, x0, 99

average_conversion_done:
    addi x13, x0, 0
    add  x14, x11, x0
    addi x15, x0, 0
    addi x9, x0, 10

average_bcd_loop:  #separa decenas y unidades
    bltu x14, x9, average_bcd_done
    addi x14, x14, -10
    addi x15, x15, 1
    jal  x0, average_bcd_loop

average_bcd_done: #arma el numero para los display
    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x14
    sw   x13, 0(x1)

finished_wait_release: #espera a que quites todos los botones
    lw   x8, 8(x1)
    bne  x8, x0, finished_wait_release
    addi x9, x0, 8


finished_wait_button4: #espera a que los botones muestran exactamente 8
    lw   x8, 8(x1)
    bne  x8, x9, finished_wait_button4

finished_wait_button4_release: # espera a que sueltes el boton 4 para que esa ultima pulsacion no cuente como respuesta
    lw   x8, 8(x1)
    bne  x8, x0, finished_wait_button4_release
    jal  x0, _start
