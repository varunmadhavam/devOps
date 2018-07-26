#!/bin/bash
TOMCAT_VERSION=/opt/OpenIAM/tomcat
DEPLOY_DIRECTORY=/tmp/deploy
TARGET_DIRECTORY=/opt/OpenIAM/tomcat/webapps
APP_ROOT=/opt/OpenIAM/autodeploy
BACKUP=/opt/OpenIAM/autodeploy/backup
APPS=idp:openiam-ui-static:selfservice:webconsole:webconsole-idm:webconsole-am:reportviewer:selfservice-ext
#LOG=$APP_ROOT/deploy.log
LOG=/dev/stdout

echo >>$LOG
echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: Starting deployment">>$LOG

function remove_pid
{
if [ -f $APP_ROOT/deploy.pid ]; then
  echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Removinf PID">>$LOG
  rm -f $APP_ROOT/deploy.pid
fi
}

function stop_tomcat
{
echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Trying to stop tomcat services...!!">>$LOG
cd $TOMCAT_VERSION/bin
#./shutdown.sh 2>&1>>$LOG
i=1
while [ $(ps -ef | grep -i catalina.startup.Bootstrap| grep -v grep|wc -l) -ne 0 ]
 do
  if [ $i -eq 13 ]; then
    echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Tomcat didnt stop after 60 seconds...Exiting">>$LOG
    exit
  else
    echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Waiting 5 seconds for Tomcat Shutdown">>$LOG
    sleep 5
    i=`expr $i + 1`
  fi
 done
}

function is_running
{
if [ -f $APP_ROOT/deploy.pid ]; then
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: File $APP_ROOT/deploy.pid exists">>$LOG
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: A deploymet process is already running of was killed abruptly. Kindly check!!!">>$LOG
   exit
else
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: No deploymnet job running...Continuing">>$LOG
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Creating Pid file">>$LOG
   touch $APP_ROOT/deploy.pid 2>&1>>$LOG
   if [ -f $APP_ROOT/deploy.pid ]; then
      echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Pid file createde">>$LOG
   else
      echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Error creating Pid file...Exiting..!!">>$LOG
      exit
   fi
fi
}

function do_deploy
{
if [ -f $DEPLOY_DIRECTORY/dodeploy ]; then
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Dodeploy flag set..removing it and continuing deployment">>$LOG
   echo -n `date +"%b %d %T"` " "`hostname`" tomcatdeploy: ";rm -v --interactive=never $DEPLOY_DIRECTORY/dodeploy 2>&1>>$LOG
   if [ $? -ne 0 ];then
    echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Error removing deploy flag..exiting">>$LOG
    exit
   fi
else
   echo `date +"%b %d %T"` " "`hostname`" tomcatdeploy: Dodeploy flag not set...exiting without any deployment">>$LOG
   remove_pid
   exit
fi
}

function sync_files
{
for x in $(find $DEPLOY_DIRECTORY -type f -name "*.war");
 do
  file=`basename $x`
  folder=${file%.*}
  if [ -f $TARGET_DIRECTORY/$file ]; then
     echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: Backing up file " $TARGET_DIRECTORY/$file " as " $BACKUP/$file.bak>>$LOG
     if [ -f $BACKUP/$file.bak ]; then
      echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: Archiving backup file " $BACKUP/$file.bak " as " $BACKUP/$file.$(date +"%d%b%T")
      echo -n `date +"%b %d %T"`" "`hostname`" tomcatdeploy: ";cp -pv $BACKUP/$file.bak $BACKUP/$file.$(date +"%d%b%T")>>$LOG
      echo -n `date +"%b %d %T"`" "`hostname`" tomcatdeploy: ";cp -pv $TARGET_DIRECTORY/$file $BACKUP/$file.bak>>$LOG
     else
      echo -n `date +"%b %d %T"`" "`hostname`" tomcatdeploy: ";cp -pv $TARGET_DIRECTORY/$file $BACKUP/$file.bak>>$LOG
     fi
     if [ -f $BACKUP/$file.bak ]; then
      echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: File " $file " successfully backed up">>$LOG
     else
      echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: Failed to backup file " $file " Exiting">>$LOG
      exit
     fi
  else
     echo `date +"%b %d %T"`" "`hostname`" tomcatdeploy: File " $file " doesnot exist in the target. Skipping backup">>$LOG
  fi
 done
}

function check_deployments
{
manager=$(curl -u tomcat:tomcat http://10.72.21.180:8080/manager/html 2>/dev/null)
apps=$(echo $APPS | tr ":" "\n")
for app  in $apps;
do
  echo "$manager"| grep -w "/$app</a>"
 done

}

#is_running
#do_deploy
#stop_tomcat
#sync_files
check_deployments
