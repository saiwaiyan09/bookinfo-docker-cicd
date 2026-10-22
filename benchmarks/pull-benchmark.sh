#!/usr/bin/env bash

set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-saiwaiyan09}"

SERVICES=(productpage details ratings reviews)
VERSIONS=(original updated optimized)

OUTPUT="benchmarks/pull-results.csv"

mkdir -p benchmarks

echo "service,version,pull_time_seconds" > "$OUTPUT"

for service in "${SERVICES[@]}"; do
    for version in "${VERSIONS[@]}"; do

        IMAGE="${DOCKERHUB_USER}/bookinfo-${service}:${version}"

        echo "===================================="
        echo "Benchmarking: $IMAGE"
        echo "===================================="

        # Remove local image reference.
        # Shared layers may remain cached.
        docker image rm "$IMAGE" 2>/dev/null || true

        START=$(date +%s.%N)

        docker pull --platform linux/amd64 "$IMAGE"

        END=$(date +%s.%N)

        DURATION=$(awk -v start="$START" -v end="$END" \
          'BEGIN {printf "%.3f", end-start}')

        echo "$service,$version,$DURATION" >> "$OUTPUT"

        echo "Pull Time: ${DURATION}s"
        echo

    done
done

echo "Benchmark complete."
echo "Results saved to $OUTPUT"
