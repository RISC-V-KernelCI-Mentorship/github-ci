#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
d=$(dirname "${BASH_SOURCE[0]}")

build_id=$1

rc=0

${d}/kernel_builder.sh $build_id || rc=1
${d}/selftest_builder.sh $build_id || rc=1
exit $rc
