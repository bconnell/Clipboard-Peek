#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_SHA:?SOURCE_SHA is required; provided by the host PowerShell gate}"

if [[ ! "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'RELEASE BLOCKED: source commit is not an exact 40-character SHA' >&2
  exit 1
fi

if [[ ! -d /out ]]; then
  echo 'RELEASE BLOCKED: output mount is missing' >&2
  exit 1
fi

project=src/ClipboardPeek/ClipboardPeek.csproj
tests=tests/ClipboardPeek.Core.Tests/ClipboardPeek.Core.Tests.csproj
run=/tmp/clipboardpeek-gate
mkdir -p "$run/linux" "$run/windows"

sdk="$(dotnet --version)"
[[ "$sdk" == 10.* ]] || {
  echo "RELEASE BLOCKED: expected .NET 10 SDK, found $sdk" >&2
  exit 1
}

# Fail closed on restore/build/test errors; constrain concurrency on modest hardware.
dotnet restore "$project" -p:RestoreDisableParallel=true
dotnet restore "$tests" -p:RestoreDisableParallel=true
dotnet build "$project" -c Release --no-restore -m:1 -warnaserror
dotnet run --project "$tests" -c Release --no-restore

dotnet list "$project" package --vulnerable --include-transitive --format json > "$run/dependency-audit.json"
if ! grep -q '"projects"' "$run/dependency-audit.json"; then
  echo 'RELEASE BLOCKED: dependency audit did not return recognized JSON' >&2
  exit 1
fi
if tr -d '\n' < "$run/dependency-audit.json" | grep -Eq '"vulnerabilities"[[:space:]]*:[[:space:]]*\[[[:space:]]*\{'; then
  echo 'RELEASE BLOCKED: one or more dependencies have a published vulnerability' >&2
  exit 1
fi

common=(-c Release --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=none -p:DebugSymbols=false -m:1)
dotnet publish "$project" "${common[@]}" -r linux-x64 -o "$run/linux"
dotnet publish "$project" "${common[@]}" -r win-x64 -o "$run/windows"

linux_exe="$run/linux/ClipboardPeek"
win_exe="$run/windows/ClipboardPeek.exe"
[[ -x "$linux_exe" && -s "$win_exe" ]] || {
  echo 'RELEASE BLOCKED: expected native launchers are missing' >&2
  exit 1
}

# Validate ELF64 x86-64 and PE AMD64, not merely filename extensions.
[[ "$(od -An -tx1 -N4 "$linux_exe" | tr -d ' \n')" == 7f454c46 ]] || {
  echo 'RELEASE BLOCKED: invalid ELF launcher magic' >&2
  exit 1
}
[[ "$(od -An -tu1 -j4 -N1 "$linux_exe" | tr -d ' \n')" == 2 ]] || {
  echo 'RELEASE BLOCKED: Linux launcher is not ELF64' >&2
  exit 1
}
[[ "$(od -An -tu2 -j18 -N2 "$linux_exe" | tr -d ' \n')" == 62 ]] || {
  echo 'RELEASE BLOCKED: Linux launcher is not AMD64' >&2
  exit 1
}
[[ "$(od -An -tx1 -N2 "$win_exe" | tr -d ' \n')" == 4d5a ]] || {
  echo 'RELEASE BLOCKED: Windows launcher is missing MZ header' >&2
  exit 1
}
pe_offset="$(od -An -tu4 -j60 -N4 "$win_exe" | tr -d ' \n')"
[[ "$pe_offset" =~ ^[0-9]+$ && "$pe_offset" -ge 64 ]] || {
  echo 'RELEASE BLOCKED: invalid Windows PE offset' >&2
  exit 1
}
[[ "$(od -An -tx1 -j"$pe_offset" -N4 "$win_exe" | tr -d ' \n')" == 50450000 ]] || {
  echo 'RELEASE BLOCKED: invalid Windows PE signature' >&2
  exit 1
}
[[ "$(od -An -tx1 -j"$((pe_offset + 4))" -N2 "$win_exe" | tr -d ' \n')" == 6486 ]] || {
  echo 'RELEASE BLOCKED: Windows executable does not target AMD64' >&2
  exit 1
}

set +e
xvfb-run -a timeout 8s "$linux_exe" > "$run/linux-gui.log" 2>&1
smoke_result=$?
set -e
if [[ "$smoke_result" != 124 ]]; then
  echo "RELEASE BLOCKED: Linux GUI exited unexpectedly (status $smoke_result)" >&2
  cat "$run/linux-gui.log" >&2
  exit 1
fi

for target in linux windows; do
  cp LICENSE THIRD_PARTY_NOTICES.md "$run/$target/"
done

linux_name=ClipboardPeek-linux-x64.tar.gz
windows_name=ClipboardPeek-win-x64.zip
(
  cd "$run/linux"
  tar czf "/out/$linux_name" .
)
(
  cd "$run/windows"
  zip -q -r "/out/$windows_name" .
)

(
  cd /out
  sha256sum "$linux_name" "$windows_name" > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt
)
cp "$run/dependency-audit.json" /out/dependency-audit.json
cp "$run/linux-gui.log" /out/linux-gui-smoke.log
printf 'candidate=%s\nsdk=%s\nlinux_xvfb_smoke=passed\nwindows_native_gui=NOT_RUN\nlinux_native_gui=NOT_RUN\nmanual_accessibility_and_visual=NOT_RUN\n' \
  "$SOURCE_SHA" "$sdk" > /out/release-evidence.txt
printf 'Container gates passed for %s; native Windows acceptance remains required.\n' "$SOURCE_SHA"
