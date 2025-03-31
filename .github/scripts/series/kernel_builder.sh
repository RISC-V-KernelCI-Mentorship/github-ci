#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
. $d/utils.sh

build_id=$1

tm=$(mktemp -p ${ci_root})
n=$build_id
logs=$(get_logs_dir)
rc=0
log="build_kernel___${n}.log"
\time --quiet -o $tm -f "took %es" \
      $d/build_kernel.sh "${build_id}" &> "${logs}/${log}" || rc=$?

if grep -a ": warning:" "${logs}/${log}" | grep -qv "frame size"; then
    # TODO Can't get rid of LLVM "warning: performing pointer arithmetic on a null pointer has undefined behavior [-Wnull-pointer-arithmetic]"
    if [[ ! "${log}" =~ "nommu" ]]; then
        echo "::error::FAIL WARNINGS kernel ${n} \"${log}\" $(cat $tm)"
    fi
elif (( $rc )); then
    echo "::error::FAIL Build kernel ${n} \"${log}\" $(cat $tm)"
else
    echo "::notice::OK Build kernel ${n} $(cat $tm)"
fi
rm $tm
exit $rc
