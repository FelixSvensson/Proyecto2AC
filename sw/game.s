.section .text
.global _start



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

    lui  x6, 0x4787
    addi x6, x6, -1856



wait_three_seconds:

    lw   x9, 12(x1)

    sub  x5, x9, x4

    bltu x5, x6, wait_three_seconds



wait_release:

    lw   x8, 8(x1)

    bne  x8, x0, wait_release


    sw   x0, 0(x1)



    lw   x9, 12(x1)

    xor  x9, x9, x3
    add  x9, x9, x2

    andi x7, x9, 3



    beq  x7, x0, target_led_1

    addi x14, x0, 1
    beq  x7, x14, target_led_2

    addi x14, x0, 2
    beq  x7, x14, target_led_4

    addi x7, x0, 8
    jal  x0, target_ready


target_led_1:

    addi x7, x0, 1
    jal  x0, target_ready


target_led_2:

    addi x7, x0, 2
    jal  x0, target_ready


target_led_4:

    addi x7, x0, 4
    jal  x0, target_ready


target_ready:

    sw   x7, 4(x1)

    lw   x4, 16(x1)



wait_button:

    lw   x8, 8(x1)

    beq  x8, x0, wait_button

    lw   x9, 12(x1)

    sub  x10, x9, x4



    bne  x8, x7, wrong_button



correct_button:

    add  x3, x3, x10



    addi x11, x0, 0

    add  x14, x10, x0

    lui  x12, 0x262
    addi x12, x12, 1440


reaction_to_tenths:

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


reaction_bcd_done:

    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13

    add  x13, x13, x14

    sw   x13, 0(x1)



    addi x2, x2, 1

    addi x9, x0, 10

    beq  x2, x9, game_finished

    jal  x0, round_start



wrong_button:

    addi x9, x0, 238
    sw   x9, 0(x1)


    jal  x0, round_start



game_finished:

    sw   x0, 4(x1)



    addi x11, x0, 0

    add  x14, x3, x0

    lui  x12, 0x17D8
    addi x12, x12, -1984


average_to_tenths:

    bltu x14, x12, average_conversion_done

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


average_bcd_loop:

    bltu x14, x9, average_bcd_done

    addi x14, x14, -10
    addi x15, x15, 1

    jal  x0, average_bcd_loop


average_bcd_done:

    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13

    add  x13, x13, x14

    sw   x13, 0(x1)




finished_wait_release:

    lw   x8, 8(x1)
    bne  x8, x0, finished_wait_release

    addi x9, x0, 8


finished_wait_button4:

    lw   x8, 8(x1)
    bne  x8, x9, finished_wait_button4


finished_wait_button4_release:

    lw   x8, 8(x1)
    bne  x8, x0, finished_wait_button4_release

    jal  x0, _start