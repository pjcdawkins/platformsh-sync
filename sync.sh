#!/bin/bash
set -e

YES=0

## Set up options
while getopts "y" opt; do
    case "$opt" in
    y)  YES=1
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

REMOTE_ALIAS_NAME=${1:-'production'}
LOCAL_ALIAS_NAME=${2:-'_local'}
##

if PROJECT_TITLE=$(platform project:metadata title); then
	PROJECT_ID=$(platform project:metadata id)
	echo "Site: ${PROJECT_TITLE} (${PROJECT_ID})"
else
	echo "Project not found. Go to a project directory"
	exit 1
fi

ALIAS_GROUP="$(platform drush-aliases -g)"
if [ ! $? = 0 ]; then
	echo "Failed to get Drush alias group"
	exit 1
fi

LOCAL_ALIAS="@${ALIAS_GROUP}.${LOCAL_ALIAS_NAME}"
REMOTE_ALIAS="@${ALIAS_GROUP}.${REMOTE_ALIAS_NAME}"

for TEST in "$LOCAL_ALIAS" "$REMOTE_ALIAS"; do
	if ! drush site-alias "$TEST" --format=list > /dev/null 2>&1; then
		echo "Alias not found: $TEST"
		exit 1
	fi
done

if [ ! "$YES" = 1 ]; then
	read -p "Are you sure you want to sync from ${REMOTE_ALIAS} to ${LOCAL_ALIAS}? [y/N] " -r
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1;
	fi
else
	echo "Syncing from ${REMOTE_ALIAS} to ${LOCAL_ALIAS}"
fi

echo "Rebuilding site"
platform build

echo "Dropping local database tables, before syncing"
drush $LOCAL_ALIAS sql-drop -y

echo "Syncing database from remote"
drush sql-sync $REMOTE_ALIAS $LOCAL_ALIAS -y

# This is here in case the production site uses Redis caching.
echo "Clearing DB caches"
for TABLE in cache cache_bootstrap cache_field cache_rules; do
  drush $LOCAL_ALIAS sqlq "TRUNCATE TABLE $TABLE" || true
done

drush $LOCAL_ALIAS cc drush

echo "Running DB updates"
drush $LOCAL_ALIAS updb -y

echo "Sanitizing database"
drush $LOCAL_ALIAS sql-sanitize -y

echo "Reverting features (?)"
drush $LOCAL_ALIAS fra

echo "Clearing the cache again, just to be sure"
drush $LOCAL_ALIAS cc all
