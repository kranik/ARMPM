#!/bin/bash

# Calculate average cpu usage per core.
#      user  nice system   idle iowait irq softirq steal guest guest_nice
# cpu0 30404 2382   6277 554768   6061   0      19    0      0          0

if (( $# != 1 )); then
  echo "This program requires a wait input for the sensors in nsecs." >&2
  exit 1
fi

echo -e "#Timestamp\t\tCPU_ID\tuser%\tnice%\tsys%\tidle%\tiowait%\tirq%\tsoftiq%\tsteal%\tguest%\tguest_nice%"

declare -a CPUs
declare -a CPUs_st
declare -a CPUs_nd
declare -a CPUs_idle
time_convert=1000000000

CPUs=($(awk '{if($1 == "processor") print $3}' /proc/cpuinfo))

A=($(sed -n '2,9p' /proc/stat))
last_cpu=$( echo "scale = 0;  ${#CPUs[@]} - 1;" | bc)

for i in `seq 0 $last_cpu`
do
	CPUs_st[$i]=$(echo "scale = 2;  ${A[$i*11+1]}  + ${A[$i*11+2]}  + ${A[$i*11+3]}  + ${A[$i*11+4]}  + ${A[$i*11+5]}  + ${A[$i*11+6]}  + ${A[$i*11+7]}  + ${A[$i*11+8]}  + ${A[$i*11+9]}  + ${A[$i*11+10]};" | bc)
	
done

while true; do
	#This is to convert the user input of usecs to secs, required ofr the sleep call
	sleep `echo "scale = 10; $1/$time_convert;" | bc`
	C=($(sed -n '2,9p' /proc/stat))
	timestamp=$(date +'%s%N')

	for i in `seq 0 $last_cpu`
	do
        	CPUs_nd[$i]=$(echo "scale = 2;  ${C[$i*11+1]}  + ${C[$i*11+2]}  + ${C[$i*11+3]}  + ${C[$i*11+4]}  + ${C[$i*11+5]}  + ${C[$i*11+6]}  + ${C[$i*11+7]}  + ${C[$i*11+8]}  + ${C[$i*11+9]}  + ${C[$i*11+10]};" | bc)

	        CPUs_user[$i]=$(echo "scale=2; (100 * (${C[$i*11+1]} - ${A[$i*11+1]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
        	CPUs_nice[$i]=$(echo "scale=2; (100 * (${C[$i*11+2]} - ${A[$i*11+2]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
	        CPUs_sys[$i]=$(echo "scale=2; (100 * (${C[$i*11+3]} - ${A[$i*11+3]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
		CPUs_idle[$i]=$(echo "scale=2; (100 * (${C[$i*11+4]} - ${A[$i*11+4]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
        	CPUs_iowait[$i]=$(echo "scale=2; (100 * (${C[$i*11+5]} - ${A[$i*11+5]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
	        CPUs_irq[$i]=$(echo "scale=2; (100 * (${C[$i*11+6]} - ${A[$i*11+6]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
        	CPUs_softiq[$i]=$(echo "scale=2; (100 * (${C[$i*11+7]} - ${A[$i*11+7]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
	        CPUs_steal[$i]=$(echo "scale=2; (100 * (${C[$i*11+8]} - ${A[$i*11+8]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
        	CPUs_guest[$i]=$(echo "scale=2; (100 * (${C[$i*11+9]} - ${A[$i*11+9]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
        	CPUs_guest_nice[$i]=$(echo "scale=2; (100 * (${C[$i*11+10]} - ${A[$i*11+10]}) / (${CPUs_nd[$i]} - ${CPUs_st[$i]}))" | bc)
	
		echo -e "$timestamp\tCPU_${CPUs[$i]}\t${CPUs_user[$i]}\t${CPUs_nice[$i]}\t${CPUs_sys[$i]}\t${CPUs_idle[$i]}\t${CPUs_iowait[$i]}\t${CPUs_irq[$i]}\t${CPUs_softiq[$i]}\t${CPUs_steal[$i]}\t${CPUs_guest[$i]}\t${CPUs_fuest_nice[$i]}"
		#Use C as the new A (old values)
		for j in `seq 1 10`
		do
			A[$i*11+$j]=${C[$i*11+$j]}
		done
:
		CPUs_st[$i]=${CPUs_nd[$i]}	
	done

	echo -e "\n"	
done
