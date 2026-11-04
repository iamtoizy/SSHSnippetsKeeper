#!/bin/bash
NAMESPACE="${1:-default}"
THRESHOLD=3
OUT_DIR="/tmp/k8s_debug_$(date +%H%M%S)"
mkdir -p "$OUT_DIR"
PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | awk "{print \$1, \$3, \$4}")
while read -r POD STATUS RESTARTS; do
    [ -z "$POD" ] && continue
    if [ "$STATUS" != "Running" ] || [ "$RESTARTS" -ge $THRESHOLD ]; then
        echo "problem pod: $POD status=$STATUS restarts=$RESTARTS"
        kubectl describe pod "$POD" -n "$NAMESPACE" > "$OUT_DIR/$POD.describe" 2>&1
        kubectl logs "$POD" -n "$NAMESPACE" --tail=100 > "$OUT_DIR/$POD.log" 2>&1
        PREVIOUS=$(kubectl logs "$POD" -n "$NAMESPACE" --previous --tail=50 2>/dev/null | wc -l)
        echo "$POD previous log lines: $PREVIOUS"
    fi
done < <(echo "$PODS")
EVENTS=$(kubectl get events -n "$NAMESPACE" --field-selector type=Warning --no-headers | wc -l)
echo "warning events: $EVENTS"
kubectl top pods -n "$NAMESPACE" --no-headers | sort -k3 -hr | head -n 5
CRASHLOOP=$(echo "$PODS" | grep -c CrashLoopBackOff)
PENDING=$(echo "$PODS" | grep -c Pending)
echo "crashloop=$CRASHLOOP pending=$PENDING"
tar -czf "$OUT_DIR.tar.gz" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
rm -rf "$OUT_DIR"
echo "bundle saved: $OUT_DIR.tar.gz"
