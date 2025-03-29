#!/bin/bash

_GITHUB_HOST=${GITHUB_HOST:="github.com"}

# If URL is not github.com then use the enterprise api endpoint
if [[ ${GITHUB_HOST} = "github.com" ]]; then
  URI="https://api.${_GITHUB_HOST}"
else
  URI="https://${_GITHUB_HOST}/api/v3"
fi

REPOSITORY=$REPO
ACCESS_TOKEN=$ACCESS_TOKEN

API_VERSION=v3
CONTENT_LENGTH_HEADER="Content-Length: 0"
AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"


case ${RUNNER_SCOPE:=""} in
  org*)
    _FULL_URL="${URI}/orgs/${ORG_NAME}/actions/runners/registration-token"
    ;;

  ent*)
    _FULL_URL="${URI}/enterprises/${ENTERPRISE_NAME}/actions/runners/registration-token"
    ;;

  *)
    # _PROTO="https://"
    # # shellcheck disable=SC2116
    # _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    # _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    # _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    # _REPO="$(echo "${_PATH}" | cut -d/ -f2)"
    _ACCOUNT=proxyserver2023
    _REPO=$REPOSITORY
    _FULL_URL="${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    ;;
esac

echo "FULL_URL ${_FULL_URL}"

REG_TOKEN="$(curl -XPOST -fsSL \
  -H "${CONTENT_LENGTH_HEADER}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" \
| jq -r '.token')"

echo "{\"token\": \"${REG_TOKEN}\", \"full_url\": \"${_FULL_URL}\"}"

cd /home/docker/actions-runner


_SHORT_URL="https://github.com/${_ACCOUNT}/${REPOSITORY}"
_RUNNER_NAME=$(cat /proc/sys/kernel/random/uuid)
_LABELS=${LABELS:-default}
_RUNNER_GROUP=${RUNNER_GROUP:-Default}

echo "Configuring"
./config.sh \
    --url "${_SHORT_URL}" \
    --token "${REG_TOKEN}" \
    --name "${_RUNNER_NAME}" \
    --labels "${_LABELS}" \
    --runnergroup "${_RUNNER_GROUP}"

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token ${REG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
