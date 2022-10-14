#!/bin/bash
#Installer script

#Prefix can be defined by user argument. Defaults to ~/.local/bin
PREFIX=${1:-${HOME}/.local/bin/}

#Determine whether we're working with Slurm or PBS
PBS_PATH=$(which qsub)
SLURM_PATH=$(which sbatch)
if [[ -n $SLURM_PATH ]]; then
  BASEDIR="slurm/"
elif [[ -n $PBS_PATH ]]; then
  BASEDIR="pbs/"
else
  echo "ERROR: Neither SLURM nor PBS were found!">&2
  exit 1
fi

#copy files to target directory
cp -v ${BASEDIR}*.sh ${PREFIX}

#determine if bash dotfiles are writable
if [[ -w ${HOME}/.bash_aliases ]]; then
  BRC=${HOME}/.bash_aliases
#check if .bash_aliases or .bashrc are writable
elif [[ -w ${HOME}/.bashrc ]]; then
  BRC=${HOME}/.bashrc
else
  echo "ERROR: Cannot write to .bash_alias or .bashrc!"
  exit 1
fi

#make a backup of the old file
cp $BRC "${BRC}.bak"
echo "Made a backup copy of $(basename $BRC) : ${BRC}.bak"

#if no prior version of the content exists
if ! grep -q '>>> clusterUtil >>>' $BRC ; then
  #add it to the end
  echo "Appending aliases to $BRC"
  # echo "$CONTENT">>$BRC 
  cat ${BASEDIR}aliases>>$BRC
else
  #otherwise, replace it
  echo "Replacing pre-existing aliases in $BRC"
  START=$(grep -n '>>> clusterUtil >>>' $BRC|cut -f 1 -d :)
  END=$(grep -n '<<< clusterUtil <<<' $BRC|cut -f 1 -d :)
  if [[ $END > $START ]]; then
    TMPFILE=$(mktemp)
    head -n $((START-1)) "${BRC}.bak">$TMPFILE
    # echo "$CONTENT">>$TMPFILE
    cat ${BASEDIR}aliases>>$BRC
    tail -n +$((END+1)) "${BRC}.bak">>$TMPFILE
    cp $TMPFILE $BRC
    rm $TMPFILE
  else
    echo "ERROR: Invalid clusterUtil section in $BRC !"
    exit 1
  fi
fi

