#!/bin/bash
# This script downloads the specified site DB


DBTYPE='auth'
UPDB=1
DO_DRUSH=1


function dbimport(){
  # Check and import the database
  echo [INFO] Copying DB from NFS

  if [ $DBTYPE = 'migration' ] 
  then
    [ ! -f  "/mnt/nfs/Drupal/sql/${SITE}-migration.sql.gz" ]  && echo ERROR: ${SITE} migration DB does not exist on NFS && exit 1
    echo [INFO] MIGRATION: migration database found: /mnt/nfs/Drupal/sql/${SITE}-migration.sql.gz
	  cp /mnt/nfs/Drupal/sql/${SITE}-migration.sql.gz /tmp/${SITE}.sql.gz && gunzip -f /tmp/${SITE}.sql.gz
  else
	  [ ! -f  "/mnt/nfs/Drupal/sql/${SITE}-latest.sql.gz" ] && echo ERROR: ${SITE} DB does not exist on NFS && exit 1
    echo [INFO] /mnt/nfs/Drupal/sql/${SITE}-latest.sql.gz
	  cp /mnt/nfs/Drupal/sql/${SITE}-latest.sql.gz /tmp/${SITE}.sql.gz && gunzip -f /tmp/${SITE}.sql.gz
  fi

  mysql -u root -e 'DROP DATABASE IF EXISTS drupal_distro_'${SITE}''
  mysql -u root -e 'CREATE DATABASE drupal_distro_'${SITE}''
  echo [INFO] Importing DB

  pv /tmp/${SITE}.sql | mysql -uroot drupal_distro_${SITE}

  mysql -u root drupal_distro_${SITE} -e 'update system set filename = replace(filename, "'${SITE}'.co.uk", "'${SITE}'.vm.didev.co.uk");'
  mysql -u root drupal_distro_${SITE} -e 'update system set filename = replace(filename, "auth.'${SITE}'.co.uk", "'${SITE}'.vm.didev.co.uk");'
  mysql -u root drupal_distro_${SITE} -e 'update system set filename = replace(filename, "auth'${SITE}'.didev.co.uk", "'${SITE}'.vm.didev.co.uk");'
  mysql -u root drupal_distro_${SITE} -e 'update registry set filename = replace(filename, "'${SITE}'.co.uk", "'${SITE}'.vm.didev.co.uk");'
  mysql -u root drupal_distro_${SITE} -e 'update registry_file set filename = replace(filename, "'${SITE}'.co.uk", "'${SITE}'.vm.didev.co.uk");'
  mysql -u root drupal_distro_${SITE} -e 'show tables like "cache%"' | grep -v '\-\-\-' | grep -v 'Tables_in' | xargs -Iarg mysql -u root drupal_distro_${SITE} -e'TRUNCATE TABLE arg'

  rm /tmp/${SITE}.sql
  echo [INFO] Done Importing DB
}

function admin(){
  # Update admin account password and clear cache
  echo [INFO] Updating 'admin' password 
  mysql -u root drupal_distro_${SITE} -e 'UPDATE  `users` SET  `pass` = "$S$C7EvohNxjX7Oac64a7EI5Sd6.isioQxIbu4KvpFbUUHgyCKs0SFg" WHERE  `users`.`uid` =1 LIMIT 1;'

}


function drush(){
  cd ${SITEDIR}
  echo Clearing cache and settings drush options...
  /usr/local/bin/drush rr
  echo [INFO] Set dev varnish server details
  /usr/local/bin/drush -y vset varnish_control_terminal "127.0.0.1:6082"
  echo [INFO] Set solr details
  /usr/local/bin/drush -y solr-set-env-url "http://localhost:8080/solr3/solr3"
  /usr/local/bin/drush -y solr-variable-set apachesolr_read_only "1"

  echo [INFO] Set file_public_path
  /usr/local/bin/drush -y vset file_public_path "sites/$SITE/files"
  
  echo [INFO] Disable drupal modules: cdn, varnish
  /usr/local/bin/drush -y dis cdn
  /usr/local/bin/drush -y dis varnish
  
  echo [INFO] Disable CSS/JS Aggregation
  /usr/local/bin/drush -y vset preprocess_css 0
  /usr/local/bin/drush -y vset preprocess_js 0

  echo [INFO] Disable Google Analytics
  /usr/local/bin/drush -y vset googleanalytics-account ''
  
  if [ $UPDB = 1 ] 
  then
    updb
  fi

  echo [INFO] Cache Clear All
  /usr/local/bin/drush cc all
  echo
  echo
  echo Site should now be viewable at: http://${SITE}.vm.didev.co.uk
  echo Username: admin
  echo Password: dennis3
  echo
  echo DONE
  echo
}

function updb() {
  if [ $UPDB = 1 ] 
  then
    echo [INFO] Apply Database Updates
    cd ${SITEDIR}
    /usr/local/bin/drush -y updatedb
  fi
}


#http://www.linuxcommand.org/wss0130.php

function usage
{
  echo "usage: didev_db.sh [-m (--migration)] [-nu (--noupdate)] [-nd (--nodrush)] site | [-h (--help)]]"
}

function error_site
{
  echo [ERROR] Please enter site name! e.g. didev_db.sh dennis && exit 1
}

function require_site_dir_exists {
  if [ ! -d $SITEDIR ] 
  then
    echo ERROR: $SITEDIR does not exist.
    exit
  fi
}

function set_vars
{
  SITEREPO="/vagrant/repos/${SITE}/"
  SITEDIR="/vagrant/repos/dennis_distro_7/sites/${SITE}.vm.didev.co.uk/"
  FILES="${SITEDIR}/files"
}

function run 
{
  [ -z $SITE ] && error_site
  echo Run with: $DBTYPE, UPDB=$UPDB, DO_DRUSH=$DO_DRUSH for $SITE
  
  ## Actually run the functions
  
  if [ $DO_DRUSH = 1 ] 
  then
    require_site_dir_exists
  fi
  
  if [ $UPDB = 1 ] 
  then
    require_site_dir_exists
  fi
  
  dbimport
  admin

  if [ $DO_DRUSH = 1 ] 
  then
    drush
  else
    updb
  fi
}


# Get the aruments & options, then run
while [ "$1" != "" ]; do
    case $1 in
        -m | --migration ) DBTYPE='migration'
                           ;;
        -nu | --noupdate ) UPDB=0
                           ;;
        -nd | --nodrush )  DO_DRUSH=0
                           ;;
        -h | --help )      usage
                           exit
                           ;;
                                
        * ) param=$1
            if [ ${param:0:1} = '-' ] 
            then
              echo Unknown param $param
            else
              SITE=$1
              set_vars
              run
              exit
            fi
    esac
    shift
done
error_site
