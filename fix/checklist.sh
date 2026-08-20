#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECKLIST=${1:-"$SCRIPT_DIR/CHECKLIST.md"}

usage() {
    cat <<EOF
사용법:
  $0 [CHECKLIST]
  $0 module MODULE [CHECKLIST]
  $0 file FILE [CHECKLIST]
  $0 check FUNCTION
  $0 check FILE FUNCTION [CHECKLIST]

예:
  $0 check vsub
  $0 check src/vdsp/vecop.zig vsub
EOF
}

if [ "${1:-}" = "module" ] || [ "${1:-}" = "file" ]; then
    query_type=$1
    query_value=${2:-}
    CHECKLIST=${3:-"$SCRIPT_DIR/CHECKLIST.md"}

    if [ -z "$query_value" ]; then
        usage >&2
        exit 2
    fi
    if [ ! -f "$CHECKLIST" ]; then
        echo "체크리스트 파일을 찾을 수 없습니다: $CHECKLIST" >&2
        exit 1
    fi

    awk -v query_type="$query_type" -v query_value="$query_value" '
        BEGIN {
            label = query_type == "module" ? "모듈" : "파일"
            error_label = query_type == "module" ? "모듈을" : "파일을"
        }
        function selected() {
            return (query_type == "module" && current_module == query_value) ||
                   (query_type == "file" && current_file == query_value)
        }
        /^## / {
            current_module = substr($0, 4)
            next
        }
        /^### / {
            current_file = substr($0, 5)
            gsub(/^`|`$/, "", current_file)
            next
        }
        /^- \[[ xX]\] / {
            if (!selected()) next
            split($0, parts, "`")
            total++
            if (substr($0, 4, 1) == "x" || substr($0, 4, 1) == "X") {
                completed++
            } else {
                remaining++
                remaining_name[remaining] = parts[2]
            }
        }
        END {
            if (total == 0) {
                printf "%s 찾을 수 없습니다: %s\n", error_label, query_value > "/dev/stderr"
                exit 1
            }
            printf "조회: %s %s\n", label, query_value
            printf "진행률: %d/%d (%.2f%%)\n", completed, total, completed / total * 100
            printf "남은 함수: %d개\n", remaining
            if (remaining > 0) {
                print "남은 함수 목록:"
                for (i = 1; i <= remaining; i++) {
                    printf "  - %s\n", remaining_name[i]
                }
            }
        }
    ' "$CHECKLIST"
    exit $?
fi

if [ "${1:-}" = "check" ]; then
    shift
    CHECKLIST="$SCRIPT_DIR/../CHECKLIST.md"
    target_file=""
    case $# in
        1)
            target_function=$1
            ;;
        2)
            target_file=$1
            target_function=$2
            ;;
        3)
            target_file=$1
            target_function=$2
            CHECKLIST=$3
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac

    if [ ! -f "$CHECKLIST" ]; then
        echo "체크리스트 파일을 찾을 수 없습니다: $CHECKLIST" >&2
        exit 1
    fi

    temporary_checklist=$(mktemp "${CHECKLIST}.tmp.XXXXXX")
    trap 'rm -f "$temporary_checklist"' EXIT HUP INT TERM

    if ! awk -v target_file="$target_file" -v target_function="$target_function" '
        /^### / {
            current_file = substr($0, 5)
            gsub(/^`|`$/, "", current_file)
        }
        /^- \[[ xX]\] / {
            split($0, parts, "`")
            if (parts[2] == target_function &&
                (target_file == "" || current_file == target_file)) {
                matches++
                if (substr($0, 4, 1) == " ") {
                    $0 = substr($0, 1, 3) "x" substr($0, 5)
                    changed++
                }
            }
        }
        { print }
        END {
            if (matches != 1 || changed != 1) {
                exit 1
            }
        }
    ' "$CHECKLIST" > "$temporary_checklist"; then
        echo "체크할 미완료 항목을 하나로 특정하지 못했습니다: $target_function" >&2
        if [ -n "$target_file" ]; then
            echo "파일: $target_file" >&2
        fi
        exit 1
    fi

    mv "$temporary_checklist" "$CHECKLIST"
    trap - EXIT HUP INT TERM
    checked_module=$(awk -v target_file="$target_file" -v target_function="$target_function" '
        /^## / {
            current_module = substr($0, 4)
        }
        /^### / {
            current_file = substr($0, 5)
            gsub(/^`|`$/, "", current_file)
        }
        /^- \[[xX]\] / {
            split($0, parts, "`")
            if (parts[2] == target_function &&
                (target_file == "" || current_file == target_file)) {
                print current_module
                exit
            }
        }
    ' "$CHECKLIST")
    echo "체크 완료: [$checked_module] $target_function"
    echo
    "$0" "$CHECKLIST"
    exit 0
fi

if [ ! -f "$CHECKLIST" ]; then
    echo "체크리스트 파일을 찾을 수 없습니다: $CHECKLIST" >&2
    exit 1
fi

awk '
function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
}

function add_module(name) {
    module_count++
    module_order[module_count] = name
    current_module = name
}

function add_file(path) {
    file_count[current_module]++
    file_order[current_module, file_count[current_module]] = path
    current_file = path
}

BEGIN {
    total = 0
    completed = 0
}

/^## / {
    add_module(trim(substr($0, 4)))
    next
}

/^### / {
    path = trim(substr($0, 5))
    gsub(/^`|`$/, "", path)
    add_file(path)
    next
}

/^- \[[ xX]\] / {
    total++
    status = substr($0, 4, 1)
    if (status == "x" || status == "X") {
        completed++
        next
    }

    split($0, parts, "`")
    function_name = parts[2]
    remaining[current_module]++
    remaining_file[current_module, current_file]++
    remaining_function[current_module, current_file, remaining_file[current_module, current_file]] = function_name
}

END {
    if (total == 0) {
        print "체크리스트 항목을 찾을 수 없습니다." > "/dev/stderr"
        exit 1
    }

    printf "진행률: %d/%d (%.2f%%)\n", completed, total, completed / total * 100
    printf "남은 항목: %d개\n", total - completed

    remaining_modules = 0
    for (i = 1; i <= module_count; i++) {
        if (remaining[module_order[i]] > 0) {
            remaining_modules++
        }
    }
    printf "남은 모듈: %d/%d개\n", remaining_modules, module_count

    for (i = 1; i <= module_count; i++) {
        module = module_order[i]
        if (remaining[module] == 0) {
            continue
        }
        files_with_remaining = 0
        for (j = 1; j <= file_count[module]; j++) {
            if (remaining_file[module, file_order[module, j]] > 0) {
                files_with_remaining++
            }
        }
        printf "\n[%s] 남은 함수 %d개, 파일 %d개\n", module, remaining[module], files_with_remaining

        for (j = 1; j <= file_count[module]; j++) {
            file = file_order[module, j]
            count = remaining_file[module, file]
            if (count == 0) {
                continue
            }
            printf "  %s (%d개)\n", file, count
            for (k = 1; k <= count; k++) {
                printf "    - %s\n", remaining_function[module, file, k]
            }
        }
    }
}
' "$CHECKLIST"
