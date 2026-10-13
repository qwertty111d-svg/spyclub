#!/usr/bin/env bash
set -euo pipefail

# Official Luau sources; never disable Git HTTPS/TLS or change this pin silently.
tools_root="${SPY_TOOLS_ROOT:-/workspace/.spy-tools}"
luau_version="0.742"
luau_commit="8387cfb461b38ce09e37c1e4c2811538ef1bf5cb"
luau_source="$tools_root/luau-src"
build_jobs="${SPY_BUILD_JOBS:-2}"

for required_tool in git make g++ gcc install python3; do
    command -v "$required_tool" >/dev/null || {
        printf 'Missing required tool: %s\n' "$required_tool" >&2
        exit 1
    }
done
case "$build_jobs" in
    ''|*[!0-9]*|0) printf 'SPY_BUILD_JOBS must be a positive integer\n' >&2; exit 1 ;;
esac

mkdir -p "$tools_root/bin"
if [[ ! -e "$luau_source" ]]; then
    git -c advice.detachedHead=false clone --depth 1 --branch "$luau_version" \
        https://github.com/luau-lang/luau.git "$luau_source"
fi
[[ -d "$luau_source/.git" ]] || {
    printf 'Source directory exists but is not a Git checkout: %s\n' "$luau_source" >&2
    exit 1
}
actual_commit="$(git -C "$luau_source" rev-parse HEAD)"
[[ "$actual_commit" == "$luau_commit" ]] || {
    printf 'Luau commit differs from trusted pin (%s); existing checkout was preserved.\n' "$luau_commit" >&2
    exit 1
}
[[ -z "$(git -C "$luau_source" status --porcelain --untracked-files=no)" ]] || {
    printf 'Tracked Luau source files have local changes; existing checkout was preserved.\n' >&2
    exit 1
}
git -C "$luau_source" fsck --no-dangling
make -C "$luau_source" config=release MAKEFLAGS=-r -j"$build_jobs" \
    luau luau-compile luau-analyze
for binary in luau luau-compile luau-analyze; do
    install -m 755 "$luau_source/build/release/$binary" "$tools_root/bin/$binary"
done

smoke_dir="$(mktemp -d "$tools_root/luau-smoke.XXXXXX")"
trap 'rm -rf "$smoke_dir"' EXIT
cat > "$smoke_dir/smoke.luau" <<'LUAU'
--!strict
local answer: number = 6 * 7
assert(answer == 42)
local source = "return 6 * 7"
local chunk = assert(loadstring(source, "embedded-source-smoke"))
assert(chunk() == answer)
print("Luau smoke: runtime, compiler, and embedded source passed")
LUAU
"$tools_root/bin/luau-compile" --null "$smoke_dir/smoke.luau"
"$tools_root/bin/luau" "$smoke_dir/smoke.luau"
# Typecheck a pure typed sample; loadstring is a CLI extension, not a builtin type.
printf '%s\n' '--!strict' 'local answer: number = 6 * 7' 'assert(answer == 42)' > "$smoke_dir/typed.luau"
"$tools_root/bin/luau-analyze" "$smoke_dir/typed.luau"
printf 'Verified official Luau %s (%s) installed in %s/bin\n' "$luau_version" "$luau_commit" "$tools_root"
printf 'For this shell: export PATH="%s/bin:$PATH"\n' "$tools_root"
