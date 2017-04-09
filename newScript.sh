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
    exec 2>/dev/null
	local return_code=$1
    sudo -u /tmp/loopdir
	rm -rf /tmp/{isofiles,workspace,loopdir}
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
                readonly INPUT=$(realpath $OPTARG)
				;;
			o)
                readonly OUTPUT=$(realpath $OPTARG)
				;;
			p)
                readonly PRESEED=$(realpath $OPTARG)
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
	mkdir /tmp/{loopdir,isofiles,workspace}
    sudo mount -o loop $INPUT /tmp/loopdir
    rsync -a -H --exclude=TRANS.TBL /tmp/loopdir/ /tmp/isofiles
    sleep 1
    sudo umount /tmp/loopdir
    chmod -R u+w /tmp/isofiles
    cd /tmp/workspace
    gzip -d < /tmp/isofiles/install.amd/initrd.gz | cpio --extract --verbose --make-directories --no-absolute-filenames
    cp ${PRESEED} ./preseed.cfg
    find . | cpio -H newc --create --verbose | gzip -9 | tee ../isofiles/install.amd/initrd.gz > /dev/null
    cd ../isofiles
    chmod u+w md5sum.txt
    md5sum `find -follow -type f` > md5sum.txt
    sudo genisoimage -o ${OUTPUT} -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat .
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
