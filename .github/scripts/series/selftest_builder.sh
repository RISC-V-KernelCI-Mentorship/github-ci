set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
. $d/utils.sh

build_id=$1

tm=$(mktemp -p ${ci_root})
n=$build_id
logs=$(get_logs_dir)
rc=0
log="build_selftest___${n}.log"
\time --quiet -o $tm -f "took %es" \
      $d/build_selftest.sh "${build_id}" &> "${logs}/${log}" || rc=$?
if (( $rc )); then
    echo "::error::FAIL Build selftest ${n} \"${log}\" $(cat $tm)"
else
    echo "::notice::OK Build selftest ${n} $(cat $tm)"
fi
rm $tm
exit $rc
