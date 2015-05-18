#!/bin/bash
#This is my main script to run benchmarks in parallel with sensor collection
#KrNikov 2014

if [ "$#" -eq 0 ]; then
  echo "This program requires inputs. Type -h for help." >&2
  exit 1
fi

#Flags to enable different functionality
BENCH_EXEC_CHOSEN=0
SAVE_DIR_CHOSEN=0
SAMPLE_TIME=0
big_CHOSEN=0
LITTLE_CHOSEN=0
NUM_RUNS=0
big_FREQ=""
LITTLE_FREQ=""

#main loop b=big L=LITTLE s=save directory n=specify number of runs -t=benchmark directory -h=help
#requires getops, but this should not be an issue since ints built in bash
while getopts ":b:L:s:x:t:n:h" opt;
do
    case $opt in
        b|L)
            #Set flag name
            	if [[ $opt == b ]]; then
			core_select="big"
			max_f=2000000
			min_f=200000
		else
		        core_select="LITTLE"
		        max_f=1400000
		        min_f=200000
		fi

            #Make sure command has not already been processed (flag is unset)
            if (( "$core_select"_CHOSEN )); then
                echo "Invalid input: option -$opt has already been used!" >&2
                exit 1                
            else
                eval "$core_select"_CHOSEN=1
            fi

            spaced_OPTARG="${OPTARG//,/ }"

            #Go throught the selected frequecnies and make sure they are not out of bounds
	    #Also make sure they are present in the frequency table located at /sys/devices/system/cpu/cpufreq/iks-cpufreq/freq_table because the kernel rounds up
            #Specifying a higher/lower frequency or an odd frequency is now wrong, jsut the kernel handles it in the background and might lead to collection of unwanted resutls
            for freq_select in $spaced_OPTARG
            do
            	if (( "$freq_select" > $max_f || "$freq_select" < $min_f )); then 
		    echo "selected frequency $freq_select for -$opt is out of bounds. Range is [$max_f;$min_f]"
                    exit 1
                else
	            #if (( !$(grep -o " $freq_select " <<< "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies)" | grep -c .) && "$freq_select" != max_f && "$freq_select" != min_f )); then
			#echo "Input frequency $freq_select for -$opt not present in frequency table located at /sys/devices/system/cpu/cpu0/cpufreq/scaling_availavle_frequencies "
                        #exit 1;
                    #else
                        if [[ -z "$(eval echo \$$(eval echo "$core_select"_FREQ))" ]]; then
                            eval "$core_select"_FREQ=$freq_select
                        else 
                            eval "$core_select"_FREQ+=","
                            eval "$core_select"_FREQ+=$freq_select
                        fi
                    fi
                #fi
            done
            ;;
        #Specify the save directory, if no save directory is chosen the results are saved in the $PWD
        s)
            if (( $SAVE_DIR_CHOSEN )); then
                echo "Invalid input: option -s has already been used!" >&2
                exit 1                
            fi
            #If the directory exists, ask the user if he really wants to reuse it. I do not accept symbolic links as a save directory.
            if [[ -d $OPTARG ]]; then
                if [[ -L $OPTARG ]]; then
                    echo "-s $OPTARG is a symbolic link. Please enter a directory!" >&2 
                    exit 1
                else
                    #wait on user input here (Y/N)
                    #if user says Y set writing directory to that
                    #if no then exit and ask for better input parameters
                    echo "-s $OPTARG already exists. Continue writing in directory? (Y/N)" >&1
                    read usr_input
                    while true;
                    do
                        if [[ $usr_input == Y || $usr_input == y ]]; then
                            echo "Using existing directory $OPTARG" >&1
                            break
                        elif [[ $usr_input == N || $usr_input == n ]]; then
                            echo "Cancelled using save directory $OPTARG Program exiting." >&1
                            exit 0                            
                        else
                            echo "Invalid input: $usr_input !(Expected Y/N)" >&2
                            exit 1
                        fi
                    done
                    save_dir=$OPTARG
                    SAVE_DIR_CHOSEN=1
                    #Remove previosu results from the existing save directory structure. If you rerun MC.sh with different flags it might not overwrite all the old results, so this cleanup is necessary for correct analysis later on
                    find "$save_dir/" -name "Run_*" -exec rm -r -v "{}" +
                fi
            else
                #directory does not exist, set mkdir flag. Directory is made only when results are successfully collected.
                save_dir=$OPTARG
                SAVE_DIR_CHOSEN=1
            fi
            ;;
        #specify the benchmark executable to be ran
        x)
            if (( $BENCH_EXEC_CHOSEN )); then
                echo "Invalid input: option -x has already been used!" >&2
                exit 1                
            fi
            #Make sure the benchmark directory selected exists
            if [[ ! -x $OPTARG ]]; then
                echo "-x $OPTARG is not an executable file or does not exist. Please enter the bechmark executable script/program!" >&2 
                exit 1
            else
                bench_exec=$OPTARG
                BENCH_EXEC_CHOSEN=1
            fi
            ;;

        #specify the sensor sample time
        t)
            if (( $SAMPLE_TIME )); then
                echo "Invalid input: option -t has already been used!" >&2
                exit 1
            fi
            if (( !$OPTARG )); then
                echo "Invalid input: option -n needs to have a positive integer!" >&2
                exit 1
            else
                SAMPLE_TIME=$OPTARG
            fi
            ;;

        n)
            #Choose the number of runs. Data from different runs is saved in Run_(run number) subfolders in the save directory
            if (( $NUM_RUNS )); then
                echo "Invalid input: option -n has already been used!" >&2
                exit 1                
            fi
            echo $OPTARG
            if (( !$OPTARG )); then
                echo "Invalid input: option -n needs to have a positive integer!" >&2
                exit 1
            else        
                NUM_RUNS=$OPTARG                        
            fi
            ;;
        h)
            echo "Available flags and options:" >&2
            echo "-b [FREQUENCIES] -> turn on collection for big cores [benchmarks and monitors], specify frequencies in Hz separated by commas. Range is [500000;1200000]"
            echo "-L {FREQUENCIES] -> turn on collection for LITTLE cores [benchmarks and monitors], specify frequencies in Hz, separated by commas. Range is [175000;500000]."
            echo "-s [DIRECTORY] -> specify a save directory for the results of the different runs. If flag is not specified program uses current directory"
            echo "-t [DIRECTORY] -> specify the benchmark executable to be run. In multiple benchmarks are to be ran, put them all in a script and set that."
            echo "-n [NUMBER] -> specify number of runs. Results from different runs are saved in subdirectories Run_RUNNUM"
            echo "Mandatory options are: -b and/or -L; -t [DIR]; -n [NUM]"
            echo "You can group flags with no options together, flags are separated with spaces"
            echo "Recommended input: ./MC.sh -b {FREQEUNCY LIST} -L {FREQUENCY LIST} -s Results/{NAME}/ -t Benchmarks/{EXEC} -n {RUNS}"
            echo "Average time per 1 run of the complete benchmark set: UPDATE!"
            echo "You can control which benchmarks of the whole cBench soute are run by editing the bench_list file in the Benchmarks/cBench/ directory and commenting out/in the ones you want."
            exit 0 
            ;;
        :)
            echo "Option: -$OPTARG requires an argument" >&2
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

#Check if user has specified something to run
if (( !$big_CHOSEN && !$LITTLE_CHOSEN )); then
    echo "Nothing to run. Expected -b or -L" >&2
    exit 1
fi

if (( !$NUM_RUNS )); then
    echo "Nothing to run. Expected -n NUM_RUNS" >&2
    exit 1
fi

if (( !$BENCH_EXEC_CHOSEN )); then
    echo "No benchmarks specified. Expected -t BENCH_EXEC" >&2
    exit 1
fi

if (( !$SAMPLE_TIME )); then
        echo "Invalid input: option -s (sample time) has not been specified!" >&2
        exit 1
fi

sample_ns=$SAMPLE_TIME
sample_ms=$(echo "scale = 0; $sample_ns/1000000;" | bc )

#Set the environment
./enviroset.sh 1

#loop to run benchmarks
core_choices="big LITTLE"
cpu_option=""
cpu_number=""

for core_select in $core_choices;
do
    #Process only the cores the user has chosen 
    if (( "$core_select"_CHOSEN )); then
	
	if [[ $core_select == "big" ]]; then 
		cpu_option="-b"
		cpu_number=4
		cpu_collect=0
                cpufreq-set -d 1400000 -u 1400000  -c 0
        else	
		cpu_option="-L"
		cpu_number=0
		cpu_collect=4
                cpufreq-set -d 2000000 -u 2000000 -c 4
	fi
        #Run benchmarks for specified number of runs
        for i in `seq 1 $NUM_RUNS`;
        do
            
            echo "This is run $i out of $NUM_RUNS"            
                
		if (( $SAVE_DIR_CHOSEN )); then mkdir -v -p "$save_dir/Run_$i"
		else mkdir -v "Run_$i"
		fi

            #Run benchmark for each specified core frequency 
            freq_list="$(eval echo \$$(eval echo "$core_select"_FREQ))"
            freq_list="${freq_list//,/ }"
            #Set header flag

            for freq_select in $freq_list
	    do

		cpufreq-set -d $freq_select -u $freq_select -c $cpu_number

		echo "Core frequency: $freq_select""Mhz"
	        
		#Run collections scripts in parallel to the benchmarks
            	taskset -c $cpu_collect ./sensors 1 1 $sample_ns > "sensors_""$core_select""$freq_select"".data" &
            	PID_sensors=$!
            	disown

                #Run collections scripts in parallel to the benchmarks
                taskset -c $cpu_collect ./get_cpu_usage.sh $cpu_option -t $sample_ns > "usage_""$core_select""$freq_select"".data" &
                PID_usage=$!
                disown

            	taskset -c $cpu_collect ./get_cpu_events.sh $cpu_option -s "benchmarks_""$core_select""$freq_select"".data" -x $bench_exec -t $sample_ms 2> "events_raw_""$core_select""$freq_select"".data" 

	     	#after benchmarks have run kill sensor collect and smartpower (if chosen)
            	sleep 1
            	kill $PID_sensors > /dev/null 2>&1
            	kill $PID_usage > /dev/null 2>&1
            	sleep 1
                
	     	echo "Data collection completed successfully"

            	#Organize results -> copy them in the save dir that is specified or put them in the PWD
            	if (( $SAVE_DIR_CHOSEN )); then
                        mkdir -v -p "$save_dir/Run_$i/""$core_select""$freq_select"
                	echo "Copying results to chosen dir: $save_dir/Run_$i/""$core_select""$freq_select"
                	cp -v "sensors_""$core_select""$freq_select"".data" "usage_"$core_select"$freq_select"".data" "benchmarks_""$core_select""$freq_select"".data" "events_raw_""$core_select""$freq_select"".data" "$save_dir/Run_$i/""$core_select""$freq_select"
                	rm -v "sensors_""$core_select""$freq_select"".data" "usage_"$core_select"$freq_select"".data" "benchmarks_""$core_select""$freq_select"".data" "events_raw_""$core_select""$freq_select"".data"
            	else
			mkdir -v -p "Run_$i/""$core_select""$freq_select"
               		echo "Copying results to dir: Run_$i/""$core_select""$freq_select"
                        cp -v "sensors_""$core_select""$freq_select"".data" "usage_"$core_select"$freq_select"".data" "benchmarks_""$core_select""$freq_select"".data" "events_raw_""$core_select""$freq_select"".data" "Run_$i/""$core_select""$freq_select"
                        rm -v "sensors_""$core_select""$freq_select"".data" "usage_"$core_select"$freq_select"".data" "benchmarks_""$core_select""$freq_select"".data" "events_raw_""$core_select""$freq_select"".data"
            	fi

            done

        done
        echo "$core_select cores done"
    fi
done

#Restore environment
./enviroset.sh 0

echo "Script End! :)"