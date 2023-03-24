#!/bin/bash
#Installer script
set +H
#Prefix can be defined by user argument. Defaults to ~/.local/bin
PREFIX=${1:-${HOME}/.local/bin/}

#Determine whether we're working with Slurm or PBS
QSUB_PATH=$(which qsub)
SLURM_PATH=$(which sbatch)
if [[ -n $SLURM_PATH ]]; then
  echo "Detected Slurm installation."
  BASEDIR="slurm/"
elif [[ -n $QSUB_PATH ]]; then
  #this could either be PBS or SGE, look for programs that are exclusive to either
  QRUN_PATH=$(which qrun)
  QCONF_PATH=$(which qconf)
  if [[ -n $QRUN_PATH ]]; then
    echo "Detected PBS installation."
    BASEDIR="pbs/"
  elif [[ -n $QCONF_PATH ]]; then
    echo "Detected SGE installation."
    BASEDIR="sge/"
  fi
  # echo "Detected qsub executable."
  # while [[ -z $BASEDIR ]]; do
  #   echo "Please type 'PBS' if this a PBS (Torque/OpenPBS/PBS Pro) system or type 'SGE' if this GridEngine (SGE/Univa/Altair) system."
  #   read -r HPCTYPE
  #   if [[ $HPCTYPE == "PBS" ]]; then
  #     BASEDIR="pbs/"
  #   elif [[ $HPCTYPE == "SGE" ]]; then
  #     BASEDIR="sge/"
  #   else
  #     echo "\nInvalid answer!"
  #   fi
  # done
else
  echo "ERROR: Unable to determine HPC system!">&2
  echo "No Slurm / PBS / SGE executable found.">&2
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
  echo "ERROR: Cannot write to .bash_alias or .bashrc!">&2
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
    cat ${BASEDIR}aliases>>$TMPFILE
    tail -n +$((END+1)) "${BRC}.bak">>$TMPFILE
    #check for valid syntax before overwriting old bashrc
    if bash -n $BRC ; then
      cp $TMPFILE $BRC
      rm $TMPFILE
    else
      echo "ERROR! Invalid syntax in $BRC ! Cancelling replacement!">&2
      exit 1
    fi
  else
    echo "ERROR: Invalid clusterUtil section in $BRC !">&2
    exit 1
  fi
fi

