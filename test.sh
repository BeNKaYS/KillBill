#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/regression
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find Sources/KillBill -name '*.swift' ! -name main.swift | sort)
swiftc -o .build/regression/tests "${sources[@]}" Tests/main.swift
.build/regression/tests
