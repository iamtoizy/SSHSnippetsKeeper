#!/bin/bash
MODE="${1:-safe}"
MIN_AGE="24h"
list_stopped() {
    docker ps -aq --filter "status=exited" --filter "until=$MIN_AGE"
}
case "$MODE" in
    safe)
        CONTAINERS=$(list_stopped)
        if [ -z "$CONTAINERS" ]; then
            echo "nothing to remove"
            exit 0
        fi
        echo "$CONTAINERS" | xargs docker rm
        ;;
    purge)
        docker container prune -f
        docker image prune -af --filter "until=$MIN_AGE"
        docker volume prune -f
        ;;
    report)
        docker system df
        docker ps -a --format "{{.Names}} {{.Status}}" | awk '{print $1, $2, $3, $4}'
        ;;
    *)
        echo "usage: $0 {safe|purge|report}" >&2
        exit 64
        ;;
esac
IMAGES=$(docker images -f "dangling=true" -q | wc -l)
VOLUMES=$(docker volume ls -qf dangling=true | wc -l)
echo "dangling images: $IMAGES"
echo "dangling volumes: $VOLUMES"
for C in $(docker ps -q); do
    NAME=$(docker inspect -f '{{.Name}}' "$C")
    UP=$(docker inspect -f '{{.State.StartedAt}}' "$C")
    echo "running: $NAME since $UP"
done
df -h /var/lib/docker | awk 'NR==2 {print "docker fs usage:", $5}'
exit 0
