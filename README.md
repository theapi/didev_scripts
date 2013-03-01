didev_scripts
=============

Create symlinks to these scripts in /home/vagrant/bin/ so they are included in the path.

didev_db.sh Gets the db for the requested site with options to not run drush updb, not run any drush commands and whether to get the migration database.
didev_db.sh --migration --noupdate --nodrush dennis
