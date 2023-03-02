#!/usr/bin/env bash
CNTS=${1:-3}	# how many cnt (iterations) of stepN_production
SIM=${2:-help}
#DRYRUN=1	# comment or set to empty to real run

# find the workspace:
# 1. current folder
# 2. ./$SIM folder
# 3. has $SIM.tgz
SIM=${SIM%.tgz}
if [ $SIM = "help" ] || [ $SIM = "-h" ] || [ $SIM = "--help" ] ; then
    echo "Usage: `basename $0` <Simulation>" && exit
elif [ $SIM = "." ] ; then
    SIM=$(basename $PWD)
elif [ $SIM = $(basename $PWD) ] && [ $PWD != $HOME ] ; then
    :
elif [ -d "$SIM" ] ; then
    cd $SIM
elif [ -f "${SIM}.tgz" ] ; then
    tar xfz "${SIM}.tgz"
    mv charmm-gui-* "${SIM}"
    cd $SIM
else
    echo "Unable to find the simulation $SIM" >&2
    exit 1
fi
pwd

CurrentSimFile=~/.current_simulation
if [ -f $CurrentSimFile ] ; then
  echo "Currently running another sinulation $(cat $CurrentSimFile)" >&2
  exit 1
fi

echo $SIM > ~/.current_simulation

# charmm gui's input files are in order
for inp in *.inp
do
    if [ "$inp" = *"production.inp" ] ; then
	break
    fi

    outfile=${inp}.out
    if [ -f charmm_openmm/$inp ] ; then 
        cd charmm_openmm
	echo -n "${PWD//$HOME\//}> "
        echo " mpirun charmm -i $inp -o $outfile"
	[ -z $DRYRUN ] && mpirun charmm -i $inp -o $outfile
	tail -n7 $outfile
	cd ..
    else
	echo -n "${PWD//$HOME\//}> "
        echo " charmm -i $inp -o $outfile"
        [ -z $DRYRUN ] && charmm -i $inp -o $outfile
	tail -n7 $outfile
    fi
done

# Last stepN_production.inp
if [ $inp = *"production.inp" ] ; then
    cd charmm_openmm
    for cnt in `seq 1 $CNTS` ; do
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
    cd .. 
fi

# All done, archive results and send to s3
RESULTS=${SIM}_results${RET}.tgz
cd ..
echo "tar cfz $RESULTS $SIM"
[ -z $DRYRUN ] && tar cfz $RESULTS $SIM
echo aws s3 cp $RESULTS s3://annadu/charmm/results/$RESULTS
[ -z $DRYRUN ] && aws s3 cp $RESULTS s3://annadu/charmm/results/$RESULTS

rm $CurrentSimFile
