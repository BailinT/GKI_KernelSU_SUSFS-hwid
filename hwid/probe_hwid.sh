#!/system/bin/sh
# HWID probe: dump every place early boot could read a device ID from.
# Run on a WORKING (stock or upstream) kernel, then send the log back.
#   sh /sdcard/probe_hwid.sh
# Root is optional but preferred.

EXPECTED="0x0000044864acd92f"

LOG=/sdcard/hwid_probe.log
: > "$LOG" 2>/dev/null || LOG=/data/local/tmp/hwid_probe.log
: > "$LOG" 2>/dev/null || { echo "cannot write log anywhere"; exit 1; }

out() { echo "$@" >> "$LOG"; }
sec() { out ""; out "=== $* ==="; }

# strip 0x prefix + leading zeros + lowercase, same as kernel hwid_match()
norm() {
	echo "$1" | tr 'A-Z' 'a-z' | sed -e 's/^0x//' -e 's/^0*//'
}

out "HWID probe"
out "time      : $(date 2>/dev/null)"
out "expected  : $EXPECTED  (normalized: $(norm "$EXPECTED"))"
out "id        : $(id 2>/dev/null)"

sec "kernel"
out "$(uname -a 2>/dev/null)"
out "$(cat /proc/version 2>/dev/null)"

sec "/proc/bootconfig  (exists => CONFIG_BOOT_CONFIG=y)"
if [ -e /proc/bootconfig ]; then
	out "PRESENT"
	cat /proc/bootconfig >> "$LOG" 2>&1
else
	out "ABSENT  -> kernel built with CONFIG_BOOT_CONFIG=n, or no bootconfig passed"
fi

sec "/proc/cmdline (raw)"
cat /proc/cmdline >> "$LOG" 2>&1

sec "/proc/device-tree/chosen/bootargs (raw)"
cat /proc/device-tree/chosen/bootargs >> "$LOG" 2>&1 || out "(unreadable)"

sec "matching tokens in cmdline + bootconfig"
{
	tr ' ' '\n' < /proc/cmdline 2>/dev/null
	cat /proc/bootconfig 2>/dev/null
} | grep -iE 'cpuid|chipid|serial|hwid|soc_?id|uid' >> "$LOG" 2>&1 \
	|| out "(NO MATCH -- none of these keys are in the boot parameters)"

sec "per-key extraction"
for KEY in androidboot.cpuid androidboot.chipid androidboot.serialno \
	   androidboot.soc_id oplusboot.serialno; do
	VAL="$(tr ' ' '\n' < /proc/cmdline 2>/dev/null \
		| grep "^${KEY}=" | head -n 1 | cut -d= -f2- | tr -d '"')"
	SRC="cmdline"
	if [ -z "$VAL" ] && [ -e /proc/bootconfig ]; then
		VAL="$(grep -E "^[[:space:]]*${KEY}[[:space:]]*=" /proc/bootconfig 2>/dev/null \
			| head -n 1 | cut -d= -f2- | tr -d ' "')"
		SRC="bootconfig"
	fi
	if [ -n "$VAL" ]; then
		if [ "$(norm "$VAL")" = "$(norm "$EXPECTED")" ]; then
			out "$KEY = $VAL   [$SRC]  ** MATCHES EXPECTED **"
		else
			out "$KEY = $VAL   [$SRC]  (normalized: $(norm "$VAL")) -- differs"
		fi
	else
		out "$KEY = <not found in cmdline or bootconfig>"
	fi
done

sec "getprop ro.boot.* (userspace view -- NOT proof of a boot parameter)"
getprop 2>/dev/null | grep -iE 'ro\.boot\.|ro\.serialno|ro\.soc\.' >> "$LOG" 2>&1

sec "specific props"
for P in ro.boot.cpuid ro.boot.chipid ro.boot.serialno ro.serialno \
	 ro.soc.model ro.boot.hwlevel; do
	out "$P = $(getprop "$P" 2>/dev/null)"
done

sec "/sys/devices/soc0 (Qualcomm SoC registers -- alternative ID source)"
for F in serial_number soc_id chip_family machine hw_platform revision raw_id; do
	[ -r "/sys/devices/soc0/$F" ] && out "$F = $(cat "/sys/devices/soc0/$F" 2>/dev/null)"
done
out "serial_number as hex = $(printf '0x%016x' "$(cat /sys/devices/soc0/serial_number 2>/dev/null || echo 0)" 2>/dev/null)"

out ""
out "=== end ==="

echo "log written to: $LOG"
echo
cat "$LOG"
