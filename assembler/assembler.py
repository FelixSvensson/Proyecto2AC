#!/usr/bin/env python3

import sys
import re


def parse_register(text):
    text = text.strip().lower()

    if not re.fullmatch(r"x(?:[0-9]|1[0-5])", text):
        raise ValueError(f"Registro invalido: {text}")

    return int(text[1:])


def parse_immediate(text):
    return int(text.strip(), 0)


def check_signed(value, bits):
    minimum = -(1 << (bits - 1))
    maximum = (1 << (bits - 1)) - 1

    if value < minimum or value > maximum:
        raise ValueError(
            f"Inmediato {value} fuera del rango de {bits} bits"
        )


def encode_u(opcode, rd, imm20):
    return (
        ((imm20 & 0xFFFFF) << 12)
        | (rd << 7)
        | opcode
    )


def encode_i(opcode, funct3, rd, rs1, immediate):
    check_signed(immediate, 12)

    return (
        ((immediate & 0xFFF) << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def encode_r(opcode, funct3, funct7, rd, rs1, rs2):
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def encode_s(opcode, funct3, rs1, rs2, immediate):
    check_signed(immediate, 12)

    imm = immediate & 0xFFF

    return (
        (((imm >> 5) & 0x7F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm & 0x1F) << 7)
        | opcode
    )


def encode_b(opcode, funct3, rs1, rs2, offset):
    if offset % 2 != 0:
        raise ValueError("Salto branch no alineado")

    check_signed(offset, 13)

    imm = offset & 0x1FFF

    return (
        (((imm >> 12) & 1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 1) << 7)
        | opcode
    )


def encode_j(opcode, rd, offset):
    if offset % 2 != 0:
        raise ValueError("Salto JAL no alineado")

    check_signed(offset, 21)

    imm = offset & 0x1FFFFF

    return (
        (((imm >> 20) & 1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | (rd << 7)
        | opcode
    )


def parse_memory_operand(text):
    text = text.replace(" ", "")

    match = re.fullmatch(
        r"(.+)\((x(?:[0-9]|1[0-5]))\)",
        text
    )

    if not match:
        raise ValueError(
            f"Operando de memoria invalido: {text}"
        )

    offset = parse_immediate(match.group(1))
    base = parse_register(match.group(2))

    return offset, base


def preprocess(lines):
    labels = {}
    instructions = []

    pc = 0

    for line_number, raw_line in enumerate(lines, 1):

        line = raw_line.split("#", 1)[0].strip()

        if not line:
            continue

        if line.startswith("."):
            continue

        while ":" in line:

            label, remaining = line.split(":", 1)

            label = label.strip()

            if not re.fullmatch(
                r"[A-Za-z_.$][A-Za-z0-9_.$]*",
                label
            ):
                break

            if label in labels:
                raise ValueError(
                    f"Etiqueta repetida: {label}"
                )

            labels[label] = pc

            line = remaining.strip()

            if not line:
                break

        if not line:
            continue

        instructions.append(
            (line_number, pc, line)
        )

        pc += 4

    return labels, instructions


def resolve_target(text, labels, pc):
    if text in labels:
        return labels[text] - pc

    return parse_immediate(text)


def assemble_instruction(line, pc, labels):

    parts = line.split(None, 1)

    instruction = parts[0].lower()

    if len(parts) > 1:
        operands = [
            value.strip()
            for value in parts[1].split(",")
        ]
    else:
        operands = []

    # --------------------------------------------------
    # U TYPE
    # --------------------------------------------------

    if instruction == "lui":

        rd = parse_register(operands[0])
        immediate = parse_immediate(operands[1])

        return encode_u(
            0x37,
            rd,
            immediate
        )

    if instruction == "auipc":

        rd = parse_register(operands[0])
        immediate = parse_immediate(operands[1])

        return encode_u(
            0x17,
            rd,
            immediate
        )

    # --------------------------------------------------
    # I TYPE ARITHMETIC
    # --------------------------------------------------

    immediate_operations = {
        "addi":  0b000,
        "slti":  0b010,
        "sltiu": 0b011,
        "xori":  0b100,
        "ori":   0b110,
        "andi":  0b111,
    }

    if instruction in immediate_operations:

        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        immediate = parse_immediate(operands[2])

        funct3 = immediate_operations[instruction]

        return encode_i(
            0x13,
            funct3,
            rd,
            rs1,
            immediate
        )

    # --------------------------------------------------
    # R TYPE
    # --------------------------------------------------

    register_operations = {
        "add":  (0b000, 0b0000000),
        "sub":  (0b000, 0b0100000),
        "sll":  (0b001, 0b0000000),
        "slt":  (0b010, 0b0000000),
        "sltu": (0b011, 0b0000000),
        "xor":  (0b100, 0b0000000),
        "srl":  (0b101, 0b0000000),
        "sra":  (0b101, 0b0100000),
        "or":   (0b110, 0b0000000),
        "and":  (0b111, 0b0000000),
    }

    if instruction in register_operations:

        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        rs2 = parse_register(operands[2])

        funct3, funct7 = register_operations[instruction]

        return encode_r(
            0x33,
            funct3,
            funct7,
            rd,
            rs1,
            rs2
        )

    # --------------------------------------------------
    # LOAD
    # --------------------------------------------------

    load_operations = {
        "lb":  0b000,
        "lh":  0b001,
        "lw":  0b010,
        "lbu": 0b100,
        "lhu": 0b101,
    }

    if instruction in load_operations:

        rd = parse_register(operands[0])

        offset, rs1 = parse_memory_operand(
            operands[1]
        )

        return encode_i(
            0x03,
            load_operations[instruction],
            rd,
            rs1,
            offset
        )

    # --------------------------------------------------
    # STORE
    # --------------------------------------------------

    store_operations = {
        "sb": 0b000,
        "sh": 0b001,
        "sw": 0b010,
    }

    if instruction in store_operations:

        rs2 = parse_register(operands[0])

        offset, rs1 = parse_memory_operand(
            operands[1]
        )

        return encode_s(
            0x23,
            store_operations[instruction],
            rs1,
            rs2,
            offset
        )

    # --------------------------------------------------
    # BRANCH
    # --------------------------------------------------

    branch_operations = {
        "beq":  0b000,
        "bne":  0b001,
        "blt":  0b100,
        "bge":  0b101,
        "bltu": 0b110,
        "bgeu": 0b111,
    }

    if instruction in branch_operations:

        rs1 = parse_register(operands[0])
        rs2 = parse_register(operands[1])

        offset = resolve_target(
            operands[2],
            labels,
            pc
        )

        return encode_b(
            0x63,
            branch_operations[instruction],
            rs1,
            rs2,
            offset
        )

    # --------------------------------------------------
    # JAL
    # --------------------------------------------------

    if instruction == "jal":

        rd = parse_register(operands[0])

        offset = resolve_target(
            operands[1],
            labels,
            pc
        )

        return encode_j(
            0x6F,
            rd,
            offset
        )

    # --------------------------------------------------
    # JALR
    # --------------------------------------------------

    if instruction == "jalr":

        rd = parse_register(operands[0])

        offset, rs1 = parse_memory_operand(
            operands[1]
        )

        return encode_i(
            0x67,
            0b000,
            rd,
            rs1,
            offset
        )

    raise ValueError(
        f"Instruccion no soportada: {instruction}"
    )


def assemble_file(input_file, output_file):

    with open(input_file, "r") as file:
        lines = file.readlines()

    labels, instructions = preprocess(lines)

    machine_code = []

    for line_number, pc, instruction in instructions:

        try:

            encoded = assemble_instruction(
                instruction,
                pc,
                labels
            )

            machine_code.append(
                f"{encoded:08x}"
            )

        except Exception as error:

            raise RuntimeError(
                f"Error linea {line_number}: "
                f"{instruction}\n{error}"
            )

    with open(output_file, "w") as file:

        for word in machine_code:
            file.write(word + "\n")

    print(
        f"Assembler OK: "
        f"{input_file} -> {output_file}"
    )

    print(
        f"{len(machine_code)} instrucciones generadas"
    )


def main():

    if len(sys.argv) != 3:

        print(
            "Uso:"
        )

        print(
            "python3 assembler.py "
            "<archivo.s> <archivo.hex>"
        )

        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:

        assemble_file(
            input_file,
            output_file
        )

    except Exception as error:

        print(error)

        sys.exit(1)


if __name__ == "__main__":
    main()
