A script to sync a Drupal site from production to local

Uses the Platform.sh CLI to get site details, and to ensure the site is built locally before sync.

Usage:

```bash
# Inside a Platform.sh CLI project directory
/path/to/sync.sh [remote-alias-name] [local-alias-name]
```

An "alias name" is the part after the `.` in a Drush alias. The remote alias name defaults to `production` and the local alias name defaults to `_local`.

Among other things, the script runs the equivalent of:

```bash
drush sql-sync @$(platform drush-aliases --pipe).production @$(platform drush-aliases --pipe)._local
```

(that `platform drush-aliases --pipe` command gets the Drush "alias group" for the current project)

