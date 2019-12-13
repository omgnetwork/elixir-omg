#!/bin/sh

set -e

echo_info() {
    printf "\\033[0;34m%s\\033[0;0m\\n" "$1"
}

echo_warn() {
    printf "\\033[0;33m%s\\033[0;0m\\n" "$1"
}


## Sanity check
##

if [ -z "$CIRCLE_GPG_KEY" ] ||
       [ -z "$CIRCLE_GPG_OWNERTRUST" ] ||
       [ -z "$GCP_KEY_FILE" ] ||
       [ -z "$GCP_ACCOUNT_ID" ] ||
       [ -z "$GCP_ZONE" ]; then
    echo_warn "Deploy credentials not present, skipping deploy."
    exit 0
fi


## GPG
##

GPGFILE=$(mktemp)
trap 'rm -f $GPGFILE' 0 1 2 3 6 14 15
echo "$CIRCLE_GPG_KEY" | base64 -d | gunzip > "$GPGFILE"
gpg --import "$GPGFILE"
printf "%s\\n" "$CIRCLE_GPG_OWNERTRUST" | gpg --import-ownertrust


## GCP
##

GCPFILE=$(mktemp)
trap 'rm -f $GCPFILE' 0 1 2 3 6 14 15
echo "$GCP_KEY_FILE" | base64 -d > "$GCPFILE"

gcloud auth activate-service-account --key-file="$GCPFILE"
gcloud beta container clusters get-credentials ${GCP_CLUSTER_DEVELOPMENT} --region ${GCP_REGION} --project ${GCP_PROJECT}
image_tag="$(printf "%s" "$CIRCLE_SHA1" | head -c 7)"

if [ "$DEPLOY" = "watcher" ]; then
    kubectl set image statefulset watcher watcher=omisego/watcher:${image_tag}
    while true; do if [ "$(kubectl get pods watcher-0 -o jsonpath=\"{.status.phase}\" | grep Running)" ]; then break; fi; done
elif [ "$DEPLOY" = "watcher_info" ]; then
    kubectl set image statefulset watcher-info watcher_info=omisego/watcher_info:${image_tag}
    while true; do if [ "$(kubectl get pods watcher-info-0 -o jsonpath=\"{.status.phase}\" | grep Running)" ]; then break; fi; done
else
    kubectl set image statefulset childchain childchain=omisego/child_chain:${image_tag}
    while true; do if [ "$(kubectl get pods childchain-0 -o jsonpath=\"{.status.phase}\" | grep Running)" ]; then break; fi; done
fi;
