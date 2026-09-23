#!/usr/bin/env python3

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ASSEMBLER = ROOT / "assembler" / "assembler.py"


def run_assembler(source):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)

        asm_file = tmp / "test.s"
        hex_file = tmp / "test.hex"

        asm_file.write_text(source)

        result = subprocess.run(
            [
                "python3",
                str(ASSEMBLER),
                str(asm_file),
                str(hex_file),
            ],
            capture_output=True,
            text=True,
        )

        output = ""

        if hex_file.exists():
            output = hex_file.read_text()

        return result, output


class TestAssembler(unittest.TestCase):

    def test_valid_program(self):

        source = """
.section .text
.global _start

_start:
    addi x1, x0, 5
    addi x2, x0, -1

loop:
    add x3, x1, x2
    bne x3, x0, loop
"""

        result, output = run_assembler(source)

        self.assertEqual(result.returncode, 0)

        expected = (
            "00500093\n"
            "fff00113\n"
            "002081b3\n"
            "fe019ee3\n"
        )

        self.assertEqual(output, expected)


    def test_invalid_register(self):

        source = """
_start:
    addi x16, x0, 5
"""

        result, _ = run_assembler(source)

        self.assertNotEqual(result.returncode, 0)

        self.assertIn(
            "Registro invalido",
            result.stdout
        )


    def test_immediate_out_of_range(self):

        source = """
_start:
    addi x1, x0, 5000
"""

        result, _ = run_assembler(source)

        self.assertNotEqual(result.returncode, 0)

        self.assertIn(
            "fuera del rango",
            result.stdout
        )


    def test_unsupported_instruction(self):

        source = """
_start:
    mul x1, x2, x3
"""

        result, _ = run_assembler(source)

        self.assertNotEqual(result.returncode, 0)

        self.assertIn(
            "Instruccion no soportada",
            result.stdout
        )


    def test_duplicate_label(self):

        source = """
loop:
    addi x1, x0, 1

loop:
    addi x2, x0, 2
"""

        result, _ = run_assembler(source)

        self.assertNotEqual(result.returncode, 0)

        self.assertIn(
            "Etiqueta repetida",
            result.stdout
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
