#!/bin/bash 

#DEFAULT PARAMETERS
#change as desired below
LOGDIR=$HOME/slurmlogs
TIME="01:00:00"
JOBNAME=${USER}$(date +%Y%m%d%H%M%S)
CPUS="1"
MEM="1G"
LOG=${LOGDIR}/${JOBNAME}.out
ERRLOG=${LOGDIR}/${JOBNAME}.err
SCRIPT=${LOGDIR}/${JOBNAME}.sh

#helper function to print usage information
usage () {
  cat << EOF

submitjob.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Submits a new slurm job
Usage: submitjob.sh [-n|--name <JOBNAME>] [-t|--time <WALLTIME>] 
    [-c|cpus <NUMCPUS>] [-m|--mem <MEMORY>] [-l|--log <LOGFILE>] 
    [-e|--err <ERROR_LOGFILE>] [--] <CMD>

-n|--name : Job name. Defaults to ${USER}_<TIMESTAMP>
-t|--time : Maximum (wall-)runtime for this job in format HH:MM:SS.
            Defaults to ${TIME}
-c|--cpus : Number of CPUs required for this job. Defaults to ${CPUS}
-m|--mem  : Maximum amount of RAM consumed by this job. Defaults to ${MEM}
-l|--log  : Output file, to which STDOUT will be written. Defaults to 
            <JOBNAME>.out in log directory ${LOGDIR}.
-e|--err  : Error file, to which STDERR will be written. Defaults to 
            <JOBNAME>.err in log directory ${LOGDIR}.
--        : Indicates end of options, indicating that all following 
            arguments are part of the job command
<CMD>     : The command to execute

IMPORTANT NOTE: The first occurrence of a positional parameter will be 
interpreted as the beginning of the job command, such that all options 
(starting with "--") will be considered part of the command, rather than 
as options for submitjob.sh itself.

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

#Parse Arguments
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage 0
      shift
      ;;
    -t|--time)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        TIME=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -n|--name)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        JOBNAME=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -c|--cpus)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CPUS=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -m|--mem)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        MEM=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -l|--log)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        LOG=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -e|--err)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        ERRLOG=$2
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

#create logdir if it doesn't exist
mkdir -p $LOGDIR

#write the slurm submission script
echo "#!/bin/bash">$SCRIPT
echo "#SBATCH --time=$TIME">>$SCRIPT
echo "#SBATCH --job-name=$JOBNAME">>$SCRIPT
echo "#SBATCH --cpus-per-task=$CPUS">>$SCRIPT
echo "#SBATCH --mem=$MEM">>$SCRIPT
echo "#SBATCH --error=$ERRLOG">>$SCRIPT
echo "#SBATCH --output=$LOG">>$SCRIPT
echo "$CMD">>$SCRIPT

#and submit
sbatch $SCRIPT
