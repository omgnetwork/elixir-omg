#!/bin/sh

"""
This is the script that would send a dispatch event to the helm chart repo to
auto increase chart version.

Required env vars:
- CIRCLE_TAG
- CHART_NAME
- HELM_CHART_REPO
- GITHUB_API_TOKEN
"""

set -e

increase_chart_version() {
    APP_VERSION="${CIRCLE_TAG#*v}"

    curl --location --request POST 'https://api.github.com/repos/omgnetwork/${HELM_CHART_REPO}/dispatches' \
    --header 'Accept: application/vnd.github.v3+json' \
    --header 'authorization: token ${GITHUB_API_TOKEN}' \
    --header 'Content-Type: application/json' \
    --data-raw '{"event_type": "increase-chart-version", "client_payload": { "chart_name": ${CHART_NAME}, "app_version": ${APP_VERSION} }}'
}

if [[ -n "$CIRCLE_TAG" ]]; then
    # if the tag start with a version. eg. `v1.0.3-pre.0`
    # otherwise it is not a release tag
    if [[ $CIRCLE_TAG =~ ^v.* ]]; then
        increase_chart_version
    else
        echo "Not tag for release version, skipping increase chart version..."
    fi
else
    echo "There is no circle CI tag, skipping increase chart version...."
fi
