#!/usr/bin/env bash
#DRYRUN=1	# comment or set to empty to real run
#
# Usage: continue-steps.sh [<simulation>] <cnts>

# if only one argument, assume it is cnts
if [ $# -eq 0 ] ; then
  echo "Usage: `basename $0` [<simulation>] <cnts>" && exit
elif [ $# -eq 1 ] ; then
  CNTS=$1 # how many cnt (iterations) of stepN_production
  SIM=
elif [ $# -eq 2 ] ; then
  SIM=$1
  CNTS=$2
else
  echo "Usage: `basename $0` [<simulation>] <cnts>" >&2
  exit 1
fi

MAX_FAILS=3 # how many times to retry a failed step

prev_last_cnt() {
  # look for like step5_3.pdb
  done_pdbs=$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null)
  [ x"$done_pdbs" = x ] && echo 0 && return 0
  last_pdb=$(ls *$(ls -1 step[0-9]*_[0-9]*.pdb 2>/dev/null | cut -d_ -f2 | sort -n | tail -n1))
  echo $last_pdb | awk -F_ '{print $2}' | awk -F. '{print $1}'
}

read_retries_log() {
  local retrylog=$1
  if [ -f $retrylog ] ; then
    cat $retrylog
  else
    echo 0
  fi
}

# run one iteration (cnt) of simulation
# expect to find the stepN_production.inp file
run-cnt() {
    local inp=$1
    local cnt=$2

    local step=${inp%_production.inp}
    local retrylog=${step}_${cnt}_retries.log

    if [ -f $retrylog ] ; then
      failed=$(cat $retrylog)
      failed=$((failed +1))
    else
      failed=0
    fi
    echo $failed > $retrylog
    local outfile=${step}_${cnt}_production.${failed}.out

    date
    echo -n "${PWD//$HOME\//}> "
    echo " mpirun charmm cnt=$cnt -i $inp -o $outfile"
    [ -z $DRYRUN ] && mpirun charmm cnt=$cnt -i $inp -o $outfile
    if grep "NORMAL TERMINATION BY NORMAL STOP" $outfile; then
        tail -n7 $outfile
        return 0
    else
        grep -B3 TERMINATING $outfile
        return 1
    fi
}

# is there another simulation?
CurrentSimFile=~/.current_simulation
if [ -f $CurrentSimFile ] ; then
  echo "Currently running another sinulation $(cat $CurrentSimFile)" >&2
  exit 1
fi

ctrl_c() {
  rm $CurrentSimFile
  exit 1
}
trap ctrl_c INT

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
step=${inp%_production.inp}
echo "Previously finished on $prev steps, will continue until $CNTS steps"
# Last stepN_production.inp
cnt=$((prev +1))
while [ $cnt -le $CNTS ] ; do
    if run-cnt $inp $cnt ; then
      RET="_$cnt"
      cnt=$((cnt +1))
    else
      # retry no more than MAX_FAILS times
      fails=$(read_retries_log ${step}_${cnt}_retries.log)
      if [ $fails -gt $MAX_FAILS ] ; then
        RET="_${cnt}_failed"
        break
      else
        # clean up $cnt and cnt-1, and retry
        cnt_1=$((cnt -1))
        # backup the failed cnt and cnt-1
        tar cfz failed_${step}_${cnt}_${fails}.tgz ${step}_${cnt}* ${step}_${cnt_1}*
        rm ${step}_${cnt}.* ${step}_${cnt_1}.* # mainly the pdb, but don't delete stepN_cnt_retries.log
        cnt=$((cnt -1))
      fi
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
