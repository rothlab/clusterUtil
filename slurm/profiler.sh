#!/bin/bash

LOGDIR=$HOME/slurmlogs
DATETIME=$(date +%Y%m%d%H%M%S)
ALPHATAG=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
JOBNAME="${USER}_${DATETIME}_$ALPHATAG"
LOG=${LOGDIR}/profile_${JOBNAME}.tsv
INTERVAL=5

#helper function to print usage information
usage () {
  cat << EOF

profiler.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Generates a CPU and memory profile of a process subtree.
Usage: profiler.sh [-l|--log <LOGFILE>] [--] <CMD>

-l|--log      : Output file, to which profiler data will be written. Defaults to 
              profile_<USER>_<TIME>_<RANDOMID>.tsv in log directory ${LOGDIR} ,
              e.g. ${LOG}
-i|--interval : Scanning interval in seconds (Default: $INTERVAL)
--            : Indicates end of options, indicating that all following 
              arguments are part of the job command
<CMD>         : The command to execute

IMPORTANT NOTE: The first occurrence of a positional parameter will be 
interpreted as the beginning of the job command, such that all options 
(starting with "--") will be considered part of the command, rather than 
as options for profiler.sh itself.

EOF
 exit $1
}

#Parse Arguments
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage 0
      shift
      ;;
    -l|--log)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        LOGFILE=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
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
      CMD=$@
      eval set -- ""
      ;;
    -*|--*=) # unsupported flags
      echo "ERROR: Unsupported flag $1" >&2
      usage 1
      ;;
    *) # the first occurrence of a positional parameter indicates the main command
      CMD=$@
      eval set -- ""
      # PARAMS="$PARAMS $1"
      # shift
      ;;
  esac
done

mkdir -p ${LOGDIR}
#run the process
eval $CMD &
#record its process ID
MAINPID=$!

#temporary file location
TMP=$(mktemp)

#helper function to recursively filter down on child processes
#relies on arrays defined outside of the function: PSLINES, PIDS and PPIDS
getChildren() {
  PID=$1
  #get indices of matching PPIDS
  LNUMS=$(echo "${PPIDS[@]}"|tr ' ' '\n'|grep -n "$PID"|cut -d: -f1)
  for LNUM in $LNUMS; do
    IDX=$((LNUM-1))
    echo "${PSLINES[IDX]}"
    CPID="${PIDS[$IDX]}"
    getChildren "$CPID"
  done
}

printf "Time\tCPU(%%)\tMemory(KB)\tThreads\n">$LOGFILE

#get all process information and store in temporary file
ps -u "$USER" -o pid,ppid,pcpu,vsize,thcount>"$TMP"

#loop until main process is no longer listed
while grep -q $MAINPID $TMP; do
  #read columns from inside the temp file into arrays
  mapfile -t PSLINES <$TMP
  #(yes, it has to be this awkward...)
  mapfile -t PIDS < <(awk '{print $1}' $TMP)
  mapfile -t PPIDS < <(awk '{print $2}' $TMP)

  #filter down to subprocesses of main PID
  getChildren "$MAINPID">"$TMP"
  #calculate CPU and MEMORY totals
  TOTALCPU=$(awk '{print $3}' $TMP|paste -sd+|bc)
  TOTALMEM=$(awk '{print $4}' $TMP|paste -sd+|bc)
  TOTALTHREADS=$(awk '{print $5}' $TMP|paste -sd+|bc)

  printf "$(date '+%Y/%m/%d-%T')\t${TOTALCPU}\t${TOTALMEM}\t${TOTALTHREADS}\n">>$LOGFILE

  #wait and refresh process information 
  sleep $INTERVAL
  ps -u "$USER" -o pid,ppid,pcpu,vsize,thcount>"$TMP"
done

rm "$TMP"

