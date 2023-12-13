#!/bin/bash
VERSION="1.0.0"

#helper function to print usage information
usage () {
  cat << "EOF"

waitForJobs.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Waits for the specified set of SGE jobs to complete
Usage: waitForJobs.sh [-v|--verbose] [-i|--interval <SECONDS>]
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

#check if SGE is installed
SGE_PATH=$(which qstat)
if [ -x "$SGE_PATH" ] ; then
  echo "SGE detected at: $SGE_PATH"
else
  >&2 echo "#########################################"
  >&2 echo "ERROR: SGE appears to not be installed!"
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
    --version)
      echo "waitForJobs.sh :: clusterutil v${VERSION}"
      exit 0
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

#the number of currently active jobs (with 1 pseudo-job to begin with)
CURRJOBNUM=1
CYCLE=0
while (( $CURRJOBNUM > 0 )); do
  #wait for time interval
  sleep $INTERVAL

  # query job information and store in temp file (in case we want more info later)
  qstat -u $USER|tail -n+3>$TMPFILE

  #Update the list of active jobs
  if [[ -n "$JOBS" ]]; then
    #ACTIVEJOBS is a newline-separated list of active job ids
    #if JOBS input list was specified, we use it to filter the output
    ACTIVEJOBS=$(awk '{print $1}' "$TMPFILE"|grep -P "${JOBS//,/|}")
  else 
    ACTIVEJOBS=$(awk '{print $1}' "$TMPFILE")
  fi
  #count number of jobs
  if [[ -z "$ACTIVEJOBS" ]]; then
    #when the list is empty, echo still returns a newline character which wc would count as 1 line
    CURRJOBNUM=0
  else
    CURRJOBNUM=$(echo "$ACTIVEJOBS"|wc -l)
  fi

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
rm $TMPFILE 

if [[ $VERBOSE == 1 ]]; then
  printf "\r$(date) INFO: Done!              \n"
fi
