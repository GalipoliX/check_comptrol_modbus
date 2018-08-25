
#!/bin/bash
#################################################################################
# Script:       check_comptrol_modbus
# Author:       Michael Geschwinder (Maerkischer-Kreis)
# Description:  Plugin for Nagios to check a Stulz Comptrol
#               device via Modbus.
# History:
# 20180104      Created plugin
#################################################################################
# Usage:        ./check_comptrol_modbus -H host
#################################################################################

help="check_comptrol_modbus (c) 2018 Michael Geschwinder published under GPL license
\nUsage: ./check_comptrol_modbus -H host [-w warning] [-c critical]
\nRequirements: modbtget, awk, sed\n
\nOptions: \t-H hostname \t-t type\n"

##########################################################
# Nagios exit codes and PATH
##########################################################
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
PATH=$PATH:/usr/local/bin:/usr/bin:/bin # Set path


##########################################################
# Debug Ausgabe aktivieren
##########################################################
DEBUG=0

##########################################################
# Debug output function
##########################################################
function debug_out {
        if [ $DEBUG -eq "1" ]
        then
                datestring=$(date +%d%m%Y-%H:%M:%S)
                echo -e $datestring DEBUG: $1
        fi
}

###########################################################
# Check if programm exist $1
###########################################################
function check_prog {
        if ! `which $1 1>/dev/null`
        then
                echo "UNKNOWN: $1 does not exist, please check if command exists and PATH is correct"
                exit ${STATE_UNKNOWN}
        else
                debug_out "OK: $1 does exist"
        fi
}

############################################################
# Check Script parameters and set dummy values if required
############################################################
function check_param {
        if [ ! $host ]
        then
                echo "No Host specified... exiting..."
                exit $STATE_UNKNOWN
        fi
        if [ ! $type ]
        then
                echo "No type specified... exiting..."
                exit $STATE_UNKNOWN
        fi
}



############################################################
# Get modbus Value
############################################################
function get_modbus {
        register=$1
        ret=$(modbtget -H $host -f 3 -s $register)
        if [ $? == 1 ]
        then
                exit $STATE_UNKNOWN
        else
                echo $ret
        fi
}

#################################################################################
# Display Help screen
#################################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit $STATE_UNKNOWN;
fi

################################################################################
# check if requiered programs are installed
################################################################################
for cmd in modbtget awk sed;do check_prog ${cmd};done;

################################################################################
# Get user-given variables
################################################################################
while getopts "H:t:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       t)      type=${OPTARG};;
       *)      echo "Wrong option given. Please use options -H for host, -w for warning and -c for critical"
               exit 1
               ;;
       esac
done

debug_out "Host=$host, type=$type"

check_param

maxtemp="27"
warn_offset="3"
crit_offset="5"

status=$(get_modbus 1)
opmode=$(get_modbus 2)
fanlevel=$(get_modbus 3)
position=$(get_modbus 4)
setpoint=$(get_modbus 5)
actvalue=$(get_modbus 6)
error=$(get_modbus 12)



#################################################################################
# Switch Case for different check types
#################################################################################
case ${type} in

state)

        case ${status} in
        0)
                echo "Betriebsstatus: Aus"
                echo "Error: E$error"
                exit $STATE_CRITICAL
        ;;
        1)
                echo "Betriebsstatus: An"
                echo "Error: E$error"
                if [ ! "$error" == "0" ]
                then
                        echo "https://www.s-klima.de/unterstuetzung/fehlercode-analyse/"
                        exit $STATE_CRITICAL
                fi
        ;;
        esac
;;

mode)
        case ${opmode} in
        0)
                echo "Betriebsmodus: Auto"
        ;;
        1)
                echo "Betriebsmodus: Heizen"
                crit=true
        ;;
        2)
                echo "Betriebsmodus: Entfeuchten"
                crit=true
        ;;
        3)
                echo "Betriebsmodus: Lueften"
                crit=true
        ;;
        4)
                echo "Betriebsmodus: Kuehlen"
        ;;
        esac


        case ${fanlevel} in
        1)
                echo "Luefterstufe: Niedrig"
        ;;
        2)
                echo "Luefterstufe: Mittel"
        ;;
        3)
                echo "Luefterstufe: Hoch"
        ;;
        4)
                echo "Luefterstufe: Ultra Hoch"
        ;;
        esac

        case ${position} in
        1)
                echo "Pendellamellen: Position 1"
        ;;
        2)
                echo "Pendellamellen: Position 2"
        ;;
        3)
                echo "Pendellamellen: Position 3"
        ;;
        5)
                echo "Pendellamellen: Position 4"
        ;;
        10)
                echo "Pendellamellen: schwingen"
        ;;
        esac

        if [ $crit ]
        then
                exit $STATE_CRITICAL
        fi

;;


temp)

        setpoint=$(echo "$setpoint * 0.1" | bc)
        actvalue=$(echo "$actvalue * 0.1" | bc)
        temp=${actvalue%.*}
        perf="| sollwert=${setpoint} istwert=${actvalue}"
        echo "Istwert: $actvalue C° Sollwert: $setpoint C° $perf"

        warntemp=$(echo "($setpoint + $warn_offset)/1" | bc)

        crittemp=$(echo "($setpoint + $crit_offset)/1" | bc)

        debug_out "warning at $warntemp    critical at $crittemp    or $maxtemp"

        if [ $temp -ge $maxtemp ] || [ $temp -ge $crittemp ]
        then
                exit $STATE_CRITICAL
        elif [ $temp -ge $warntemp ]
        then
                exit $STATE_WARNING
        else
                exit $STATE_OK
        fi
;;

esac
exit $STATE_UNKNOWN
