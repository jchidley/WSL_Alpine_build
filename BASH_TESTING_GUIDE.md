# Comprehensive Bash Testing and Debugging Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Testing Frameworks](#testing-frameworks)
3. [Unit Testing Best Practices](#unit-testing-best-practices)
4. [Debugging Techniques](#debugging-techniques)
5. [Mocking and Stubbing](#mocking-and-stubbing)
6. [Integration Testing](#integration-testing)
7. [CI/CD Integration](#cicd-integration)
8. [Performance Testing](#performance-testing)
9. [Real-World Examples](#real-world-examples)
10. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)

## Introduction

Testing bash scripts is crucial for maintaining reliable shell automation. This guide covers modern approaches to testing, debugging, and maintaining bash scripts in production environments.

### Why Test Bash Scripts?

- **Reliability**: Catch errors before they impact production
- **Maintainability**: Easier refactoring with confidence
- **Documentation**: Tests serve as usage examples
- **Regression Prevention**: Ensure fixes stay fixed

## Testing Frameworks

### 1. Bats (Bash Automated Testing System)

The most popular bash testing framework, providing a simple and intuitive testing experience.

#### Installation
```bash
# Using npm
npm install -g bats

# Using git
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local

# Using package manager (Ubuntu/Debian)
sudo apt-get install bats
```

#### Basic Usage
```bash
#!/usr/bin/env bats

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "invoking foo without arguments prints usage" {
  run foo
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

#### Advanced Features
```bash
# Setup and teardown
setup() {
  export TEMP_DIR="$(mktemp -d)"
  cd "$TEMP_DIR"
}

teardown() {
  cd /
  rm -rf "$TEMP_DIR"
}

# Skip tests conditionally
@test "test requiring root" {
  [ "$EUID" -ne 0 ] && skip "requires root"
  # test code here
}

# Test with timeout
@test "long running process" {
  timeout 5 ./long_script.sh
}
```

### 2. ShellSpec

A modern BDD-style testing framework for shell scripts.

#### Installation
```bash
curl -fsSL https://git.io/shellspec | sh
```

#### Example Test
```bash
Describe 'Math functions'
  Describe 'add()'
    add() {
      echo $(($1 + $2))
    }

    It 'adds two numbers'
      When call add 2 3
      The output should equal 5
    End

    It 'handles negative numbers'
      When call add -5 3
      The output should equal -2
    End
  End
End
```

### 3. Shunit2

A xUnit-based unit testing framework for bash scripts.

#### Example
```bash
#!/bin/bash

oneTimeSetUp() {
  export TEST_DIR=$(mktemp -d)
}

oneTimeTearDown() {
  rm -rf "$TEST_DIR"
}

testEquality() {
  assertEquals 1 1
}

testFileCreation() {
  touch "$TEST_DIR/test.txt"
  assertTrue "[ -f '$TEST_DIR/test.txt' ]"
}

# Load shUnit2
. ./shunit2
```

## Unit Testing Best Practices

### 1. Test Structure

```bash
#!/usr/bin/env bats

# Load the script to test
load '../src/mylib.sh'

# Group related tests
@test "validate_email: accepts valid emails" {
  run validate_email "user@example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: rejects invalid emails" {
  run validate_email "invalid.email"
  [ "$status" -eq 1 ]
}
```

### 2. Testing Functions in Isolation

```bash
# mylib.sh
calculate_discount() {
  local price=$1
  local percentage=$2
  echo "$((price * percentage / 100))"
}

# test_mylib.bats
@test "calculate_discount: 20% of 100" {
  result=$(calculate_discount 100 20)
  [ "$result" -eq 20 ]
}
```

### 3. Testing Error Conditions

```bash
@test "fails on missing required argument" {
  run ./script.sh
  [ "$status" -ne 0 ]
  [[ "${output}" =~ "Error: Missing required argument" ]]
}

@test "handles file not found gracefully" {
  run ./process_file.sh /nonexistent/file
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" =~ "File not found" ]]
}
```

## Debugging Techniques

### 1. Debug Mode with set Options

```bash
#!/bin/bash
# Enable debug mode
set -x  # Print commands as they execute
set -e  # Exit on error
set -u  # Error on undefined variables
set -o pipefail  # Propagate pipe failures

# Even better: use strict mode
set -euo pipefail
IFS=$'\n\t'

# Debug specific sections
debug() {
  [ "${DEBUG:-0}" -eq 1 ] && echo "DEBUG: $*" >&2
}

debug "Starting processing"
```

### 2. Advanced Debugging with PS4

```bash
#!/bin/bash
# Enhanced debug output
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

function process_data() {
  local file=$1
  debug "Processing file: $file"
  # ... processing logic
}
```

### 3. Logging Framework

```bash
#!/bin/bash

# Logging levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Current log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

log() {
  local level=$1
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case $level in
    ERROR) [ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ] && echo "[$timestamp] ERROR: $message" >&2 ;;
    WARN)  [ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]  && echo "[$timestamp] WARN: $message" >&2 ;;
    INFO)  [ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]  && echo "[$timestamp] INFO: $message" ;;
    DEBUG) [ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ] && echo "[$timestamp] DEBUG: $message" ;;
  esac
}

# Usage
log ERROR "Critical failure in module X"
log INFO "Processing started"
log DEBUG "Variable value: $var"
```

### 4. Interactive Debugging

```bash
#!/bin/bash

# Breakpoint function
breakpoint() {
  echo "Breakpoint reached. Press Enter to continue or Ctrl+C to exit."
  read -r
}

# Conditional breakpoint
debug_break() {
  [ "${DEBUG:-0}" -eq 1 ] && breakpoint
}

# Usage in script
process_file() {
  local file=$1
  echo "Processing: $file"
  
  debug_break  # Pause here if DEBUG=1
  
  # Continue processing
}
```

## Mocking and Stubbing

### 1. Function Mocking

```bash
# production_script.sh
send_email() {
  local to=$1
  local subject=$2
  local body=$3
  
  mail -s "$subject" "$to" <<< "$body"
}

# test_script.bats
setup() {
  # Mock the mail command
  mail() {
    echo "MOCK: mail $*" >> "$BATS_TMPDIR/mail_calls.log"
    return 0
  }
  export -f mail
}

@test "send_email calls mail with correct arguments" {
  send_email "test@example.com" "Test Subject" "Test Body"
  
  grep -q "MOCK: mail -s Test Subject test@example.com" "$BATS_TMPDIR/mail_calls.log"
}
```

### 2. Command Stubbing

```bash
# Create stub directory
setup() {
  export STUB_DIR="$BATS_TMPDIR/stubs"
  mkdir -p "$STUB_DIR"
  export PATH="$STUB_DIR:$PATH"
}

# Create command stub
create_stub() {
  local cmd=$1
  local behavior=$2
  
  cat > "$STUB_DIR/$cmd" << EOF
#!/bin/bash
$behavior
EOF
  chmod +x "$STUB_DIR/$cmd"
}

@test "script handles curl failure" {
  create_stub "curl" "exit 1"
  
  run ./download_script.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Download failed" ]]
}
```

### 3. File System Mocking

```bash
# Mock file system operations
setup() {
  export MOCK_FS="$BATS_TMPDIR/mockfs"
  mkdir -p "$MOCK_FS"
  
  # Override file check
  file_exists() {
    [ -f "$MOCK_FS/$1" ]
  }
  
  # Override file read
  read_file() {
    cat "$MOCK_FS/$1"
  }
}

@test "processes config file correctly" {
  echo "key=value" > "$MOCK_FS/config.conf"
  
  run process_config "config.conf"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Loaded key=value" ]]
}
```

## Integration Testing

### 1. Docker-based Testing

```bash
#!/usr/bin/env bats

setup() {
  # Start test container
  docker run -d --name test_env -p 8080:80 nginx:alpine
  sleep 2  # Wait for container to start
}

teardown() {
  docker rm -f test_env || true
}

@test "web service responds to health check" {
  run curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
  [ "$output" = "200" ]
}
```

### 2. Multi-Component Testing

```bash
# test_integration.bats

setup_file() {
  # Start all services
  docker-compose -f test-compose.yml up -d
  
  # Wait for services to be ready
  timeout 30 bash -c 'until docker-compose ps | grep -q "healthy"; do sleep 1; done'
}

teardown_file() {
  docker-compose -f test-compose.yml down -v
}

@test "API communicates with database" {
  # Insert test data
  docker-compose exec -T db mysql -e "INSERT INTO users VALUES (1, 'test')"
  
  # Test API endpoint
  run curl -s http://localhost:8080/api/users/1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test" ]]
}
```

### 3. End-to-End Testing

```bash
#!/usr/bin/env bats

@test "full workflow execution" {
  # Setup test environment
  export TEST_ENV=1
  export TEST_DATA_DIR="$BATS_TMPDIR/data"
  mkdir -p "$TEST_DATA_DIR"
  
  # Create test input
  cat > "$TEST_DATA_DIR/input.csv" << EOF
id,name,value
1,test1,100
2,test2,200
EOF
  
  # Run full workflow
  run ./process_workflow.sh "$TEST_DATA_DIR/input.csv" "$TEST_DATA_DIR/output.json"
  [ "$status" -eq 0 ]
  
  # Verify output
  [ -f "$TEST_DATA_DIR/output.json" ]
  jq -e '.total == 300' "$TEST_DATA_DIR/output.json"
}
```

## CI/CD Integration

### 1. GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install test dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y bats shellcheck
    
    - name: Run shellcheck
      run: |
        find . -name "*.sh" -type f | xargs shellcheck
    
    - name: Run unit tests
      run: bats tests/unit/*.bats
    
    - name: Run integration tests
      run: bats tests/integration/*.bats
    
    - name: Upload test results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test-results/
```

### 2. GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2

shellcheck:
  stage: lint
  image: koalaman/shellcheck-alpine:latest
  script:
    - find . -name "*.sh" -type f | xargs shellcheck

unit-tests:
  stage: test
  image: bats/bats:latest
  script:
    - bats tests/unit/*.bats
  artifacts:
    reports:
      junit: test-results/*.xml

integration-tests:
  stage: test
  services:
    - docker:dind
  script:
    - apk add --no-cache docker-compose
    - bats tests/integration/*.bats
```

### 3. Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Lint') {
            steps {
                sh 'shellcheck scripts/*.sh'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'bats tests/unit/*.bats --formatter junit > test-results.xml'
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh 'docker-compose -f test-compose.yml up -d'
                sh 'bats tests/integration/*.bats'
            }
            post {
                always {
                    sh 'docker-compose -f test-compose.yml down'
                }
            }
        }
    }
}
```

## Performance Testing

### 1. Benchmarking Functions

```bash
#!/bin/bash

benchmark() {
  local name=$1
  local iterations=$2
  shift 2
  
  local start=$(date +%s.%N)
  
  for ((i=0; i<iterations; i++)); do
    "$@" > /dev/null
  done
  
  local end=$(date +%s.%N)
  local duration=$(echo "$end - $start" | bc)
  
  echo "$name: $duration seconds for $iterations iterations"
  echo "Average: $(echo "scale=6; $duration / $iterations" | bc) seconds per iteration"
}

# Functions to test
method1() {
  find . -name "*.txt" | wc -l
}

method2() {
  ls -1 *.txt 2>/dev/null | wc -l
}

# Run benchmarks
benchmark "find method" 100 method1
benchmark "ls method" 100 method2
```

### 2. Memory Usage Testing

```bash
#!/usr/bin/env bats

@test "script memory usage stays under limit" {
  # Start monitoring memory
  ./monitor_memory.sh ./memory_intensive_script.sh &
  monitor_pid=$!
  
  # Run the script
  timeout 30 ./memory_intensive_script.sh
  
  # Check peak memory usage
  kill $monitor_pid
  peak_memory=$(cat peak_memory.txt)
  
  # Assert memory usage under 100MB
  [ "$peak_memory" -lt 104857600 ]
}
```

### 3. Load Testing

```bash
#!/bin/bash

# Concurrent execution testing
load_test() {
  local script=$1
  local concurrent=$2
  local iterations=$3
  
  echo "Running $concurrent concurrent instances, $iterations iterations each"
  
  local pids=()
  local start=$(date +%s)
  
  # Start concurrent processes
  for ((i=0; i<concurrent; i++)); do
    (
      for ((j=0; j<iterations; j++)); do
        $script
      done
    ) &
    pids+=($!)
  done
  
  # Wait for completion
  for pid in "${pids[@]}"; do
    wait $pid
  done
  
  local end=$(date +%s)
  echo "Total time: $((end - start)) seconds"
}

# Run load test
load_test "./api_client.sh" 10 100
```

## Real-World Examples

### 1. Database Backup Script Testing

```bash
#!/usr/bin/env bats

# Mock database commands
setup() {
  # Mock mysqldump
  mysqldump() {
    echo "-- MySQL dump mock output"
    echo "-- Database: $3"
    return 0
  }
  export -f mysqldump
  
  # Mock aws s3
  aws() {
    echo "MOCK: aws $*" >> "$BATS_TMPDIR/aws_calls.log"
    return 0
  }
  export -f aws
}

@test "backup script creates correct filename" {
  run ./backup_database.sh production
  
  # Check filename format
  [[ "$output" =~ backup_production_[0-9]{8}_[0-9]{6}.sql.gz ]]
}

@test "backup script uploads to S3" {
  ./backup_database.sh production
  
  # Verify S3 upload was called
  grep -q "s3 cp.*backup_production_.*s3://backups/" "$BATS_TMPDIR/aws_calls.log"
}

@test "backup script handles database connection failure" {
  # Mock failure
  mysqldump() { return 1; }
  export -f mysqldump
  
  run ./backup_database.sh production
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Database backup failed" ]]
}
```

### 2. Deployment Script Testing

```bash
#!/usr/bin/env bats

# Test deployment script with various scenarios

setup() {
  export DEPLOY_ENV="test"
  export DEPLOY_DIR="$BATS_TMPDIR/deploy"
  mkdir -p "$DEPLOY_DIR"
  
  # Mock SSH
  ssh() {
    echo "SSH: $*" >> "$BATS_TMPDIR/ssh.log"
    
    # Simulate different responses
    case "$*" in
      *"health_check"*)
        echo "OK"
        return 0
        ;;
      *"deploy_failure"*)
        return 1
        ;;
      *)
        return 0
        ;;
    esac
  }
  export -f ssh
}

@test "deployment performs health check" {
  run ./deploy.sh app-v1.2.3
  [ "$status" -eq 0 ]
  
  grep -q "health_check" "$BATS_TMPDIR/ssh.log"
}

@test "deployment rolls back on failure" {
  # Simulate deployment failure
  touch "$DEPLOY_DIR/deploy_failure"
  
  run ./deploy.sh app-v1.2.3
  [ "$status" -ne 0 ]
  
  # Check rollback was triggered
  grep -q "rollback" "$BATS_TMPDIR/ssh.log"
}

@test "deployment validates version format" {
  run ./deploy.sh "invalid version"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid version format" ]]
}
```

### 3. Log Processing Script Testing

```bash
#!/usr/bin/env bats

# Create test log data
setup() {
  export TEST_LOG="$BATS_TMPDIR/test.log"
  cat > "$TEST_LOG" << 'EOF'
2023-01-01 10:00:00 INFO Starting application
2023-01-01 10:00:01 ERROR Database connection failed
2023-01-01 10:00:02 WARN Retrying connection
2023-01-01 10:00:03 INFO Connection established
2023-01-01 10:00:04 ERROR Invalid user input
2023-01-01 10:00:05 INFO Request processed
EOF
}

@test "count errors correctly" {
  run ./log_analyzer.sh --count-errors "$TEST_LOG"
  [ "$output" = "2" ]
}

@test "extract time range" {
  run ./log_analyzer.sh --time-range "10:00:01" "10:00:03" "$TEST_LOG"
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" =~ "ERROR Database connection failed" ]]
}

@test "generate summary report" {
  run ./log_analyzer.sh --summary "$TEST_LOG"
  [[ "$output" =~ "Total entries: 6" ]]
  [[ "$output" =~ "Errors: 2" ]]
  [[ "$output" =~ "Warnings: 1" ]]
}
```

## Common Pitfalls and Solutions

### 1. Variable Scope Issues

```bash
# Problem: Variables modified in subshells don't persist
count=0
cat file.txt | while read line; do
  ((count++))  # This won't work as expected
done
echo "$count"  # Will be 0

# Solution: Avoid subshells
count=0
while read line; do
  ((count++))
done < file.txt
echo "$count"  # Correct count
```

### 2. Word Splitting

```bash
# Problem: Unquoted variables cause word splitting
files="file with spaces.txt"
rm $files  # Tries to remove "file", "with", "spaces.txt"

# Solution: Always quote variables
rm "$files"  # Correctly removes single file

# Test for word splitting issues
@test "handles filenames with spaces" {
  touch "$BATS_TMPDIR/file with spaces.txt"
  run ./process_file.sh "$BATS_TMPDIR/file with spaces.txt"
  [ "$status" -eq 0 ]
}
```

### 3. Exit Code Propagation

```bash
# Problem: Pipeline exit codes
false | true
echo $?  # Returns 0, not 1

# Solution: Use pipefail
set -o pipefail
false | true
echo $?  # Returns 1

# Test for proper error propagation
@test "pipeline failures are detected" {
  run bash -c 'set -o pipefail; false | true'
  [ "$status" -ne 0 ]
}
```

### 4. Race Conditions

```bash
# Problem: Multiple processes writing to same file
for i in {1..10}; do
  echo "Process $i" >> shared.log &
done
wait

# Solution: Use file locking
write_log() {
  local message=$1
  {
    flock -x 200
    echo "$message" >> shared.log
  } 200>shared.log.lock
}

# Test for race conditions
@test "concurrent writes are handled safely" {
  local log="$BATS_TMPDIR/concurrent.log"
  
  # Start multiple writers
  for i in {1..100}; do
    (echo "$i" >> "$log") &
  done
  wait
  
  # Verify all writes completed
  local count=$(wc -l < "$log")
  [ "$count" -eq 100 ]
}
```

### 5. Cleanup Issues

```bash
# Problem: Cleanup not happening on script exit
temp_file=$(mktemp)
# ... script exits early due to error
# temp_file is never removed

# Solution: Use trap for cleanup
cleanup() {
  rm -f "$temp_file"
}
trap cleanup EXIT

# Test cleanup behavior
@test "cleanup happens on error" {
  # Create a script that fails
  cat > "$BATS_TMPDIR/failing_script.sh" << 'EOF'
#!/bin/bash
temp_file=$(mktemp)
trap "rm -f $temp_file" EXIT
exit 1
EOF
  chmod +x "$BATS_TMPDIR/failing_script.sh"
  
  # Run and verify cleanup
  run "$BATS_TMPDIR/failing_script.sh"
  [ "$status" -eq 1 ]
  
  # Verify no temp files left
  [ -z "$(ls /tmp/tmp.* 2>/dev/null)" ]
}
```

## Best Practices Summary

1. **Always test error conditions** - Test what happens when things go wrong
2. **Use mocking for external dependencies** - Don't rely on external services in unit tests
3. **Keep tests fast** - Slow tests won't get run
4. **Test one thing at a time** - Each test should verify a single behavior
5. **Use descriptive test names** - The test name should explain what's being tested
6. **Clean up after tests** - Don't leave artifacts that affect other tests
7. **Use continuous integration** - Automate test execution on every commit
8. **Monitor test coverage** - Ensure critical paths are tested
9. **Test edge cases** - Empty files, missing arguments, concurrent access
10. **Document test requirements** - Make it easy for others to run tests

## Resources

- [Bats Documentation](https://bats-core.readthedocs.io/)
- [ShellSpec Documentation](https://shellspec.info/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [ShellCheck](https://www.shellcheck.net/)