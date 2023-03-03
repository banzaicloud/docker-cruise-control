#!/usr/bin/env bash

set -euo pipefail

readonly CRUISE_CONTROL_VERSION="${CRUISE_CONTROL_VERSION:?'Cruise Control version must be set!'}"
readonly DOCKER_COMPOSE_PROJECT_NAME="${DOCKER_COMPOSE_PROJECT_NAME:-docker-cruise-control-test}"
readonly DOCKER_COMPOSE_PROJECT_DIR="${DOCKER_COMPOSE_PROJECT_DIR:-./deploy}"
readonly USE_EXISTING="${USE_EXISTING:-false}"
readonly TIMEOUT=120
readonly CRUISE_CONTROL_CONTAINER_NAME="cruisecontrol"

readonly STATUS_QUERY='[[.AnalyzerState.isProposalReady,
                       (.AnalyzerState.goalReadiness[].status
                        | . |= (if . == "ready" then true else false end))]
                        | .[] | select(. == false)] | length'
readonly BROKERS_QUERY='.KafkaBrokerState.Summary.Brokers'
readonly EXPECTED_NUMBER_OF_BROKERS=3
readonly READINESS_TIMEOUT="${READINESS_TIMEOUT:-300}"

trap cleanup SIGINT EXIT

function cleanup() {
    local err_code="${?}"
    teardown || true
    exit "${err_code}"
}

function timestamp() {
  printf "%s" "$(date +'%Y-%m-%d %H:%M:%S')"
}

function log() {
  local level="${1}"
  local msg="${2}"

  printf "%s %s: %s\n" "$(timestamp)" "${level}" "${msg}" >&2
}

function err() {
  local msg="${*}"

  log "ERROR" "${msg}"
}

function info() {
  local msg="${*}"

  log "INFO" "${msg}"
}

function teardown() {
  if [[ "${USE_EXISTING}" == "true" ]]; then
      return
  fi

  docker compose \
    		--project-name "${DOCKER_COMPOSE_PROJECT_NAME}" \
    		--project-directory "${DOCKER_COMPOSE_PROJECT_DIR}" \
    		down \
    		--remove-orphans \
    		--volumes \
    		--timeout "${TIMEOUT}"
}

function setup() {
  if [[ "${USE_EXISTING}" == "true" ]]; then
    return
  fi

  docker compose \
  		--project-name "${DOCKER_COMPOSE_PROJECT_NAME}" \
  		--project-directory "${DOCKER_COMPOSE_PROJECT_DIR}" \
  		up -d \
  		--remove-orphans \
  		--timeout "${TIMEOUT}" \
  		--wait
}

function get_cruise_control_url() {
  local host
  local port

  host="$(docker inspect \
    --format='{{(index (index .HostConfig.PortBindings "8090/tcp") 0).HostIp}}' \
    ${CRUISE_CONTROL_CONTAINER_NAME})"

  if [[ -z "${host}" ]]; then
    host="127.0.0.1"
  fi

  port="$(docker inspect \
    --format='{{(index (index .HostConfig.PortBindings "8090/tcp") 0).HostPort}}' \
    ${CRUISE_CONTROL_CONTAINER_NAME})"

  printf "%s://%s:%s" "http" "${host}" "${port}"
}

function is_ready() {
  local url="${1:?'Base url must be provided'}"
  local resp

  resp=$(curl -sSf "${url}/kafkacruisecontrol/state?substates=ANALYZER&verbose=true&json=true")
  ready=$(jq -e -r "${STATUS_QUERY}" <<< "${resp}")

  return "${ready}"
}

function wait_until_ready() {
    local url="${2:?'Base url must be provided'}"
    local timeout="${1:?'Timeout must be set'}"
    local wait
    local retry

    wait=10
    retry=$((timeout/wait))

    until [[ 0 -ge "${retry}" ]]; do
      if is_ready "${url}"; then
        return 0
      fi
      sleep "${wait}"
      retry=$((retry-1))
    done
    return 127
}

function get_number_of_brokers() {
  local url="${1:?'Base url must be provided'}"
  local resp

  resp=$(curl -sSf "${url}/kafkacruisecontrol/kafka_cluster_state?json=true")
  printf "%s" "$(jq -e -r "${BROKERS_QUERY}" <<< "${resp}")"
}

function test_cruise_control() {
  local base_url

  base_url="$(get_cruise_control_url)"

  info "Waiting until Cruise Control is ready..."
  if ! wait_until_ready "${READINESS_TIMEOUT}" "${base_url}"; then
    err "Timed out"
    return 127
  fi
  info "Ready"

  local brokers
  brokers=$(get_number_of_brokers "${base_url}")
  local test_msg
  test_msg=$(printf "TEST(CC) - %s: " "Check if Cruise Control reports the number of brokers correctly")
  printf "%s" "${test_msg}"
  if [[ "${brokers}" -ne "${EXPECTED_NUMBER_OF_BROKERS}" ]]; then
    printf "%s\n" "FAILED"
    return 11
  else
    printf "%s\n" "OK"
  fi
}

function test_cruise_control_ui() {
  local base_url

  base_url="$(get_cruise_control_url)"

  info "Waiting until Cruise Control is ready..."
  if ! wait_until_ready "${READINESS_TIMEOUT}" "${base_url}"; then
    err "Timed out"
    return 127
  fi
  info "Ready"

  local test_msg
  test_msg=$(printf "TEST(UI) - %s: " "Check if the Cruise Control UI is available")
  local url
  url="${base_url}/#/local/localhost/kafka_cluster_state"
  printf "%s" "${test_msg}"
  if ! curl -sSfL "${url}" &> /dev/null; then
    printf "%s\n" "FAILED"
    return 11
  else
    printf "%s\n" "OK"
  fi
}

function main() {
  setup
  test_cruise_control
  test_cruise_control_ui
}

main
