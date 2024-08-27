#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
. $d/utils.sh

xlen=$1
config=$2
fragment=$3
toolchain=$4

tm=$(mktemp -p ${ci_root})
n=$(gen_kernel_name $xlen $config $fragment $toolchain)
logs=$(get_logs_dir)
rc=0
log="build_kernel___${n}.log"
\time --quiet -o $tm -f "took %es" \
      $d/build_kernel.sh "${xlen}" "${config}" "${fragment}" "${toolchain}" &> "${logs}/${log}" || rc=$?
if (( $rc )); then
    echo "::error::FAIL Build kernel ${n} \"${log}\" $(cat $tm)"
else
    echo "::notice::OK Build kernel ${n} $(cat $tm)"
fi
rm $tm
exit $rc
