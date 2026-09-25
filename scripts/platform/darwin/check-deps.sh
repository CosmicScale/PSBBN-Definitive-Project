#!/bin/bash
# The shims answer for the Linux tool names even when the Homebrew package
# behind them is missing, so the front door checks the packages themselves.
# Prints one line per package like check_cmd does; exit 1 if any is missing.
here=$(cd "$(dirname "$0")" && pwd)
brew="${PSBBN_BREW:-}"
if [[ -z "$brew" ]]; then
    for candidate in "$(command -v brew 2>/dev/null)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            brew="$candidate"
            break
        fi
    done
fi
if [[ -z "$brew" ]]; then
    echo "[X] Homebrew not found"
    exit 1
fi
formulae=()
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line// /}"
    [[ -n "$line" ]] && formulae+=("$line")
done < "$here/formulae.txt"
# One brew call for all packages; fall back to one per package if the
# output does not line up (an unknown name makes brew stop early).
prefixes=$("$brew" --prefix "${formulae[@]}" 2>/dev/null) || prefixes=""
lines=()
while IFS= read -r line; do
    [[ -n "$line" ]] && lines+=("$line")
done <<< "$prefixes"
if [[ ${#lines[@]} -ne ${#formulae[@]} ]]; then
    lines=()
    for f in "${formulae[@]}"; do
        lines+=("$("$brew" --prefix "$f" 2>/dev/null || true)")
    done
fi
missing=0
for i in "${!formulae[@]}"; do
    if [[ -n "${lines[$i]}" && -d "${lines[$i]}" ]]; then
        echo "[✓] Homebrew package ${formulae[$i]} found"
    else
        echo "[X] Missing Homebrew package: ${formulae[$i]}"
        missing=1
    fi
done
exit $missing
