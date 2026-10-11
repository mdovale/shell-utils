# docku — run a command in a temporary container with the working directory mounted.

docku() {
    local image="${DOCKU_IMAGE:-ubuntu:22.04}"
    local docker_bin="${DOCKU_DOCKER:-docker}"
    local as_user=0
    local host_dir
    local -a cmd
    local -a docker_args

    cmd=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
usage: docku [options] [command...]

Run a command in a temporary container. The current directory is mounted at
/work and removed from the container when the command exits (--rm).
The default command is bash. The default image is ubuntu:22.04.

The container runs as root, so files it creates in /work are root-owned.
Pass --user to run as your uid and gid instead.

  DOCKU_IMAGE   Image name (default: ubuntu:22.04)
  DOCKU_DOCKER  Container CLI (default: docker)

Options:
      --image IMAGE  Image to run
      --user         Run as the current uid:gid
  -h, --help         Show this help

  docku
  docku python
  docku --image python:3.12 python
  docku --user -- bash -lc 'id'
EOF
                return 0
                ;;
            --image)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    printf 'docku: option requires a value: %s\n' "$1" >&2
                    return 2
                fi
                image="$2"
                shift 2
                ;;
            --user)
                as_user=1
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    cmd+=("$1")
                    shift
                done
                break
                ;;
            -*)
                printf 'docku: unknown option: %s\n' "$1" >&2
                return 2
                ;;
            *)
                while [[ $# -gt 0 ]]; do
                    cmd+=("$1")
                    shift
                done
                break
                ;;
        esac
    done

    if [[ -z "$image" ]]; then
        printf 'docku: image must not be empty\n' >&2
        return 2
    fi
    if [[ ${#cmd[@]} -eq 0 ]]; then
        cmd=(bash)
    fi
    if ! command -v "$docker_bin" >/dev/null 2>&1 && [[ ! -x "$docker_bin" ]]; then
        printf 'docku: container CLI not found: %s\n' "$docker_bin" >&2
        return 1
    fi

    host_dir=${PWD:-}
    if [[ -z "$host_dir" ]]; then
        host_dir=$(pwd) || return 1
    fi

    docker_args=(
        run --rm
        --mount "type=bind,source=${host_dir},target=/work"
        -w /work
    )
    if [[ -t 0 && -t 1 ]]; then
        docker_args+=(-it)
    else
        docker_args+=(-i)
    fi
    if [[ "$as_user" -eq 1 ]]; then
        docker_args+=(-u "$(id -u):$(id -g)")
    fi

    "$docker_bin" "${docker_args[@]}" "$image" "${cmd[@]}"
}

_docku_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _docku_is_sourced; then
    docku --help
    exit $?
fi
unset -f _docku_is_sourced
