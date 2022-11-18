#!/bin/bash

#helper function to print usage information
usage () {
  cat << "EOF"

waitForJobs.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Waits for the specified set of PBS jobs to complete
Usage: pacbioCCS.sh [-v|--verbose] [-i|--interval <SECONDS>]
    [-h|--help] [--] [<JOBS>]

-v|--verbose  : Print number of remaining jobs every interval.
-h|--help     : Show this help message.
-i|--interval : Time interval between checks in seconds. (Default 5)
<JOBS>        : comma-separated list of job IDs. For example 12345,12346

Tip: To capture the job ID of a job submission you can use:
RETVAL=$(submitjob.sh myJob.sh)
JOBID=${RETVAL##* }

EOF
 exit $1
}

#check if PBS is installed
PBS_PATH=$(which qstat)
if [ -x "$PBS_PATH" ] ; then
  echo "PBS detected at: $PBS_PATH"
else
  >&2 echo "#########################################"
  >&2 echo "ERROR: PBS appears to not be installed!"
  >&2 echo "#########################################"
  usage 1
fi

#Default parameter values
VERBOSE=0
INTERVAL=5

PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage 0
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -i|--interval)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        INTERVAL=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    --) # end of options indicates that the main command follows
      shift
      PARAMS="$PARAMS $@"
      eval set -- ""
      ;;
    -*|--*=) # unsupported flags
      echo "ERROR: Unsupported flag $1" >&2
      usage 1
      ;;
    *) # positional parameter
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
#reset command arguments as only positional parameters
eval set -- "$PARAMS"

#first argument should be a comma-separated list of job ids.
JOBS=$1

#Validate parameters
if [[ $INTERVAL < 1 ]]; then
  >&2 echo "#########################################"
  >&2 echo "ERROR: Interval length must be at least 1"
  >&2 echo "#########################################"
  usage 1
fi

if [[ $VERBOSE == 1 ]]; then
  echo "$(date) INFO: Waiting for jobs to finish..."
fi
#print extra newline to make room for job counter
echo ""

#create temporary file for squeue output
TMPFILE=$(mktemp)
TMPERRFILE=$(mktemp)

TMPACTIVE=$(mktemp)

ACTIVEJOBS=${JOBS//,/ }
echo "${ACTIVEJOBS// /$'\n'}">$TMPACTIVE

#the number of currently active jobs (with 1 pseudo-job to begin with)
CURRJOBNUM=1
CYCLE=0
while (( $CURRJOBNUM > 0 )); do
  #wait for time interval
  sleep $INTERVAL

  # query job information
  if [ -z "$JOBS" ]; then
    qstat -u $USER|tail -n+6>$TMPFILE
  else
    #redirect stdout and stderror into different pipes to record statuses and errors
    { qstat -u $USER ${ACTIVEJOBS}|tail -n+6>"$TMPFILE" ; } 2>&1 | grep "Unknown Job Id">"$TMPERRFILE"
    # Completed jobs disappear from the PBS database after a while and will cause errors if queried.
    # So they need to be removed from the $ACTIVEJOBS list to prevent cascading errors.
    #extract list of completed jobs from qstat output
    COMPLETED=$(cat $TMPFILE|awk '{if ($10=="C"){print $1}}')
    #check if any errors regarding unrecognized job IDs occurred
    if (( $(cat $TMPERRFILE|wc -l) > 0 )); then
      #if so, extract the missing job IDs and add them to the 'completed' list
      MISSING=$(awk 'NF>1{print $NF}' "$TMPERRFILE"|sort|uniq)
      COMPLETED=$(printf "$COMPLETED\n$MISSING"|sort|uniq)
      printf "\nDropping missing jobs: ${MISSING//$'\n'/, }\n" >&2
    fi
    #if the completed list is not empty...
    if (( $(echo "$COMPLETED"|wc -l) > 0 )); then
      #remove them from the active jobs list
      ACTIVEJOBS=$(grep -vP "${COMPLETED//$'\n'/|}" $TMPACTIVE)
      #make sure to re-convert newlines into spaces on the active list
      ACTIVEJOBS=${ACTIVEJOBS//$'\n'/ }
      #and also update the temporary file
      echo "${ACTIVEJOBS// /$'\n'}">$TMPACTIVE
    fi
    # ACTIVEJOBS=$(echo $ACTIVEJOBS|sed "s/${MISSING//$'\n'/[,]*\|}//g"|sed 's/^[,]*\|[,]*$//')

    # #clear the tempfile since we have to iteratively append below
    # rm "$TMPFILE"
    # #qstat can't deal with too many job ids at once, so we need to break it into smaller requests
    # JOBARRAY=(${JOBS//,/ })
    # for (( i = 0; i < ${#JOBARRAY[@]}; i+=10 )); do
    #   qstat "${JOBARRAY[@]:$i:10}"|tail -n+6>>$TMPFILE
    # done
  fi

  #count number of jobs
  CURRJOBNUM=$(cat $TMPFILE|awk '{if ($10!="C"){print $1}}'|wc -l)

  # #check if any are stuck ('held') and release if necessary
  # # STUCK=$(cat $TMPFILE|grep 'launch failed requeued held'|tr -s ' ' '\t'|cut -f 1|tr '\n' ',')
  # STUCK=$(grep 'launch failed requeued held' $TMPFILE|awk '{print $1}'|tr '\n' ',')
  # if ! [[ -z "$STUCK" ]]; then
  #   if [[ $VERBOSE == 1 ]]; then
  #     printf "\r$(date) WARNING: Failed/Held jobs detected! Attempting to release...\n"
  #   fi
  #   scontrol release "$STUCK"
  # fi

  # #check if any are suspended and requeue if necessary
  # SUSPENDED=$(awk '{if ($3 =="S"){print $1}}' $TMPFILE|tr '\n' ',')
  #  if ! [[ -z "$SUSPENDED" ]]; then
  #   if [[ $VERBOSE == 1 ]]; then
  #     printf "\r$(date) WARNING: Suspended jobs detected! Requeuing...\n"
  #   fi
  #   scontrol requeue "$SUSPENDED"
  # fi

  #Print status update (if verbose)
  if [[ $VERBOSE == 1 ]]; then
    printf "\r$CURRJOBNUM jobs remaining "
    #draw waiting animation
    CYCLE=$(( ($CYCLE+1) % 4))
    case $(($CYCLE % 4)) in
      0) printf "\u2514   ";;
      1) printf "\u250C   ";;
      2) printf "\u2510   ";;
      3) printf "\u2518   ";;
    esac
  fi

done

#clean up
rm $TMPFILE $TMPERRFILE $TMPACTIVE

if [[ $VERBOSE == 1 ]]; then
  printf "\r$(date) INFO: Done!              \n"
fi

# Job status codes:  
# C -     Job is completed after having run/
# E -  Job is exiting after having run.
# H -  Job is held.
# Q -  job is queued, eligible to run or routed.
# R -  job is running.
# T -  job is being moved to new location.
# W -  job is waiting for its execution time
#     (-a option) to be reached.
# S -  (Unicos only) job is suspend.
