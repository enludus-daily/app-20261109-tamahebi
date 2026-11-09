#!/usr/bin/env bash
# ステージを作り直す。App/Sources/Engine のコードと tools/stagegen/main.swift を 1 つのパッケージにしてビルドする
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
mkdir -p "$work/Sources/stagegen"
cp "$root"/App/Sources/Engine/*.swift "$root/tools/stagegen/main.swift" "$work/Sources/stagegen/"
cat > "$work/Package.swift" <<'P'
// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "stagegen", targets: [.executableTarget(name: "stagegen", swiftSettings: [.unsafeFlags(["-Ounchecked"])])])
P
(cd "$work" && swift build -c release >&2)
"$work/.build/release/stagegen" "$@" > "$root/App/Resources/stages.json"
echo "書いた: App/Resources/stages.json" >&2
