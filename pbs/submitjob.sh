#!/bin/bash 

#DEFAULT PARAMETERS
#change as desired below
LOGDIR=$HOME/pbslogs
TIME="01:00:00"
DATETIME=$(date +%Y%m%d%H%M%S)
ALPHATAG=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
JOBNAME="${USER}_${DATETIME}_$ALPHATAG"
CPUS="1"
MEM="1G"
BLACKLIST=""
QUEUE=""

LOG=${LOGDIR}/${JOBNAME}.out
ERRLOG=${LOGDIR}/${JOBNAME}.err
SCRIPT=${LOGDIR}/${JOBNAME}.sh

#helper function to print usage information
usage () {
  cat << EOF

submitjob.sh v0.0.1 

by Jochen Weile <jochenweile@gmail.com> 2021

Submits a new PBS job
Usage: submitjob.sh [-n|--name <JOBNAME>] [-t|--time <WALLTIME>] 
    [-c|cpus <NUMCPUS>] [-m|--mem <MEMORY>] [-l|--log <LOGFILE>] 
    [-e|--err <ERROR_LOGFILE>] [--conda <ENV>] [--] <CMD>

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

#check if PBS is installed
PBS_PATH=$(which qsub)
if [ -x "$PBS_PATH" ] ; then
  echo "PBS detected at: $PBS_PATH"
else
  >&2 echo "##########################################"
  >&2 echo "ERROR: PBS doesn't appear to be installed!"
  >&2 echo "##########################################"
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

#check if requested conda environment exists
if ! [[ -z "$CONDAENV" ]]; then
  if conda env list|grep "$CONDAENV"; then
    echo "Successfully identified environment '$CONDAENV'"
  else
    echo "Environment '$CONDAENV' does not exist!">&2
    exit 1
  fi
fi

if ! [[ -z $BLACKLIST ]]; then
  echo "WARNING: Blacklisting is not currently supported for PBS"
fi

#create logdir if it doesn't exist
mkdir -p $LOGDIR

#write the PBS submission script
echo "#!/bin/bash">$SCRIPT
echo "#PBS -S /bin/bash">>$SCRIPT
echo "#PBS -N $JOBNAME">>$SCRIPT
echo "#PBS -l nodes=1:ppn=$CPUS,walltime=$TIME,mem=$MEM">>$SCRIPT
if ! [[ -z $QUEUE ]]; then
  echo "#PBS -q $QUEUE">>$SCRIPT
fi
echo "#PBS -e localhost:$ERRLOG">>$SCRIPT
echo "#PBS -o localhost:$LOG">>$SCRIPT
echo "#PBS -d $(pwd)">>$SCRIPT
echo "#PBS -V"
echo "export PBS_NCPU=$CPUS"
if ! [[ -z "$CONDAENV" ]]; then
  echo "source $CONDA_PREFIX/etc/profile.d/conda.sh">>$SCRIPT
  echo "conda activate $CONDAENV">>$SCRIPT
fi
echo "$CMD">>$SCRIPT
if ! [[ -z "$CONDAENV" ]]; then
  echo "conda deactivate">>$SCRIPT
fi

#and submit
qsub $SCRIPT

# $ submitjob.sh pwd
# Slurm detected at: /usr/bin/sbatch
# Submitted batch job 162814