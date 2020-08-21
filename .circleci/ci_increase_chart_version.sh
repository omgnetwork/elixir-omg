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
set -x

increase_chart_version() {
    APP_VERSION="${CIRCLE_TAG#*v}"

    echo "increase chart version for chart: ${CHART_NAME} with APP_VERSION: ${APP_VERSION}"

    curl --location --request POST 'https://api.github.com/repos/omgnetwork/'${HELM_CHART_REPO}'/dispatches' \
    --header 'Accept: application/vnd.github.v3+json' \
    --header 'authorization: token '${GITHUB_API_TOKEN}'' \
    --header 'Content-Type: application/json' \
    --data-raw '{"event_type": "increase-chart-version", "client_payload": { "chart_name": "'${CHART_NAME}'", "app_version": "'${APP_VERSION}'" }}'
}

increase_chart_version
