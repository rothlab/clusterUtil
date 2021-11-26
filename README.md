# clusterUtil
utility scripts for HPC cluster usage

## Installation

```bash
#clone this repo
git clone https://github.com/jweile/clusterUtil.git
#change to repo folder
cd clusterUtil
#run installer
make install
```

## Commands included
slogin - log into any (or a specific) worker node

submitjob - submit job in one line (no script required). Output/errors will be logged in $HOME/slurmlogs/ by default

waitForJobs - wait for all (or a list of) my jobs and monitor for suspensions and holds

cleanSlurmLogs - delete logs older than 2 weeks

deleteAllMyJobs - cancel all my currently running or scheduled jobs
