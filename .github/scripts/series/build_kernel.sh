#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -x
set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
. ${d}/utils.sh

build_id=$1

install=${ci_root}/${build_id}
output=${install}_build

rm -rf ${install}
mkdir -p ${install}

cp ${d}/Image ${install}
cp -r ${d}/modules/* ${install}

