#!/bin/bash

check_param() {
	local param_value="$1"
	local error_message="$2"
    
	if [ -z "${param_value}" ]; then
		echo "ERROR - ${error_message}" >&2
		exit 1
	fi
}

check_directory() {
	local dir_name="$1"
	local dir_path="$2"
    
	#~ if [ "${dir_path}" != "NA" ] && [ ! -d "${dir_path}" ]; then
	if [ ! -d "${dir_path}" ]; then
		echo "ERROR - ${dir_name} is not a regular directory [${dir_path}]" >&2
		exit 1
	fi
}

check_file() {
	local file_name="$1"
	local file_path="$2"
    
	#~ if [ "${file_path}" != "NA" ] && [ ! -f "${file_path}" ]; then
	if [ ! -f "${file_path}" ]; then
		echo "ERROR - ${file_name} is not a regular file [${file_path}]" >&2
		exit 1
	fi
}

check_job() {
	local ped_dir="$1"
    
    for jobLog in $(find ${ped_dir} -name '*jobID.log'); do 
		for i in $(cut -f 2 $jobLog); do 
			sacct -bn -j ${i} --format="JobID,JobName%60,State"; 
		done
	done
}

check_missing() {
	local file="$1"
	[ ! -f "$file" ] && echo "ERROR : Output missing, expected [$file]" | tee -a "$checkLog"
}

check_cntvar() {
	local cntfile="$1"
	local file="$2"
	local limit="$3"
	local op="$4"   # lt/le/gt/ge

	if [ ! -f "$cntfile" ]; then
		echo "ERROR : Output missing, expected [$cntfile]" | tee -a "$checkLog"
		return
	fi

	local countVar
	countVar=$(<"$cntfile")

	case "$op" in
		le) [ "$countVar" -le "$limit" ] && check_missing "$file" ;;
		lt) [ "$countVar" -lt "$limit" ] && check_missing "$file" ;;
		ge) [ "$countVar" -ge "$limit" ] && check_missing "$file" ;;
		gt) [ "$countVar" -gt "$limit" ] && check_missing "$file" ;;
	esac
}

copy_or_log() {
    local file="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$file" ]; then
        cp "$file" "$dest"
    else
        echo "# INFO - Computationally unavailable file : $name" >> "$dest/expectedNA.log"
    fi
}

check_cntvar_copy() {
    local cntfile="$1"
    local file="$2"
    local dest="$3"
    local name="$4"
    local limit="$5"
    local op="$6"

    [ ! -f "$cntfile" ] && return 0

    local cnt=$(<"$cntfile")

    case "$op" in
        le) [ "$cnt" -le "$limit" ] && copy_or_log "$file" "$dest" "$name" ;;
        lt) [ "$cnt" -lt "$limit" ] && copy_or_log "$file" "$dest" "$name" ;;
        ge) [ "$cnt" -ge "$limit" ] && copy_or_log "$file" "$dest" "$name" ;;
        gt) [ "$cnt" -gt "$limit" ] && copy_or_log "$file" "$dest" "$name" ;;
    esac
}

copy_or_touch() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
	if [ ! -f "$dst" ]; then
        	cp "$src" "$dst"
	fi
    else
        touch "$dst"
    fi
}

has_cntvar_gt0() {
    local file="$1"
    local cntfile="${file}.cntvar"
    [ ! -f "$cntfile" ] && return 1
    local n
    n=$(<"$cntfile")
    [ "$n" -gt 0 ]
}

copy_or_error() {
	if [ ! -f "$stepFile" ]; then
		echo "ERROR : Output missing, expected [$stepFile]" | tee -a ${cleanLog}
	else
		cp "$stepFile" "$stepDest/$stepFname"
	fi
}

move_or_error() {
        if [ ! -f "$stepFile" ]; then
                echo "ERROR : Output missing, expected [$stepFile]" | tee -a ${cleanLog}
        else
                mv "$stepFile" "$stepDest/$stepFname"
        fi
}





