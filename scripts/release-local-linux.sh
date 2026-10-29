#!/usr/bin/env bash
# Local Linux x64 gate. No package installation, no Git history modification.
set -euo pipefail
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export NUGET_PACKAGES="$root/.packages"
project="src/ClipboardPeek/ClipboardPeek.csproj"
tests="tests/ClipboardPeek.Core.Tests/ClipboardPeek.Core.Tests.csproj"
rid="linux-x64"
run="$root/artifacts/local/linux-$(date -u +%Y%m%dT%H%M%SZ)"
publish="$run/publish"
dist="$run/dist"

command -v git >/dev/null || { echo 'RELEASE BLOCKED: Git CLI missing' >&2; exit 1; }
git diff --quiet || { echo 'RELEASE BLOCKED: unstaged changes' >&2; exit 1; }
git diff --cached --quiet || { echo 'RELEASE BLOCKED: staged changes' >&2; exit 1; }
test -z "$(git ls-files --others --exclude-standard)" || {
    echo 'RELEASE BLOCKED: untracked files exist; do not delete them automatically' >&2
    exit 1
}
sha="$(git rev-parse HEAD)"
command -v dotnet >/dev/null || { echo 'RELEASE BLOCKED: .NET SDK missing' >&2; exit 1; }
sdk="$(dotnet --version)"
[[ "$sdk" == 10.* ]] || { echo "RELEASE BLOCKED: expected .NET 10 SDK, found $sdk" >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo 'RELEASE BLOCKED: Linux x86_64 native host is required' >&2
    exit 1
}
available="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
[[ "$available" -ge 1048576 ]] || { echo 'RELEASE BLOCKED: less than 1 GiB available RAM' >&2; exit 1; }
free_kib="$(df -Pk "$root" | awk 'NR==2 {print $4}')"
[[ "$free_kib" -ge 2097152 ]] || { echo 'RELEASE BLOCKED: less than 2 GiB free disk' >&2; exit 1; }
command -v xvfb-run >/dev/null || {
    echo 'RELEASE BLOCKED: Xvfb is needed for headless GUI smoke test' >&2
    exit 1
}
command -v timeout >/dev/null || { echo 'RELEASE BLOCKED: timeout command missing' >&2; exit 1; }
mkdir -p "$dist"

dotnet restore "$project" -p:RestoreDisableParallel=true
dotnet restore "$tests" -p:RestoreDisableParallel=true
dotnet build "$project" -c Release --no-restore -m:1 -warnaserror
dotnet run --project "$tests" -c Release --no-restore

dotnet list "$project" package --vulnerable --include-transitive --format json > "$run/dependency-audit.json"
grep -q '{' "$run/dependency-audit.json" || { echo 'RELEASE BLOCKED: invalid audit output' >&2; exit 1; }
if tr -d '\n' < "$run/dependency-audit.json" | grep -Eq '"vulnerabilities"[[:space:]]*:[[:space:]]*\[[[:space:]]*\{'; then
    echo 'RELEASE BLOCKED: at least one dependency vulnerability was reported' >&2
    exit 1
fi

dotnet publish "$project" -c Release -r "$rid" --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:DebugType=none -p:DebugSymbols=false -m:1 -o "$publish"
test -x "$publish/ClipboardPeek" || {
    echo 'RELEASE BLOCKED: executable absent or not marked executable' >&2
    exit 1
}
set +e
xvfb-run -a timeout 8s "$publish/ClipboardPeek" > "$run/gui-smoke.log" 2>&1
smoke_exit=$?
set -e
if [[ "$smoke_exit" != 124 ]]; then
    echo "RELEASE BLOCKED: GUI process exited early with status $smoke_exit" >&2
    exit 1
fi

cp LICENSE THIRD_PARTY_NOTICES.md "$publish/"
archive="ClipboardPeek-$rid.tar.gz"
tar -czf "$dist/$archive" -C "$publish" .
(
  cd "$dist"
  sha256sum "$archive" > "$archive.sha256"
  sha256sum -c "$archive.sha256"
)
cat > "$run/release-evidence.txt" <<EOF
Candidate: $sha
SDK: $sdk
Platform: linux-x64
Archive: $archive
SHA256: $(sha256sum "$dist/$archive" | cut -d ' ' -f 1)
Build and core tests: passed
Xvfb startup continuity: passed
Human GUI and compositor review: NOT RUN
EOF

printf 'Local Linux build/test/package gate passed for %s\nArchive: %s\n' "$sha" "$dist/$archive"
echo 'This does not replace manual interaction, accessibility, Wayland and performance acceptance.'
