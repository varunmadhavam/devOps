################### port check script ##########
################### vm cdc basis ###############
############ shell bash os linux ###############
##usage ./vmping host port timeout count #######
#!/bin/bash
intcheck=0 ## flag for integer check on port count and timeout.
ipcheck=1  ## flag for ip address syntax check.

arg1=$1 ## argument 1 ip address ####
arg2=$2 ## argument 2 port         ####
arg3=$3 ## argument 3 timeout        #### making the arguments global[not needed...done for documentaion sake].
arg4=$4 ## argument 4 count        ####
                                 ####
intcheck() ## function to validate whether port timeout and count entered are integer or not.
{
echo $arg2 |egrep -qxe '[0-9]+' ## check whether port is an integer
if [ $? -ne 0 ];then ## if no
intcheck=1 ## set flag
fi
echo $arg3 |egrep -qxe '[0-9]+' ## check whether timeout is an integer
if [ $? -ne 0 ];then ## if no
intcheck=1 ## set flag
fi
echo $arg4 |egrep -qxe '[0-9]+' ## check whether count is an integer
if [ $? -ne 0 ];then ## if no
intcheck=1 ## set flag
fi
}
ipcheck()
{
echo $arg1 | egrep -qxe '((25[0-5]|2[0-4][0-9]|[1]?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|[1]?[0-9]?[0-9])' ## regular expression for valid ip address
if [ $? -ne 0 ];then ## if address not valid
ipcheck=0 ## set flag
fi
}
intcheck ## validate port timeout and count
ipcheck ## validate ip address
if [ $# -ne 4 ] ## if parameters less than four exit
then
echo -e "  \033[31mInvalid Parameters\033[0m"
echo -e "  \033[31mUsage : $0 ip port timeout count\033[0m"
exit 0
elif [ "$ipcheck" != "1" ] ## if invalid ip address exit
then
echo -e "  \033[31mInvalid Parameters\033[0m"
echo -e "  \033[31mInvalid IP Address\033[0m"
echo -e "  \033[31mUsage : $0 ip port timeout count\033[0m"
exit 0
elif [ $intcheck -eq 1 ] ## if any one of port timeout count not an integer exit
then
echo -e "  \033[31mInvalid Parameters\033[0m"
echo -e "  \033[31mPort|timeout|count has to be an integer\033[0m"
echo -e "  \033[31mUsage : $0 ip port timeout count\033[0m"
exit 0
else
x=$(echo -n "timeout $3 bash -c 'cat < /dev/null > /dev/tcp/$1/$2' > /dev/null 2>&1") ## /dev/tcp is a virtual device provided by bash
count=1                                                                               ## it can be only used for redirections. it opens
while [ $count -le $4 ] ##execute the port check count times                          ## a tcp connection to the specified ip and port.
do
START=($(date +%s%N)/1000000) ## get beginig  time
eval $x ## execute the /dev/tcp command
r=$? ## store return value
END=($(date +%s%N)/1000000) ## get ending time.
DIFF=$(( $END - $START )) ## difference equals approx execution time.
if [ $r -ne 0 ]; then ## return of /dev/tcp 0 when success
  echo -e "Connection to \033[34m$1\033[0m on port \033[33m$2\033[0m \033[31mfailed\033[0m"
else
  echo -e "Connection to \033[34m$1\033[0m on port \033[33m$2\033[0m \033[32msucceeded\033[0m : \033[36m$DIFF\033[0m ms"
fi
count=$((count+1)) ## increment count
if [ $count -le $4 ]; then ## avoid delay after last step
sleep 1
fi
done
fi
