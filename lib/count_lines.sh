# count_lines — count lines in source files by extension.

count_lines() {
    local search_dir=""
    local extensions=""
    local output_file=""
    local show_all=0
    local end_opts=0
    local positional_n=0
    local rest part ext first pname
    local tmpfile result find_status
    local -a exts
    local -a find_args

    while [[ $# -gt 0 ]]; do
        if [[ "$end_opts" -eq 0 ]]; then
            case "$1" in
                -h|--help)
                    cat <<'EOF'
usage: count_lines [options] <directory> <ext1,ext2,...> [output_file]

Count lines in files with the given extensions. Output matches wc -l.
Extensions may include a leading dot and surrounding spaces: "py, .lua".

These directories are skipped unless --all is set:
  .git  node_modules  .venv  venv  __pycache__  dist  build  .next

Options:
      --all    Do not skip dependency and VCS directories
  -h, --help   Show this help

  count_lines src py,js
  count_lines --all . py,sh counts.txt
EOF
                    return 0
                    ;;
                --all)
                    show_all=1
                    shift
                    continue
                    ;;
                --)
                    end_opts=1
                    shift
                    continue
                    ;;
                -*)
                    printf 'count_lines: unknown option: %s\n' "$1" >&2
                    return 2
                    ;;
            esac
        fi
        positional_n=$((positional_n + 1))
        case "$positional_n" in
            1) search_dir="$1" ;;
            2) extensions="$1" ;;
            3) output_file="$1" ;;
            *)
                printf 'count_lines: unexpected argument: %s\n' "$1" >&2
                return 2
                ;;
        esac
        shift
    done

    if [[ -z "$search_dir" || -z "$extensions" ]]; then
        printf 'usage: count_lines [options] <directory> <ext1,ext2,...> [output_file]\n' >&2
        return 2
    fi
    if [[ ! -d "$search_dir" ]]; then
        printf 'count_lines: not a directory: %s\n' "$search_dir" >&2
        return 1
    fi

    exts=()
    rest="${extensions},"
    while [[ "$rest" == *,* ]]; do
        part="${rest%%,*}"
        rest="${rest#*,}"
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        while [[ "$part" == .* ]]; do
            part="${part#.}"
        done
        if [[ -z "$part" ]]; then
            continue
        fi
        case "$part" in
            *[!A-Za-z0-9._+-]*)
                printf 'count_lines: invalid extension: %s\n' "$part" >&2
                return 2
                ;;
        esac
        exts+=("$part")
    done
    if [[ ${#exts[@]} -eq 0 ]]; then
        printf 'count_lines: no valid extensions provided\n' >&2
        return 2
    fi

    find_args=(-H "$search_dir")
    if [[ "$show_all" -eq 0 ]]; then
        find_args+=("(")
        first=1
        for pname in .git node_modules .venv venv __pycache__ dist build .next; do
            if [[ "$first" -eq 0 ]]; then
                find_args+=(-o)
            fi
            first=0
            find_args+=(-name "$pname")
        done
        find_args+=(")" -prune -o)
    fi
    find_args+=(-type f "(")
    first=1
    for ext in "${exts[@]}"; do
        if [[ "$first" -eq 0 ]]; then
            find_args+=(-o)
        fi
        first=0
        find_args+=(-name "*.${ext}")
    done
    find_args+=(")" -print0)

    tmpfile=$(command mktemp -t count_lines.XXXXXX) || return 1
    find_status=0
    command find "${find_args[@]}" > "$tmpfile" || find_status=$?
    if [[ "$find_status" -ne 0 && ! -s "$tmpfile" ]]; then
        command rm -f -- "$tmpfile"
        printf 'count_lines: find failed\n' >&2
        return 1
    fi
    if [[ "$find_status" -ne 0 ]]; then
        printf 'count_lines: find reported errors; showing readable matches\n' >&2
    fi

    if [[ ! -s "$tmpfile" ]]; then
        command rm -f -- "$tmpfile"
        if [[ -n "$output_file" ]]; then
            printf 'No matching files found in %s (extensions: %s)\n' "$search_dir" "$extensions" | command tee -- "$output_file" || return 1
        else
            printf 'No matching files found in %s (extensions: %s)\n' "$search_dir" "$extensions"
        fi
        return 0
    fi

    result=$(command mktemp -t count_lines.XXXXXX) || {
        command rm -f -- "$tmpfile"
        return 1
    }
    if ! command xargs -0 wc -l < "$tmpfile" > "$result"; then
        command rm -f -- "$tmpfile" "$result"
        printf 'count_lines: wc failed\n' >&2
        return 1
    fi
    command rm -f -- "$tmpfile"

    if [[ -n "$output_file" ]]; then
        command tee -- "$output_file" < "$result" || {
            command rm -f -- "$result"
            return 1
        }
    else
        command cat -- "$result" || {
            command rm -f -- "$result"
            return 1
        }
    fi
    command rm -f -- "$result"
}

_count_lines_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _count_lines_is_sourced; then
    count_lines --help
    exit $?
fi
unset -f _count_lines_is_sourced
