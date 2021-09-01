#!/bin/bash

#helper function to print usage information
usage () {
  cat << EOF

waitForJobs.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Waits for the specified set of slurm jobs to complete
Usage: pacbioCCS.sh [-v|--verbose] [-i|--interval <SECONDS>]
    [-h|--help] [--] [<JOBS>]

-v|--verbose  : Print number of remaining jobs every interval.
-h|--help     : Show this help message.
-i|--interval : Time interval between checks in seconds. 
<JOBS>        : comma-separated list of job IDs. For example 12345,12346

EOF
 exit $1
}

#check if slurm is installed
SLURM_PATH=$(which sbatch)
if [ -x "$SLURM_PATH" ] ; then
  echo "Slurm detected at: $SLURM_PATH"
else
  >&2 echo "#########################################"
  >&2 echo "ERROR: Slurm appears to not be installed!"
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
  echo "Waiting for jobs to finish..."
fi

#the number of currently active jobs (with 1 pseudo-job to begin with)
CURRJOBNUM=1
while (( $CURRJOBNUM > 0 )); do
  sleep $INTERVAL
  if [ -z "$JOBS" ]; then
    CURRJOBNUM=$(squeue -hu $USER|wc -l)
  else
    CURRJOBNUM=$(squeue -hu $USER -j${JOBS}|wc -l)
  fi

  if [[ $VERBOSE == 1 ]]; then
    echo "$CURRJOBNUM jobs remaining"
  fi
done
