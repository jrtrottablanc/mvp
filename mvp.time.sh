touch ${timeLog}
	
	echo "# INFO - Checking MVPGermline pipeline analysis time [${now}] ..." | tee -a ${timeLog}
	
	echo "# INFO - Analysis folder : [${anaDir}]" | tee -a ${timeLog}
	
	echo "# INFO - Checking analysis time ..." | tee -a ${timeLog}
	for jobLog in $(find ${anaDir} -name '*jobID.log'); do 
		for i in $(cut -f 2 $jobLog); do sacct -j $i --format=Start,End --noheader; done
	done | \
	awk -F 'T| ' '{
	start_time = $1 " " $2; 
	end_time = $3 " " $4; 
	cmd1 = "date -d \"" start_time "\" +%s";
	cmd2 = "date -d \"" end_time "\" +%s";
	cmd1 | getline start_epoch; close(cmd1);
	cmd2 | getline end_epoch; close(cmd2); 
	if (min == "" || start_epoch < min) min = start_epoch;
	if (max == "" || end_epoch > max) max = end_epoch;
	} END {
	elapsed = max - min;
	days = int(elapsed / 86400);
	hours = int((elapsed % 86400) / 3600);
	minutes = int((elapsed % 3600) / 60);
	seconds = elapsed % 60;
	print "First started:", strftime("%Y-%m-%d %H:%M:%S", min);
	print "Last finished:", strftime("%Y-%m-%d %H:%M:%S", max);
	printf "Elapsed time: %d-%02d:%02d:%02d\n", days, hours, minutes, seconds;
	}' | tee -a ${timeLog}
	
	echo "# INFO - Done!" | tee -a ${timeLog}