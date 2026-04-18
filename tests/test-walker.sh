#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
extractor="${repo_root}/.claude/hooks/lib/extract-markdown-paths.py"
payloads_dir="${script_dir}/hook-payloads"

if [[ ! -f "${extractor}" ]]; then
  echo "missing extractor at ${extractor}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run these tests" >&2
  exit 1
fi

pass=0
fail=0

for input in "${payloads_dir}"/*.json; do
  name="$(basename "${input}" .json)"
  expected_file="${payloads_dir}/${name}.expected"
  if [[ ! -f "${expected_file}" ]]; then
    echo "  SKIP ${name} (no .expected)"
    continue
  fi

  actual="$(python3 "${extractor}" "${input}" | tr -d '\r' | LC_ALL=C sort)"
  expected="$(tr -d '\r' < "${expected_file}" | LC_ALL=C sort)"

  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS ${name}"
    pass=$((pass + 1))
  else
    echo "  FAIL ${name}"
    echo "    expected:"
    printf '%s\n' "${expected}" | sed 's/^/      /'
    echo "    actual:"
    printf '%s\n' "${actual}" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
done

echo "${pass} passed, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
