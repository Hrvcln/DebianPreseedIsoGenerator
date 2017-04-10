#!/bin/bash

rm -rf ./isofiles/*.iso
mkdir loopdir isofiles workspace
sudo mount -o loop iso/debian.iso loopdir
rsync -a -H --exclude=TRANS.TBL loopdir/ isofiles
sleep 1
sudo umount loopdir
chmod -R u+w isofiles
cd workspace
gzip -d < ../isofiles/install.amd/initrd.gz | cpio --extract --verbose --make-directories --no-absolute-filenames
cp /home/ananser/Git/lachose.anatrace.alocal/PEA-Team/Infrastructure/example-preseed.txt ./preseed.cfg
find . | cpio -H newc --create --verbose | gzip -9 | sudo tee ../isofiles/install.amd/initrd.gz > /dev/null
cd ../isofiles
chmod u+w md5sum.txt
md5sum `find -follow -type f` > md5sum.txt
sudo genisoimage -o ../iso/debian-custom-preseed.iso -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat .
