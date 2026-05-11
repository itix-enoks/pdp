#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR/../src/design/riscy"
SIM_DIR="$SCRIPT_DIR/../src/simulation"
WORK_DIR="$SCRIPT_DIR/../vivado/aes_unit_work"
SIM_LOG="$WORK_DIR/sim_output.log"

# Verify Vivado tools are on PATH
for tool in xvlog xelab xsim; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: $tool not found — did you module load vivado / source the Vivado settings?" >&2
        exit 1
    fi
done

# Clean stale artefacts from previous runs
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

xvlog -sv \
    "$RTL_DIR/aes_sbox.sv" \
    "$RTL_DIR/riscv_aes_unit.sv" \
    "$SIM_DIR/tb_riscv_aes_unit.sv"

xelab -debug typical tb_riscv_aes_unit -s tb_aes_sim

# xsim sometimes exits 0 on $fatal; tee to log and check content ourselves
xsim tb_aes_sim -runall 2>&1 | tee "$SIM_LOG" || true

# Fail fast on any per-vector FAIL lines
if grep -qE '^ +FAIL ' "$SIM_LOG"; then
    echo "ERROR: per-vector failures detected — see $SIM_LOG" >&2
    exit 1
fi

# Require the final PASS line
if ! grep -qF ' PASS:  All ' "$SIM_LOG"; then
    echo "ERROR: PASS line not found — simulation may have crashed or produced incorrect output" >&2
    echo "       Check $SIM_LOG for details" >&2
    exit 1
fi
