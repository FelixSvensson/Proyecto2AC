# Target: Espino Core / RV32E
#
# Memory map:
#   0x80000000 -> displays
#   0x80000004 -> LEDs
#   0x80000008 -> buttons
#   0x8000000C -> cycle counter
#   0x80000010 -> cycle when LEDs were last written
#
# Clock: 12 MHz
#   3.0 s = 36,000,000 cycles
#   0.1 s =  1,200,000 cycles
#
# Register use:
#   x1  = peripheral base
#   x2  = number of correct rounds
#   x3  = accumulated reaction cycles
#   x4  = start cycle
#   x5  = elapsed cycles
#   x6  = temporary / delay constant
#   x7  = target LED mask
#   x8  = buttons
#   x9  = temporary
#   x10 = reaction cycles
#   x11 = tenths of a second
#   x12 = conversion constant
#   x13 = display value
#   x14 = temporary
#   x15 = temporary

.section .text
.global _start


# --------------------------------------------------
# INITIALIZATION
# --------------------------------------------------

_start:

    # x1 = 0x80000000
    lui  x1, 0x80000

    # Correct rounds = 0
    addi x2, x0, 0

    # Sum of reaction cycles = 0
    addi x3, x0, 0

    # Clear LEDs
    sw   x0, 4(x1)

    # Clear displays
    sw   x0, 0(x1)


# ==================================================
# START OF A ROUND
# ==================================================

round_start:

    # Turn on all four LEDs
    addi x9, x0, 15
    sw   x9, 4(x1)

    # Read current cycle counter
    lw   x4, 12(x1)

    # x6 = 36,000,000 cycles = 3 seconds
    lui  x6, 0x2255
    addi x6, x6, 256


# --------------------------------------------------
# KEEP ALL LEDs ON FOR AT LEAST 3 SECONDS
# --------------------------------------------------

wait_three_seconds:

    lw   x9, 12(x1)

    # elapsed = current - start
    sub  x5, x9, x4

    # Keep waiting while elapsed < 36,000,000
    bltu x5, x6, wait_three_seconds


# --------------------------------------------------
# WAIT UNTIL ALL BUTTONS ARE RELEASED
# --------------------------------------------------

wait_release:

    lw   x8, 8(x1)

    bne  x8, x0, wait_release


# Clear display when the actual reaction test starts
    sw   x0, 0(x1)


# --------------------------------------------------
# PSEUDORANDOM TARGET
#
# Seed uses:
#   current cycle counter
#   accumulated reaction time
#   number of completed rounds
#
# We use the two low bits to obtain 0,1,2,3.
# --------------------------------------------------

    lw   x9, 12(x1)

    xor  x9, x9, x3
    add  x9, x9, x2

    andi x7, x9, 3


# Convert:
#
# 0 -> 0001
# 1 -> 0010
# 2 -> 0100
# 3 -> 1000

    beq  x7, x0, target_led_1

    addi x14, x0, 1
    beq  x7, x14, target_led_2

    addi x14, x0, 2
    beq  x7, x14, target_led_4

    # Remaining value is 3
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


# --------------------------------------------------
# START REACTION MEASUREMENT
# --------------------------------------------------

target_ready:

    # Turn on only target LED.
    #
    # Hardware simultaneously stores the exact cycle
    # in 0x80000010.
    sw   x7, 4(x1)

    # Exact start cycle
    lw   x4, 16(x1)


# --------------------------------------------------
# WAIT FOR PLAYER INPUT
# --------------------------------------------------

wait_button:

    lw   x8, 8(x1)

    beq  x8, x0, wait_button

    # Record current cycle immediately after input
    lw   x9, 12(x1)

    # Reaction cycles
    sub  x10, x9, x4


# --------------------------------------------------
# CHECK WHETHER BUTTON WAS CORRECT
# --------------------------------------------------

    bne  x8, x7, wrong_button


# ==================================================
# CORRECT RESPONSE
# ==================================================

correct_button:

    # Add reaction time to total
    add  x3, x3, x10


# --------------------------------------------------
# CONVERT REACTION CYCLES TO TENTHS
#
# 0.1 seconds at 12 MHz = 1,200,000 cycles
# --------------------------------------------------

    addi x11, x0, 0

    # Working copy of reaction cycles
    add  x14, x10, x0

    # x12 = 1,200,000
    lui  x12, 0x125
    addi x12, x12, -128


reaction_to_tenths:

    # if remaining < 1,200,000 -> done
    bltu x14, x12, reaction_conversion_done

    sub  x14, x14, x12
    addi x11, x11, 1

    # Cap display at 99 tenths
    addi x9, x0, 99
    bgeu x11, x9, reaction_cap_99

    jal  x0, reaction_to_tenths


reaction_cap_99:

    addi x11, x0, 99


reaction_conversion_done:


# --------------------------------------------------
# CONVERT 0..99 INTO TWO DECIMAL DIGITS
#
# Example:
#   17 tenths -> display 17
# --------------------------------------------------

    addi x13, x0, 0

    # x14 = remaining units
    add  x14, x11, x0

    # x15 = tens digit
    addi x15, x0, 0

    # constant 10
    addi x9, x0, 10


reaction_bcd_loop:

    bltu x14, x9, reaction_bcd_done

    addi x14, x14, -10
    addi x15, x15, 1

    jal  x0, reaction_bcd_loop


reaction_bcd_done:

    # Multiply tens digit by 16 without shifts
    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13

    # Add units digit
    add  x13, x13, x14

    # Show response time
    sw   x13, 0(x1)


# --------------------------------------------------
# ONE CORRECT ROUND COMPLETED
# --------------------------------------------------

    addi x2, x2, 1

    addi x9, x0, 10

    # After ten correct rounds -> final result
    beq  x2, x9, game_finished

    # Otherwise start another round
    jal  x0, round_start


# ==================================================
# WRONG BUTTON
# ==================================================

wrong_button:

    # Display EE to indicate error
    addi x9, x0, 238
    sw   x9, 0(x1)

    # Do NOT increment x2.
    # Correct rounds already accumulated are preserved.
    #
    # Restart the same round.
    # EE remains visible during the new 3-second phase.

    jal  x0, round_start


# ==================================================
# TEN CORRECT ROUNDS COMPLETED
# ==================================================

game_finished:

    # Turn LEDs off
    sw   x0, 4(x1)


# --------------------------------------------------
# CALCULATE AVERAGE RESPONSE TIME
#
# total_cycles / 10 rounds
# then / 1,200,000 cycles per tenth
#
# Equivalent:
#
# total_cycles / 12,000,000
#
# Result is directly the average in tenths.
# --------------------------------------------------

    addi x11, x0, 0

    # Working copy of accumulated cycles
    add  x14, x3, x0

    # x12 = 12,000,000
    lui  x12, 0xB72
    addi x12, x12, -1280


average_to_tenths:

    bltu x14, x12, average_conversion_done

    sub  x14, x14, x12
    addi x11, x11, 1

    # Cap at 99
    addi x9, x0, 99
    bgeu x11, x9, average_cap_99

    jal  x0, average_to_tenths


average_cap_99:

    addi x11, x0, 99


average_conversion_done:


# --------------------------------------------------
# CONVERT AVERAGE TO TWO DECIMAL DIGITS
# --------------------------------------------------

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

    # tens * 16
    add  x13, x15, x15
    add  x13, x13, x13
    add  x13, x13, x13
    add  x13, x13, x13

    # + units
    add  x13, x13, x14

    # Display average
    sw   x13, 0(x1)


# --------------------------------------------------
# FINISHED STATE
# --------------------------------------------------

finished_loop:

    jal  x0, finished_loop
