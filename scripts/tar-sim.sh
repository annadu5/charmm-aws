#!/usr/bin/env bash
SIM=$1
DRYRUN=${DRYRUN}	# set to non-empty to do dryrun
#
# Usage: tar-sim.sh [<simulation>]

prev_last_cnt() {
  # look for like step5_3.pdb
  done_pdbs=$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null)
  [ x"$done_pdbs" = x ] && echo 0 && return
  last_pdb=$(ls *$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null | cut -d_ -f2 | sort -n | tail -n1))
  echo $last_pdb | awk -F_ '{print $2}' | awk -F. '{print $1}'
}

CurrentSimFile=~/.current_simulation

# set current simulation
if [ x"$SIM" != x ] ; then
  [ ! -d $HOME/$SIM ] && echo "$HOME/$SIM not found" >&2 && exit 1
elif [ $(basename $PWD) = "charmm_openmm" ] ; then
  SIM=$(cd .. ; basename $PWD)
elif [ -d ./charmm_openmm ] ; then
  SIM=$(basename $PWD)
elif [ -f $CurrentSimFile ] ; then
  SIM=$(cat $CurrentSimFile)
else
  echo "Cannot decide which simulation" >&2 && exit 1
fi

cd $HOME/$SIM/charmm_openmm
RET=$(prev_last_cnt)
[ -f $CurrentSimFile ] && RET=${RET}_running
RESULTS=${SIM}_results_${RET}.tgz
cd $HOME 
if [ x$DRYRUN = x ]; then
  echo $RESULTS
  tar cfz $RESULTS $SIM
elif [ x$DRYRUN = "xName" ]; then
  echo $RESULTS
else
  echo "tar cfz $RESULTS $SIM"
fi
