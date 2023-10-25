#!/bin/bash

if [[ -z $(command -v dialog) ]]; then
  echo "The 'dialog' software is not installed!">&2
  exit 1
fi


LOGDIR=$HOME/slurmlogs
TIME="01:00:00"
DATETIME=$(date +%Y%m%d%H%M%S)
JOBNAME="${USER}_${DATETIME}"
CPUS="1"
MEM="1G"
LOG=${LOGDIR}/${JOBNAME}.out
ERRLOG=${LOGDIR}/${JOBNAME}.err
COMMAND=""

checkParams() {
  SPACEPATTERN=" |'"
  NUMRX='^[0-9]+$'
  MEMRX='^[0-9]+[MG]{1}$'

  if [[ -z "$JOBNAME" ]]; then
    echo "Job name must not be empty"
  elif [[ "$JOBNAME" =~ $SPACEPATTERN  ]]; then
    echo "Job name must not contain spaces"
  elif ! [[ "$CPUS" =~ $NUMRX ]]; then
    echo "Max CPUs must be an integer number"
  elif ! [[ "$MEM" =~ $MEMRX ]]; then
    echo "Max RAM must be an integer number followed by M or G"
  elif ! (realpath -q "$LOG" >/dev/null ); then
    echo "Log file must be an accessible path"
  elif ! (realpath -q "$ERRLOG" >/dev/null ); then
    echo "Error file must be an accessible path"
  else
    echo "OK"
  fi
}

PARAMCHK=""
while [[ "$PARAMCHK" != "OK" ]]; do

  if [[ -z "$PARAMCHK" ]]; then
    MSG="Please enter your submission parameters:"
  else
    dialog \
      --backtitle "ClusterUtil on $HOSTNAME" \
      --title "User error" \
      --clear \
      --msgbox "ERROR: ${PARAMCHK}!" 10 30

    MSG="ERROR: ${PARAMCHK}! Please enter your submission parameters:"
  fi

  #temporarily re-direct stream handle 3 to stdout
  # (this will serve as the drawing commmand output)
  exec 3>&1
  VALUES=$(dialog \
    --ok-label 'Submit' \
    --backtitle "ClusterUtil on $HOSTNAME" \
    --title "New Slurm job submission" \
    --form "$MSG" 15 50 0 \
    "Job name" 1 1 "$JOBNAME" 1 10 40 0 \
    "Max CPU"  2 1 "$CPUS" 2 10 10 0 \
    "Max RAM"  3 1 "$MEM" 3 10 10 0 \
    "Log file" 4 1 "$LOG" 4 10 200 0 \
    "Err.file" 5 1 "$ERRLOG" 5 10 200 0 \
    "Command"  7 1 "$COMMAND" 7 10 200 0 \
    2>&1 1>&3 )
  STATUS=$?
  #the above re-directs the draw-commands from stdout to handle 3 
  #and results from stderr to stdout so that the $() subshell 
  #can capture them
  #we're done with channel 3 now, so we can undo the redirection
  exec 3>&-

  if [[ $STATUS -ne 0 ]]; then
    clear
    echo "Aborted."
    exit 0;
  fi

  #replace newlines from output with tabs, then use tab-separated parsing
  #to read the line into multiple variables. We can't just use newlines
  #because read only processes a single line at a time
  IFS=$'\t' read -r JOBNAME CPUS MEM LOG ERRLOG COMMAND \
    <<< "$(echo "$VALUES"|tr '\n' '\t')"

  PARAMCHK=$(checkParams)

done

clear

submitjob.sh -n "$JOBNAME" -c "$CPUS" -m "$MEM" -l "$LOG" -e "$ERRLOG" -- $COMMAND

