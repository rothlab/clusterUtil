# clusterUtil
ClusterUtil is a collection of utility scripts for HPC cluster usage and serves as an abstraction layer over PBS and Slurm.

## Installation

```bash
#clone this repo
git clone https://github.com/jweile/clusterUtil.git
#change to repo folder
cd clusterUtil
#run installer
./install.sh
```

By default, clusterUtil will be installed in `~/.local/bin/`, but if you'd like to customize the installation location you can provide it as an argument to the installer, e.g. `./install.sh ~/bin/`.

## Commands included
slogin - log into any (or a specific) worker node. To log into a specific node, provide it as an argument, e.g. `slogin galen42`

submitjob.sh - submit job in one line (no script required). Output/errors will be logged in `$HOME/slurmlogs/` or `$HOME/pbslogs` by default. Supports custom time, CPU, memory limits, log file locations and conda environments. Use `submitjob.sh --help` for a full breakdown.

waitForJobs.sh - waits for all (or a list of) the current user's jobs and monitor for suspensions and holds, which it will try resolve automatically. Use `waitForJobs.sh --help` for more information.

cleanSlurmLogs / cleanPBSLogs - delete logs and submission scripts older than 2 weeks from `$HOME/slurmlogs/` or `$HOME/pbslogs`. You can also specify the desired maximum age of the logs in days, e.g. `cleanSlurmLogs 30`

deleteAllMyJobs - cancel all currently running or scheduled jobs of the current user.

## Example

```bash
JOBS=""
#here we assume $COMMANDS contains a number of commands you want to submit to the cluster
for CMD in $COMMANDS; do
  #submit job
  RETVAL=$(submitjob.sh --cpus 4 --mem 8GB --time 4:00:00 --log "${CMD##*/}.log" --err "${CMD##*/}.err" -- $CMD)
  #capture job id
  JOBID=${RETVAL##* }
  JOBS=${JOBS},$JOBID
done
#wait for list of jobs
waitForJobs.sh --verbose $JOBS
```

