#!/usr/bin/env bash
CNTS="${1:-6}"	# how many cnt (iterations) of stepN_production
SIM=$2
#DRYRUN=1	# comment or set to empty to real run
#
# Usage: continue-steps.sh <cnts> <simulation>

prev_last_cnt() {
  # look for like step5_3.pdb
  done_pdbs=$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null)
  [ x"$done_pdbs" = x ] && echo 0 && return
  last_pdb=$(ls *$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null | cut -d_ -f2 | sort -n | tail -n1))
  echo $last_pdb | awk -F_ '{print $2}' | awk -F. '{print $1}'
}

# is there another simulation?
CurrentSimFile=~/.current_simulation
if [ -f $CurrentSimFile ] ; then
  echo "Currently running another sinulation $(cat $CurrentSimFile)" >&2
  exit 1
fi

# set current simulation
if [ x"$SIM" != x ] ; then
  [ ! -d $HOME/$SIM ] && echo "$HOME/$SIM not found" >&2 && exit 1
  cd $HOME/$SIM/charmm_openmm
else
  if [ $(basename $PWD) = "charmm_openmm" ] ; then
    SIM=$(cd .. ; basename $PWD)
  elif [ -d ./charmm_openmm ] ; then
    SIM=$(basename $PWD)
    cd charmm_openmm
  fi
fi

echo $SIM > ~/.current_simulation

# continue after previous steps
prev=$(prev_last_cnt) # previously cnt ran to this
inp=$(ls *production.inp)
echo "Previously finished on $prev steps, will continue until $CNTS steps"
# Last stepN_production.inp
for cnt in `seq $((prev +1)) $CNTS` ; do
      outfile=${inp}.cnt=${cnt}.out
      date
      echo -n "${PWD//$HOME\//}> "
      echo " mpirun charmm cnt=$cnt -i $inp -o $outfile"
      [ -z $DRYRUN ] && mpirun charmm cnt=$cnt -i $inp -o $outfile
      if grep "NORMAL TERMINATION BY NORMAL STOP" $outfile; then
        RET="_$cnt"
        tail -n7 $outfile
      else
        RET="_${cnt}_failed"
        grep -B3 TERMINATING $outfile
        break
      fi
done


# All done, archive results and send to s3
cd .. 
SIM=$(basename $PWD)
RESULTS=${SIM}_results${RET}.tgz
cd ..
echo "tar cfz $RESULTS $SIM"
[ -z $DRYRUN ] && tar cfz $RESULTS $SIM
echo aws s3 cp $RESULTS s3://annadu/charmm/results/$RESULTS
[ -z $DRYRUN ] && aws s3 cp $RESULTS s3://annadu/charmm/results/$RESULTS

rm $CurrentSimFile
