#!/bin/bash
set -o pipefail
USAGE="usage: deploy.sh -e env -t tag [-r]"
ENV_NAME=""
IMAGE_TAG=""
ROLLBACK=0
while getopts "e:t:rh" OPT; do
    case "$OPT" in
        e) ENV_NAME="$OPTARG" ;;
        t) IMAGE_TAG="$OPTARG" ;;
        r) ROLLBACK=1 ;;
        h) echo "$USAGE"; exit 0 ;;
        *) echo "$USAGE" >&2; exit 64 ;;
    esac
done
shift $((OPTIND - 1))
if [ -z "$ENV_NAME" ] || [ -z "$IMAGE_TAG" ]; then
    echo "$USAGE" >&2
    exit 64
fi
rollback() {
    kubectl rollout undo deployment/app -n "$ENV_NAME"
    echo "rollback executed" >&2
}
trap rollback ERR
kubectl set image deployment/app app="registry.local/app:$IMAGE_TAG" -n "$ENV_NAME"
kubectl rollout status deployment/app -n "$ENV_NAME" --timeout=180s
if [ "$ROLLBACK" -eq 1 ]; then
    rollback
    exit 0
fi
kubectl annotate deployment/app deployed-at="$(date -Is)" -n "$ENV_NAME" --overwrite
kubectl get pods -n "$ENV_NAME" -o wide | awk '{print $1, $3, $5}'
echo "deployed $IMAGE_TAG to $ENV_NAME"
git tag "deploy/$ENV_NAME/$IMAGE_TAG" 2>/dev/null || true
git push origin "deploy/$ENV_NAME/$IMAGE_TAG" 2>/dev/null || true
trap - ERR
