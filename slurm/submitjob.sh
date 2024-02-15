#!/bin/bash 

#fail on error, even within pipes; require variable declarations, disable history tracking
set -eEuo pipefail +H
#if an error occurred, print where it happened
function handle_error {
  local retval=$?
  local line=$1
  echo "Failed at $line: $BASH_COMMAND"
  exit $retval
}
trap 'handle_error $LINENO' ERR

VERSION="1.0.0"

#DEFAULT PARAMETERS
#change as desired below
LOGDIR=$HOME/slurmlogs
TIME="01:00:00"
DATETIME=$(date +%Y%m%d%H%M%S)
ALPHATAG=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8||true)
JOBNAME="${USER}_${DATETIME}_$ALPHATAG"
CPUS="1"
MEM="1G"
BLACKLIST=""
QUEUE=""
DOREPORT=0
CONDAENV=""
SKIPVALIDATION=""

LOG=${LOGDIR}/${JOBNAME}.out
ERRLOG=${LOGDIR}/${JOBNAME}.err
SCRIPT=${LOGDIR}/${JOBNAME}.sh

#helper function to print usage information
usage () {
  cat << EOF

submitjob.sh v${VERSION}

by Jochen Weile <jochenweile@gmail.com> 2021

Submits a new slurm job
Usage: submitjob.sh [-n|--name <JOBNAME>] [-t|--time <WALLTIME>] 
    [-c|cpus <NUMCPUS>] [-m|--mem <MEMORY>] [-l|--log <LOGFILE>] 
    [-e|--err <ERROR_LOGFILE>] [--conda <ENV>] [--blacklist <LIST>]
    [--skipValidation] [--report] [--] <CMD>

-n|--name : Job name. Defaults to ${USER}_<TIMESTAMP>_<RANDOMSTRING>
-t|--time : Maximum (wall-)runtime for this job in format HH:MM:SS.
            Defaults to ${TIME}
-c|--cpus : Number of CPUs required for this job. Defaults to ${CPUS}
-m|--mem  : Maximum amount of RAM consumed by this job. Defaults to ${MEM}
-l|--log  : Output file, to which STDOUT will be written. Defaults to 
            <JOBNAME>.out in log directory ${LOGDIR}.
-e|--err  : Error file, to which STDERR will be written. Defaults to 
            <JOBNAME>.err in log directory ${LOGDIR}.
-b|--blacklist : Comma-separated black-list of nodes not to use. If none
            is provided, all nodes are allowed.
-q|--queue : Which queue to use. Defaults to default queue
--conda   : activate given conda environment for job
--skipValidation : skip conda environment activation (faster submission 
            but will lead to failed jobs if environment isn't valid)
--report  : Report success or failure of job at the end of the log file
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
  >&2 echo "############################################"
  >&2 echo "ERROR: Slurm doesn't appear to be installed!"
  >&2 echo "############################################"
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
    --version)
      echo "submitjob.sh :: clusterutil v${VERSION}"
      exit 0
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
    -b|--blacklist)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        BLACKLIST=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    -q|--queue)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        QUEUE=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    --conda)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CONDAENV=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        usage 1
      fi
      ;;
    --skipValidation)
      SKIPVALIDATION=1
      shift
      ;;
    --report)
      DOREPORT=1
      shift
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

#check if conda or mamba is installed
if [[ -n $(command -v conda) ]]; then
  CONDAMGR=conda
elif [[ -n $(command -v mamba) ]]; then
  CONDAMGR=mamba
elif [[ -n $(command -v micromamba) ]]; then
  CONDAMGR=micromamba
elif [[ -n "$CONDAENV" ]]; then
  echo "No conda installation was found!">&2
  exit 1
fi

#check if requested conda environment exists
if ! [[ -z "$CONDAENV" && -z "$SKIPVALIDATION" ]]; then
  if ${CONDAMGR} env list|grep "$CONDAENV"; then
    echo "Successfully identified environment '$CONDAENV'"
  else
    echo "Environment '$CONDAENV' does not exist!">&2
    exit 1
  fi
fi

#create logdir if it doesn't exist
mkdir -p $LOGDIR

#write the slurm submission script
echo "#!/bin/bash">$SCRIPT
echo "#SBATCH --time=$TIME">>$SCRIPT
echo "#SBATCH --job-name=$JOBNAME">>$SCRIPT
echo "#SBATCH --cpus-per-task=$CPUS">>$SCRIPT
echo "#SBATCH --mem=$MEM">>$SCRIPT
if ! [[ -z $QUEUE ]]; then
  echo "#SBATCH --partition=$QUEUE">>$SCRIPT
fi
echo "#SBATCH --error=$ERRLOG">>$SCRIPT
echo "#SBATCH --output=$LOG">>$SCRIPT
if ! [[ -z $BLACKLIST ]]; then
  echo "#SBATCH --exclude=$BLACKLIST">>$SCRIPT
fi
echo "set -eEuo pipefail +H">>$SCRIPT
if [[ "$DOREPORT" == 1 ]]; then
  echo 'echo "Running on node $HOSTNAME"'>>$SCRIPT
fi
ACTIVATED=""
if ! [[ -z "$CONDAENV" ]]; then
  #if we're in the base environment, activate the desired new environment
  if [[ -z $CONDA_DEFAULT_ENV || $CONDA_DEFAULT_ENV == "base" ]]; then
    echo 'source ${CONDA_PREFIX}'"/etc/profile.d/${CONDAMGR}.sh">>$SCRIPT
    echo "${CONDAMGR} activate $CONDAENV">>$SCRIPT
    ACTIVATED=1
  #if we're neither in base, nor in $CONDAENV, then we're screwed.
  elif [[ "$CONDA_DEFAULT_ENV" != "$CONDAENV" ]]; then
    echo "Current environment is neither base nor $CONDAENV. Unable to proceed">&2
    exit 1
  fi
fi
echo "$CMD">>$SCRIPT
echo 'EXITCODE=$?'>>$SCRIPT
# if ! [[ -z "$CONDAENV" ]]; then
if [[ -n $ACTIVATED ]]; then
  echo "${CONDAMGR} deactivate">>$SCRIPT
fi
if [[ "$DOREPORT" == 1 ]]; then
  echo 'if [[ "$EXITCODE" == 0 ]]; then echo "Job completed successfully."; else echo "Job failed with exit code $EXITCODE"; fi'>>$SCRIPT
fi
#propagate exit code to wrapper script
echo 'exit $EXITCODE'>>$SCRIPT
#make script executable
chmod u+x $SCRIPT

#and submit
sbatch $SCRIPT
