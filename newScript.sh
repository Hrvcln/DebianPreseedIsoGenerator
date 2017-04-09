#!/bin/bash

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

usage() {
	cat <<- EOF
	Usage: $PROGNAME -i/--input <ISO à modifier> -o/--output <ISO de sortie> -p/--preseed-file <Fichier preseed>

	<Description>

	Options:
	-i --input              Fichier ISO à modifier.
	-o --output             Fichier ISO de sortie.
	-p --preseed-file       Fichier preseed à insérer dans l'iso défini en '--input'.
	-a --autostart          Définir si l'installation preseed doit se lancer automatiquement au chargement de l'ISO
	-h --help               Afficher cette aide

	Examples:
	Run all tests:
	$PROGNAME --test all
	EOF
}

clean_exit() {
	local return_code=$1
	fusermount -u /tmp/isofiles
	rm -rf /tmp/isofiles
	exit $return_code
}

is_fuseiso_installed() {
	dpkg -s fuseiso >/dev/null 2>&1
	return $?
}

cmdline() {
	local arg=
	for arg
	do
		local delim=""
		case "$arg" in
			--input)          args="${args}-i ";;
			--output)         args="${args}-o ";;
			--preseed-file)   args="${args}-p ";;
			--auto-start)     args="${args}-a ";;
			--help)           args="${args}-h ";;
			*) [[ "${arg:0:1}" == "-" ]] || delim="\""
				args="${args}${delim}${arg}${delim} ";;
		esac
	done

	eval set -- $args

	while getopts "i:o:p:ah" OPTION
	do
		case $OPTION in
			i)
				readonly INPUT=$OPTARG
				;;
			o)
				readonly OUTPUT=$OPTARG
				;;
			p)
				readonly PRESEED=$OPTARG
				;;
			a)
				readonly AUTOSTART=true
				;;
			h)
				usage
				exit 0
				;;
		esac
	done

	if [ -z ${INPUT} ]; then echo "--input parameter is not defined, abort";usage && clean_exit 1;fi
	if [ -z ${OUTPUT} ]; then echo "--output parameter is not defined, abort";usage && clean_exit 1;fi
	if [ -z ${PRESEED} ]; then echo "--preseed-file is not defined, abort";usage && clean_exit 1;fi
	if [ -z ${AUTOSTART} ]; then readonly AUTOSTART=false;fi

	return 0
}

is_file() {
    local file=$1

    [[ -f $file ]]
}


is_input_valid() {
	is_file $INPUT || { echo "--input parameter is not a valid file, abort"; clean_exit 1; }	
}

is_output_valid() {
	! is_file $OUTPUT || { echo "--output parameter already exist, abort"; clean_exit 1; }
}

is_preseed_valid() {
	is_file $PRESEED || { echo "--preseed parameter is not a valid file, abort"; clean_exit 1; }
}

task() {
	mkdir /tmp/isofiles
	fuseiso $INPUT /tmp/isofiles
}

main() {
	cmdline $ARGS
	is_input_valid
	is_output_valid
	is_preseed_valid

	task

	clean_exit 0
}

main
