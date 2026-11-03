#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/module-cache"
swiftc -module-cache-path "$ROOT/.build/module-cache" "$ROOT/Sources/ConnectivityState.swift" "$ROOT/Sources/ProbePolicy.swift" "$ROOT/Tests/HealthTests.swift" -o "$ROOT/.build/HealthTests"
"$ROOT/.build/HealthTests"
