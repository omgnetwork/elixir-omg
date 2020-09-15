#!/bin/sh

"""
This is the script that would send a dispatch event to the helm chart repo to auto increase chart version.
You can set the UPDATE_DEV flag to decide whether to update to dev too.

For master, we increase the chart version and update dev together. The app version should be short git sha with length 7.
For release, we increase the chart version only. The app version should be semver. (eg. 1.0.3-pre.0)

Required env vars:
- CHART_NAME (eg. childchain, watcher, watcher-info)
- APP_VERSION (eg. 3d75118 or 1.0.3-pre.0)
- HELM_CHART_REPO (eg. helm-devlopement)
- UPDATE_DEV (true/false)
- GITHUB_API_TOKEN
"""

set -ex

[ -z "$CHART_NAME" ] && echo "CHART_NAME should be set" && exit 1
[ -z "$APP_VERSION" ] && echo "APP_VERSION should be set" && exit 1
[ -z "$HELM_CHART_REPO" ] && echo "HELM_CHART_REPO should be set" && exit 1
[ -z "$UPDATE_DEV" ] && echo "HELM_CHART_REPO should be set" && exit 1
[ -z "$GITHUB_API_TOKEN" ] && echo "GITHUB_API_TOKEN should be set" && exit 1


echo "increase chart version: chart [${CHART_NAME}], appVersion: [${APP_VERSION}], update_dev: [${UPDATE_DEV}]"

curl --location --request POST "https://api.github.com/repos/omgnetwork/${HELM_CHART_REPO}/dispatches" \
--header "Accept: application/vnd.github.v3+json" \
--header "authorization: token ${GITHUB_API_TOKEN}" \
--header "Content-Type: application/json" \
--data-raw " { \
    \"event_type\": \"increase-chart-version\", \
    \"client_payload\": { \
        \"chart_name\": \"${CHART_NAME}\", \
        \"app_version\": \"${APP_VERSION}\", \
        \"update_dev\": \"${UPDATE_DEV}\" \
    } \
}"
