#!/bin/bash
TOMCAT_VERSION=/opt/OpenIAM/tomcat
DEPLOY_DIRECTORY=/tmp/deploy
TARGET_DIRECTORY=/opt/OpenIAM/tomcat/webapps
APP_ROOT=/opt/OpenIAM/autodeploy
BACKUP=/opt/OpenIAM/autodeploy/backup
APPS=idp:openiam-ui-static:selfservice:webconsole:webconsole-idm:webconsole-am:reportviewer:selfservice-ext
MNGUSER=tomcat
MNGPASSWD=tomcat
APPID=tomcatdeploy
DEPLOY_TIMEOUT=5 ## minutes
STOP_TIMEOUT=12  ## *5 seconds
START_TIMEOUT=12 ## *5 seconds
TOMCAT_PORT=8080
MANAGER_URL=http://localhost:$TOMCAT_PORT/manager/html
DEPLOY_WAIT=300
TOMCAT_LOG=$TOMCAT_VERSION/logs/catalina.out
LOG=$APP_ROOT/deploy.log
#LOG=/dev/stdout

echo >>$LOG
echo `date +"%b %d %T"`" "`hostname`" $APPID: Starting deployment">>$LOG

function remove_pid
{
if [ -f $APP_ROOT/$APPID.pid ]; then
  echo `date +"%b %d %T"`" "`hostname`" $APPID: Removing PID">>$LOG
  rm -f $APP_ROOT/$APPID.pid
fi
}

function stop_tomcat
{
echo `date +"%b %d %T"`" "`hostname`" $APPID: Trying to stop tomcat services...!!">>$LOG
cd $TOMCAT_VERSION/bin
./shutdown.sh 2>&1>>/dev/null
i=0
while [ $(ps -ef | grep -i catalina.startup.Bootstrap| grep -v grep|wc -l) -ne 0 ]
 do
  if [ $i -eq $STOP_TIMEOUT ]; then
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Tomcat didnt stop after 60 seconds...Exiting">>$LOG
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
    exit
  else 
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Waiting 5 seconds for Tomcat Shutdown">>$LOG
    sleep 5
    i=`expr $i + 1`
  fi 
 done
echo `date +"%b %d %T"`" "`hostname`" $APPID: Tomcat services stopped.">>$LOG
}

function is_running 
{
if [ -f $APP_ROOT/$APPID.pid ]; then
   echo `date +"%b %d %T"`" "`hostname`" $APPID: File $APP_ROOT/$APPID.pid exists">>$LOG
   echo `date +"%b %d %T"`" "`hostname`" $APPID: A deploymet process is already running of was killed abruptly. Kindly check!!!">>$LOG
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
   exit
else
   echo `date +"%b %d %T"`" "`hostname`" $APPID: No deploymnet job running...Continuing">>$LOG
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Creating Pid file">>$LOG
   touch $APP_ROOT/$APPID.pid 2>&1>>$LOG
   if [ -f $APP_ROOT/$APPID.pid ]; then
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Pid file createde">>$LOG
   else
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Error creating Pid file...Exiting..!!">>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
      exit
   fi
fi
}

function do_deploy
{
if [ -f $DEPLOY_DIRECTORY/dodeploy ]; then
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Dodeploy flag set..removing it and continuing deployment">>$LOG
   echo -n `date +"%b %d %T"`" "`hostname`" $APPID: ">>$LOG;rm -v --interactive=never $DEPLOY_DIRECTORY/dodeploy 2>&1>>$LOG
   if [ $? -ne 0 ];then
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Error removing deploy flag..exiting">>$LOG
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
    exit
   fi
else
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Dodeploy flag not set...exiting without any deployment">>$LOG
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
     echo `date +"%b %d %T"`" "`hostname`" $APPID: Backing up file " $TARGET_DIRECTORY/$file " as " $BACKUP/$file.bak>>$LOG
     if [ -f $BACKUP/$file.bak ]; then
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Archiving backup file " $BACKUP/$file.bak " as " $BACKUP/$file.$(date +"%d%b%T")
      echo -n `date +"%b %d %T"`" "`hostname`" $APPID: ">>$LOG;cp -pv $BACKUP/$file.bak $BACKUP/$file.$(date +"%d%b%T")>>$LOG
      echo -n `date +"%b %d %T"`" "`hostname`" $APPID: ">>$LOG;cp -pv $TARGET_DIRECTORY/$file $BACKUP/$file.bak>>$LOG
     else
      echo -n `date +"%b %d %T"`" "`hostname`" $APPID: ">>$LOG;cp -pv $TARGET_DIRECTORY/$file $BACKUP/$file.bak>>$LOG
     fi
     if [ -f $BACKUP/$file.bak ]; then
      echo `date +"%b %d %T"`" "`hostname`" $APPID: File " $file " successfully backed up">>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Cleaning files realted to application "$file>>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Removing file "$file;rm -rf --interactive=never $TARGET_DIRECTORY/$file 2>&1>>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Removing folder "$folder;rm -rf --interactive=never $TARGET_DIRECTORY/$folder 2>&1>>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Copying new files for application "$file>>$LOG
      echo -n `date +"%b %d %T"`" "`hostname`" $APPID: ">>$LOG;cp -pv $DEPLOY_DIRECTORY/$file $TARGET_DIRECTORY>>$LOG
      if [ -f $TARGET_DIRECTORY/$file ];then
	echo `date +"%b %d %T"`" "`hostname`" $APPID: Application "$file" successfully copied">>$LOG
      else
	echo `date +"%b %d %T"`" "`hostname`" $APPID: failed to copy application "$file" ...Exiting">>$LOG
        echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
        exit
      fi
     else
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Failed to backup file " $file " Exiting">>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
      exit
     fi
  else
     echo `date +"%b %d %T"`" "`hostname`" $APPID: File " $file " doesnot exist in the target. Skipping backup">>$LOG
  fi
 done
}

function check_deployments
{
echo `date +"%b %d %T"`" "`hostname`" $APPID: Checking appp deployment status">>$LOG
apps=$(echo $APPS | tr ":" "\n")
j=0
retry=true
while $retry 
do
retry=false
  if [ $j -eq $DEPLOY_TIMEOUT ]; then
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Apps didnot deploy after 5 minutes...Exiting...!">>$LOG
      echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
      exit
  else
      j=`expr $j + 1`
  fi
  manager=$(curl --connect-timeout 10 -m 60 -u $MNGUSER:$MNGPASSWD $MANAGER_URL 2>/dev/null)
  for app  in $apps; 
    do 
      if [ $(echo "$manager"| grep -w "/$app</a>"|wc -l) -eq 1 ]; then
         echo `date +"%b %d %T"`" "`hostname`" $APPID: Application "$app" deployed">>$LOG
      else
         retry=true
         echo `date +"%b %d %T"`" "`hostname`" $APPID: Application "$app" not deployed.">>$LOG
         echo `date +"%b %d %T"`" "`hostname`" $APPID: Checking after 60 Seconds ">>$LOG
         sleep 60
         break
      fi
   done
done
remove_pid
echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Successfull">>$LOG
}

function start_tomcat
{
unset DISPLAY
echo `date +"%b %d %T"`" "`hostname`" $APPID: Trying to start tomcat services...!!">>$LOG
k=0
x=$(echo -n "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/$TOMCAT_PORT' > /dev/null 2>&1")
eval $x
if [ $? -eq 0 ]; then
echo `date +"%b %d %T"`" "`hostname`" $APPID: Port $TOMCAT_PORT is active..Not attempting tomcat start...Exiting">>$LOG
echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
exit
else
cd $TOMCAT_VERSION/bin
./startup.sh 2>&1>>/dev/null
fi
while [ a=$(eval $x) -a $? -ne 0 ];
do
  if [ $k -eq $START_TIMEOUT ]; then
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Tomcat didnt start after 60 seconds...Exiting">>$LOG
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment Failed">>$LOG
    exit
  else
    echo `date +"%b %d %T"`" "`hostname`" $APPID: Waiting 5 seconds for Tomcat Startup">>$LOG
    sleep 5
    k=`expr $k + 1`
  fi
done
echo `date +"%b %d %T"`" "`hostname`" $APPID: Port $TOMCAT_PORT is now active">>$LOG
}

function wait_for_deployment
{
echo 0 > flag
echo `date +"%b %d %T"`" "`hostname`" $APPID: Waiting max "$DEPLOY_WAIT" seconds for Tomcat to deploy apps and start">>$LOG
timeout  $DEPLOY_WAIT tail -n0 -F $TOMCAT_LOG | while read LOGLINE
do
   [[ "${LOGLINE}" == *"INFO: Server startup in"* ]]  && echo 1 > flag && pkill -P $$ timeout
done
x=$(cat flag)
if [ $x -eq 0 ]; then
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Tomcat deployment didn't complete after "$DEPLOY_WAIT" seconds...exiting">>$LOG
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment failed">>$LOG
   exit
elif [ $x -eq 1 ]; then
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Tomcat service started">>$LOG 
else
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Unexpected retunr from timeout...Exiting">>$LOG
   echo `date +"%b %d %T"`" "`hostname`" $APPID: Deployment failed">>$LOG
   exit
fi
echo 0 > flag
}

is_running
do_deploy
stop_tomcat
sync_files
start_tomcat
wait_for_deployment
check_deployments
