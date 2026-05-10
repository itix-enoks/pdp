#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR/../src/design/riscy"
SIM_DIR="$SCRIPT_DIR/../src/simulation"
WORK_DIR="$SCRIPT_DIR/../vivado/aes_unit_work"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

xvlog -sv \
    "$RTL_DIR/aes_sbox.sv" \
    "$RTL_DIR/riscv_aes_unit.sv" \
    "$SIM_DIR/tb_riscv_aes_unit.sv"

xelab -debug typical tb_riscv_aes_unit -s tb_aes_sim

xsim tb_aes_sim -runall
