#!/bin/bash
# DroneWorld Log Viewer
# Interactive log file viewer with filtering and search capabilities

LOGS_DIR="logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_PATH="$PROJECT_DIR/$LOGS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print header
print_header() {
    echo ""
    print_color $CYAN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color $CYAN "$1"
    print_color $CYAN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Check if logs directory exists
check_logs_dir() {
    if [ ! -d "$LOGS_PATH" ]; then
        print_color $RED "Error: Logs directory not found at $LOGS_PATH"
        echo "Run 'make setup' or create the logs directory first."
        exit 1
    fi
}

# List all log files
list_logs() {
    print_header "Available Log Files"

    if [ -z "$(ls -A $LOGS_PATH 2>/dev/null)" ]; then
        print_color $YELLOW "No log files found."
        echo "Run the game first with 'make run' to generate logs."
        return
    fi

    print_color $GREEN "Recent logs:"
    echo ""

    # List with numbering
    local i=1
    ls -t "$LOGS_PATH" | while read file; do
        local size=$(du -h "$LOGS_PATH/$file" | cut -f1)
        local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOGS_PATH/$file" 2>/dev/null || stat -c "%y" "$LOGS_PATH/$file" 2>/dev/null | cut -d'.' -f1)
        printf "${CYAN}%2d.${NC} %-40s ${YELLOW}%8s${NC}  ${BLUE}%s${NC}\n" "$i" "$file" "$size" "$date"
        i=$((i + 1))
    done
}

# View a specific log file
view_log() {
    local log_file="$1"

    if [ ! -f "$LOGS_PATH/$log_file" ]; then
        print_color $RED "Error: Log file not found: $log_file"
        return 1
    fi

    print_header "Viewing: $log_file"

    # Check if bat is available (better syntax highlighting)
    if command -v bat &> /dev/null; then
        bat --style=numbers --color=always "$LOGS_PATH/$log_file"
    else
        # Fallback to less with color support
        less -R "$LOGS_PATH/$log_file"
    fi
}

# Tail a log file
tail_log() {
    local log_file="$1"
    local lines="${2:-50}"

    if [ ! -f "$LOGS_PATH/$log_file" ]; then
        print_color $RED "Error: Log file not found: $log_file"
        return 1
    fi

    print_header "Tailing: $log_file (last $lines lines)"
    tail -n "$lines" "$LOGS_PATH/$log_file"
}

# Follow a log file (live tail)
follow_log() {
    local log_file="$1"

    if [ ! -f "$LOGS_PATH/$log_file" ]; then
        print_color $RED "Error: Log file not found: $log_file"
        return 1
    fi

    print_header "Following: $log_file (Press Ctrl+C to stop)"
    tail -f "$LOGS_PATH/$log_file"
}

# Search in log files
search_logs() {
    local pattern="$1"
    local case_sensitive="${2:-false}"

    print_header "Searching for: '$pattern'"

    if [ "$case_sensitive" = "true" ]; then
        grep -r --color=always "$pattern" "$LOGS_PATH"
    else
        grep -ri --color=always "$pattern" "$LOGS_PATH"
    fi
}

# Filter log by type
filter_logs() {
    local log_type="$1"
    local log_file="$2"

    if [ ! -f "$LOGS_PATH/$log_file" ]; then
        print_color $RED "Error: Log file not found: $log_file"
        return 1
    fi

    print_header "Filtering: $log_file - Type: $log_type"

    case "$log_type" in
        "error"|"ERROR")
            grep -i --color=always "error" "$LOGS_PATH/$log_file"
            ;;
        "warning"|"WARNING")
            grep -i --color=always "warning\|warn" "$LOGS_PATH/$log_file"
            ;;
        "info"|"INFO")
            grep -i --color=always "info" "$LOGS_PATH/$log_file"
            ;;
        "debug"|"DEBUG")
            grep -i --color=always "debug" "$LOGS_PATH/$log_file"
            ;;
        *)
            print_color $RED "Unknown log type: $log_type"
            echo "Valid types: error, warning, info, debug"
            return 1
            ;;
    esac
}

# Show log statistics
show_stats() {
    local log_file="$1"

    if [ ! -f "$LOGS_PATH/$log_file" ]; then
        print_color $RED "Error: Log file not found: $log_file"
        return 1
    fi

    print_header "Statistics: $log_file"

    local total_lines=$(wc -l < "$LOGS_PATH/$log_file")
    local errors=$(grep -ic "error" "$LOGS_PATH/$log_file" || echo "0")
    local warnings=$(grep -ic "warning\|warn" "$LOGS_PATH/$log_file" || echo "0")
    local size=$(du -h "$LOGS_PATH/$log_file" | cut -f1)

    print_color $GREEN "Total Lines:  $total_lines"
    print_color $RED "Errors:       $errors"
    print_color $YELLOW "Warnings:     $warnings"
    print_color $BLUE "File Size:    $size"

    echo ""
    print_color $CYAN "Top Error Messages:"
    grep -i "error" "$LOGS_PATH/$log_file" | sort | uniq -c | sort -rn | head -5

    echo ""
    print_color $CYAN "Top Warning Messages:"
    grep -i "warning\|warn" "$LOGS_PATH/$log_file" | sort | uniq -c | sort -rn | head -5
}

# Compare two log files
compare_logs() {
    local log1="$1"
    local log2="$2"

    if [ ! -f "$LOGS_PATH/$log1" ]; then
        print_color $RED "Error: Log file not found: $log1"
        return 1
    fi

    if [ ! -f "$LOGS_PATH/$log2" ]; then
        print_color $RED "Error: Log file not found: $log2"
        return 1
    fi

    print_header "Comparing: $log1 vs $log2"

    if command -v diff-so-fancy &> /dev/null; then
        diff -u "$LOGS_PATH/$log1" "$LOGS_PATH/$log2" | diff-so-fancy
    else
        diff -u --color=always "$LOGS_PATH/$log1" "$LOGS_PATH/$log2" | less -R
    fi
}

# Interactive mode
interactive_mode() {
    while true; do
        print_header "DroneWorld Log Viewer - Interactive Mode"

        echo "1. List all logs"
        echo "2. View log file"
        echo "3. Tail log file"
        echo "4. Follow log file (live)"
        echo "5. Search in logs"
        echo "6. Filter log by type"
        echo "7. Show log statistics"
        echo "8. Compare two logs"
        echo "9. View latest log"
        echo "0. Exit"
        echo ""

        read -p "Select option: " choice

        case $choice in
            1)
                list_logs
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                list_logs
                echo ""
                read -p "Enter log number or filename: " log_input
                if [[ "$log_input" =~ ^[0-9]+$ ]]; then
                    log_file=$(ls -t "$LOGS_PATH" | sed -n "${log_input}p")
                else
                    log_file="$log_input"
                fi
                view_log "$log_file"
                ;;
            3)
                list_logs
                echo ""
                read -p "Enter log number or filename: " log_input
                read -p "Number of lines (default 50): " lines
                lines=${lines:-50}
                if [[ "$log_input" =~ ^[0-9]+$ ]]; then
                    log_file=$(ls -t "$LOGS_PATH" | sed -n "${log_input}p")
                else
                    log_file="$log_input"
                fi
                tail_log "$log_file" "$lines"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                list_logs
                echo ""
                read -p "Enter log number or filename: " log_input
                if [[ "$log_input" =~ ^[0-9]+$ ]]; then
                    log_file=$(ls -t "$LOGS_PATH" | sed -n "${log_input}p")
                else
                    log_file="$log_input"
                fi
                follow_log "$log_file"
                ;;
            5)
                read -p "Enter search pattern: " pattern
                read -p "Case sensitive? (y/n, default n): " case_opt
                if [ "$case_opt" = "y" ]; then
                    search_logs "$pattern" "true"
                else
                    search_logs "$pattern" "false"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                list_logs
                echo ""
                read -p "Enter log number or filename: " log_input
                read -p "Filter type (error/warning/info/debug): " filter_type
                if [[ "$log_input" =~ ^[0-9]+$ ]]; then
                    log_file=$(ls -t "$LOGS_PATH" | sed -n "${log_input}p")
                else
                    log_file="$log_input"
                fi
                filter_logs "$filter_type" "$log_file"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                list_logs
                echo ""
                read -p "Enter log number or filename: " log_input
                if [[ "$log_input" =~ ^[0-9]+$ ]]; then
                    log_file=$(ls -t "$LOGS_PATH" | sed -n "${log_input}p")
                else
                    log_file="$log_input"
                fi
                show_stats "$log_file"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                list_logs
                echo ""
                read -p "Enter first log (number or filename): " log1_input
                read -p "Enter second log (number or filename): " log2_input
                if [[ "$log1_input" =~ ^[0-9]+$ ]]; then
                    log1=$(ls -t "$LOGS_PATH" | sed -n "${log1_input}p")
                else
                    log1="$log1_input"
                fi
                if [[ "$log2_input" =~ ^[0-9]+$ ]]; then
                    log2=$(ls -t "$LOGS_PATH" | sed -n "${log2_input}p")
                else
                    log2="$log2_input"
                fi
                compare_logs "$log1" "$log2"
                ;;
            9)
                latest=$(ls -t "$LOGS_PATH" | head -1)
                view_log "$latest"
                ;;
            0)
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Show usage
show_usage() {
    print_color $CYAN "DroneWorld Log Viewer"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    print_color $GREEN "Commands:"
    echo "  list              List all log files"
    echo "  view <file>       View a log file"
    echo "  tail <file> [n]   Show last n lines (default 50)"
    echo "  follow <file>     Follow a log file (live tail)"
    echo "  search <pattern>  Search for pattern in all logs"
    echo "  filter <type> <file>  Filter log by type (error/warning/info/debug)"
    echo "  stats <file>      Show statistics for a log file"
    echo "  compare <f1> <f2> Compare two log files"
    echo "  latest            View the latest log file"
    echo "  interactive       Start interactive mode"
    echo ""
    print_color $GREEN "Examples:"
    echo "  $0 list"
    echo "  $0 view debug_20260227_143045.log"
    echo "  $0 tail run_20260227_143022.log 100"
    echo "  $0 follow run_20260227_143022.log"
    echo "  $0 search 'Physics Error'"
    echo "  $0 filter error debug_20260227_143045.log"
    echo "  $0 stats debug_20260227_143045.log"
    echo "  $0 latest"
    echo "  $0 interactive"
}

# Main script logic
main() {
    check_logs_dir

    if [ $# -eq 0 ]; then
        interactive_mode
        exit 0
    fi

    case "$1" in
        "list")
            list_logs
            ;;
        "view")
            if [ -z "$2" ]; then
                print_color $RED "Error: Please specify a log file"
                exit 1
            fi
            view_log "$2"
            ;;
        "tail")
            if [ -z "$2" ]; then
                print_color $RED "Error: Please specify a log file"
                exit 1
            fi
            tail_log "$2" "${3:-50}"
            ;;
        "follow")
            if [ -z "$2" ]; then
                print_color $RED "Error: Please specify a log file"
                exit 1
            fi
            follow_log "$2"
            ;;
        "search")
            if [ -z "$2" ]; then
                print_color $RED "Error: Please specify a search pattern"
                exit 1
            fi
            search_logs "$2"
            ;;
        "filter")
            if [ -z "$2" ] || [ -z "$3" ]; then
                print_color $RED "Error: Please specify filter type and log file"
                exit 1
            fi
            filter_logs "$2" "$3"
            ;;
        "stats")
            if [ -z "$2" ]; then
                print_color $RED "Error: Please specify a log file"
                exit 1
            fi
            show_stats "$2"
            ;;
        "compare")
            if [ -z "$2" ] || [ -z "$3" ]; then
                print_color $RED "Error: Please specify two log files"
                exit 1
            fi
            compare_logs "$2" "$3"
            ;;
        "latest")
            latest=$(ls -t "$LOGS_PATH" | head -1)
            if [ -z "$latest" ]; then
                print_color $RED "No log files found"
                exit 1
            fi
            view_log "$latest"
            ;;
        "interactive"|"-i")
            interactive_mode
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_color $RED "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"
