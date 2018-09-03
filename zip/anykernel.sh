# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=lordarcadius@xda-developers
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=1
device.name1=mido
device.name2=redmi note 4
device.name3=Rendi Nude 4
device.name4=Redmi Note 4
device.name5=Redmi Note 4x
supported.sdk1=27
supported.sdk2=28
'; } # end properties

# shell variables
block=/dev/block/platform/soc/7824900.sdhci/by-name/boot;
is_slot_device=0;
ramdisk_compression=gz;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chmod -R 755 $ramdisk/sbin;
chown -R root:root $ramdisk/*;


## AnyKernel install
dump_boot;

# begin ramdisk changes

# insert init.spectrum.rc in init.rc
insert_line init.rc "import /init.spectrum.rc" after "import /init.trace.rc" "import /init.spectrum.rc";

# end ramdisk changes

write_boot;

## end install

