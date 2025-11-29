#/bin/sh
if [ "$1" = "" ] | [ "$2" = "" ] | [ "$3" = "" ] | [ "$4" = "" ] | [ "$5" = "" ]; then
    echo "usage: monitor pid skynet_bin_path service_id_in_decimal seconds proj_path"
    exit 1
fi
stap -v mini_lua_bt.stp --skip-badvars -x $1 $2 $3 $4 -g --suppress-time-limits -DMAXSTRINGLEN=65536 | tee a.bt

lua ./dump.lua $5 a.bt | tee b.bt

./flamegraph.pl --fontsize=10 b.bt >skynet.svg
