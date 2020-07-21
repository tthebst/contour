#! /usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly HERE=$(cd "$(dirname "$0")" && pwd)
readonly REPO=$(cd "${HERE}"/.. && pwd)
readonly PROGNAME=$(basename "$0")
readonly VERSION=$1
readonly PROJECT=$2


readonly TARGET="${REPO}/examples/render/contour.yaml"

exec > >(git stripspace >"$TARGET")

cat <<EOF
# This file is generated from the individual YAML files by $PROGNAME. Do not
# edit this file directly but instead edit the source files and re-render.
#
# Generated from:
EOF

(cd "${REPO}" && ls examples/contour/*.yaml) | \
  awk '{printf "#       %s\n", $0}'

echo "#"
echo

# certgen uses the ':latest' image tag, so it always needs to be pulled. Everything
# else correctly uses versioned image tags so we should use IfNotPresent.
for y in "${REPO}/examples/contour/"*.yaml ; do
    echo # Ensure we have at least one newline between joined fragments.
    case $y in
    # need sed command between kubectl to insert --- because kubectl -o yaml does not split multiple yamls 
    */02-job-certgen.yaml)
        cat "$y" \
        | kubectl label -f - app.kubernetes.io/part-of=${PROJECT} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---'\
        | kubectl label -f - app.kubernetes.io/version=${VERSION} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---'
        ;;
    # contour deployment and deamonset need to be patched because kubectl label does not label pods
    */03*.yaml)
        sed 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/g' < "$y" \
        | kubectl label -f - app.kubernetes.io/part-of=${PROJECT} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---' \
        | kubectl label -f - app.kubernetes.io/version=${VERSION} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---' \
        | kubectl patch -f - --dry-run --local -o yaml --patch '{"spec": {"template": {"metadata": {"labels": {"app.kubernetes.io/version": "'${VERSION}'","app.kubernetes.io/part-of": "'${PROJECT}'"}}}}}' \
        | sed '/^apiVersion*/i---'
        ;;
    *) 
        sed 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/g' < "$y" \
        | kubectl label -f - app.kubernetes.io/part-of=${PROJECT} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---'\
        | kubectl label -f - app.kubernetes.io/version=${VERSION} --overwrite --dry-run --local -o yaml \
        | sed '/^apiVersion*/i---'
        ;;
    esac
done
