#!/usr/bin/env bash
#
# tra-speedtest
#
# A lightweight, dependency-free download-throughput test. It downloads a
# test file from a public CDN and reports the measured speed. This is an
# approximation, not a substitute for a dedicated tool - for precise
# measurements, `tra-install python` then `pip install speedtest-cli` (or
# similar) gives a more rigorous result.

set -uo pipefail

# Tries each URL in order until one succeeds.
TEST_URLS=(
    "https://ash-speed.hetzner.com/100MB.bin"
    "https://proof.ovh.net/files/100Mb.dat"
)

echo "=== TheRealAnonymousRSA VPS - download speed test ==="
echo "(lightweight approximation using a public test file; see --help below for a precise alternative)"
echo

success=false
for url in "${TEST_URLS[@]}"; do
    echo "Testing against: ${url}"
    result="$(curl -o /dev/null -s -L --max-time 20 \
        -w 'speed_bps=%{speed_download}\nhttp_code=%{http_code}\n' \
        "${url}" 2>/dev/null)"

    http_code="$(echo "${result}" | awk -F= '/http_code/ {print $2}')"
    speed_bps="$(echo "${result}" | awk -F= '/speed_bps/ {print $2}')"

    if [ "${http_code}" = "200" ] && [ -n "${speed_bps}" ]; then
        speed_mbps="$(awk -v b="${speed_bps}" 'BEGIN { printf "%.2f", (b * 8) / 1000000 }')"
        echo "Result: ${speed_mbps} Mbps"
        success=true
        break
    else
        echo "  (unreachable or failed, trying next source)"
    fi
done

if [ "${success}" = false ]; then
    echo "Could not reach any test server. Check the container's outbound network access."
    exit 1
fi
