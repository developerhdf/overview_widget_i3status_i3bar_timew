#!/bin/bash
#
# MIT License
#
# Copyright (c) 2017 Richard
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# README
#
# Getting it to run:
#
# Make sure you have timew, i3 and i3status installed on your machine. Also, 
# this script reports on battery status as I am using a laptop at present. If 
# neither the timew nor battery monitoring is required, comment out the relevant
# sections. In your i3 config, comment out the line 
# 'status_command i3status'
# and replace it with:
# 'status_command exec ~/path_to_script/script_name.sh'
#
#
# Please note:
#
# I am aware there must be better ways to do much of what this script does. That
# is why I released it as open source software - anyone can hack at it and I 
# hope some of those that do will share their improvements with me, even though 
# the license does not require it. I had an idea for the kind of widget I wanted 
# to run next to the clock in i3bar and then used Google to implement it. 

# What follows, therefore, is not remotely close to professional bash scripting 
# or even good programming practice. Consider this alpha software that does what
# the author intended it to do, without any considerations for security,
# performance or good programming practice.
#
# This script relies on timew being installed on the computer it is run on.
# Also, I am using a laptop so it monitors my battery level which might produce 
# errors on computers without batteries. If time/task and battery monitoring is
# not required, please comment out the relevant code. I wrote the script on Arch 
# Linux and am not aware of any other "dependencies", but should any be 
# discovered I will greatly appreciate being notified of the fact.
#
# Richard

# TODO
# scroll on timew details to select previous tasks to track next
# interact with battery low to present power off option
# interaction with widget to launch top
# volume with scroll to increase/decrease

# Crude (unchecked) instructions to add widget elements:
# To add an entry, create its relevate variables globally, write updateX and
# constructX methods and add the entry to updateData, updateMyWidget and 
# constructSummary updateX will update the data pertaining to the entry,
# constructX will create the json for i3bar

#GLOBAL CONSTANTS
colourFine='#a5ff2e'
colourWarn='#ff952e'
colourDanger='#ff2e31'
colourInfo='#2e7fff'
colourYellow='#f6ff2e'
colourNeutral='#969696'
colourBarBackground='#000000'

#Global variables and functions
showSystemStats=false
cpuStrain=false
ramStrain=false
temperatureStrain=false
systemResourceStrain=false
system_state_summary=''
system_state_summary_spacing=0
time_tracking_info=''
i3barInput=''
i3statusOutput=''
i3barOutput=''
skipDataUpdate=false

writeToLog() {
  if [ "$#" = 2 ]
  then
    $(echo $1 >> $2)
  else
    if [ "$#" = 1 ]
    then
      $(echo $1 >> ~/overview_widget.log)
    fi
  fi
}

resetVariables() {
  cpuStrain=false
  ramStrain=false
  temperatureStrain=false
  systemResourceStrain=false
}

updateStrainState() {
  if [ "$cpuStrain" = true ] && [ "$ramStrain" = true ] && [ "$temperatureStrain" = true ]
  then
    systemResourceStrain=true
  else
    systemResourceStrain=false
  fi
}

switchSystemStats() {
  if [ "$showSystemStats" = true ]
  then
    showSystemStats=false
  else
    showSystemStats=true
  fi
}

updateData() {
  if [ "$skipDataUpdate" = false ]
  then
    resetVariables
    updateTemperatureData
    updateBatteryData
    updateCpuData
    updateMemoryData
    updateDiskData
    updateWifiData
    updateVolumeData
    updateTimewData
    constructT
    constructB
    constructC
    constructR
    constructS
    constructD
    constructW
    constructV
    constructTimew
    updateProcessData
  fi
  constructProcessView
  constructSummary
}

constructSummary() {
  system_state_summary=$tw$processInfoJSON$T$C$R$S$D$B$W$V
}

updateMyWidget() {
  if [ "$#" = 1 ]
  then
    i3statusOutput=$1
  else
    read i3statusOutput <&3
  fi
  updateData  
  i3barInput=$(sed -r "s/^(,\[|\[)(\{)(.*)/\1$system_state_summary\2\3/g" <<< $i3statusOutput)
}

i3barUpdate() {
  if [ "$#" = 1 ]
  then
    i3barInput=$1
  fi
  echo $i3barInput
  #writeToLog "$i3statusOutput"
}

i3statusCapture() {
  exec 3< <(i3status)
}

i3barProcessHeader() {
  # read entry describing version and click events to i3bar
  read i3statusOutput <&3
  # enable click events
  modifiedOutput=$(sed -r 's/^(\{"version":1)(\})/\1,"click_events":true\2/g' <<< $i3statusOutput) 
  i3barUpdate "$modifiedOutput"
  # read entry opening the infinite array
  read i3statusOutput <&3
  i3barUpdate "$i3statusOutput"
  updateMyWidget
  i3barUpdate
  i3statusOutput=$(sed -r "s/^(\[.*)/,\1/g" <<< $i3statusOutput)
}

drawMyWidget() {
  local skipWidgetRefresh=0
  local sleepDuration=0
  local i3bar_output=0
  local i3status_output=0
  while true
  do
    skipWidgetRefresh=false
    skipDataUpdate=false
    sleepDuration=0
    unset i3bar_output
    unset i3status_output
    #Handle i3bar output
    read -t 0
    if [ $? == 0 ]
    then
      read i3bar_output
      i3barOutput=$i3bar_output
      local clickEventData=( $(sed -r 's/[{}:,"]+/ /g'<<< "$i3bar_output" | awk '{print $2" "$4" "$6}') )
      if [ "${#clickEventData[@]}" = 3 ]
      then
        case "${clickEventData[0]}" in
          system) case "${clickEventData[2]}" in
                    3) switchProcessView;;
                    2) ;& # fallthrough
                    1) switchSystemStats;;
                    *) skipWidgetRefresh=true;;    
                  esac;;
          process_dialog) case "${clickEventData[2]}" in                            
                            4)  upProcess
                                skipDataUpdate=true;;
                            5)  downProcess
                                skipDataUpdate=true;;
                            1) if [ "${clickEventData[1]}" = "kill_button" ]
                                then
                                  killFocusedProcess
                                  switchProcessView
                                fi;;
                            *) skipWidgetRefresh=true;;
                          esac;;
          time_tracker) case "${clickEventData[2]}" in
                    3) toggleTimew
                        skipDataUpdate=true;;
                    2) ;& # fallthrough
                    1) switchTimewView;;
                    *) skipWidgetRefresh=true;;    
                  esac;;
          *) skipWidgetRefresh=true;;
        esac
      else
        skipWidgetRefresh=true
        sleepDuration=0.1
      fi
    else
      sleepDuration=0.1
      #Handle i3status output
      read -t 0 <&3
      if [ $? == 0 ]      
      then
        read i3status_output <&3
        i3statusOutput=$i3status_output
      else
        sleepDuration=0.2
        skipWidgetRefresh=true
      fi
    fi
    
    if [ "$skipWidgetRefresh" = false ]
    then
      updateMyWidget "$i3statusOutput"
      i3barUpdate
    fi
    sleep "$sleepDuration"
  done
}

#Temperature related variables & functions
temperatureVal=0
temperatureThresholdD=$(cat /sys/class/hwmon/hwmon0/temp1_crit | awk '{print $1/1000 - 10}')
temperatureThresholdW=$(($temperatureThresholdD - 10))
temperatureUnit='°C'
temperatureLabel='T'
T=''

updateTemperatureData() {
  temperatureVal=$(cat /sys/class/hwmon/hwmon0/temp1_input | awk '{print $1/1000}')
}

constructT() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='temperature'
  local entryDisplay=$temperatureLabel    
  if (( $(bc -l <<< "$temperatureVal>=$temperatureThresholdD") ))
  then
    entryColour=$colourDanger
    temperatureStrain=true
  elif (( $(bc -l <<< "$temperatureVal>=$temperatureThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    T='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $temperatureVal)$temperatureUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    T='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#Battery related variables & functions
batteryData=''
batteryPercentage=0
batteryState=''
batteryThresholdD=10
batteryThresholdW=99
batteryUnit='%'
batteryLabel=''
B=''

updateBatteryData() {
  batteryData=$(upower -i $(upower -e | grep 'BAT') | grep -E 'percentage|state' | sed -r 's/[ ]+([a-z]+)[^a-z0-9]+([-a-z0-9]+).*/Battery \1: \2/g')
  batteryPercentage=$(grep 'percentage:' <<< $batteryData | awk '{print $NF}')
  batteryState=$(grep 'state:' <<< $batteryData | awk '{print $NF}')
}

constructB() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='battery'  
  if [ "$batteryState" != "discharging" ]
  then
    batteryLabel='A'
  else
    batteryLabel='B'
  fi
  local entryDisplay=$batteryLabel
  if (( $(bc -l <<< "$batteryPercentage<=$batteryThresholdD") ))
  then
    entryColour=$colourDanger
  elif (( $(bc -l <<< "$batteryPercentage<=$batteryThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    B='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $batteryPercentage)$batteryUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    B='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#CPU related variables & functions
cpuCores=$(nproc)
cpuPercentage=0
cpuThresholdD=90
cpuThresholdW=70
cpuUnit='%'
cpuLabel='C'
C=''

updateCpuData() {
  cpuPercentage=$(uptime | awk '{print $(NF-2)*100/'$cpuCores'}' | sed -r 's/,//g')
}

constructC() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='cpu'
  local entryDisplay=$cpuLabel
  if (( $(bc -l <<< "$cpuPercentage>=$cpuThresholdD") ))
  then
    entryColour=$colourDanger
    cpuStrain=true
  elif (( $(bc -l <<< "$cpuPercentage>=$cpuThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    C='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $cpuPercentage)$cpuUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    C='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#Memory variables and update function
memoryData=''
ramPercentage=0
swapPercentage=0
ramThresholdD=90
ramThresholdW=80
swapThresholdD=50
swapThresholdW=1
memUnit='%'
ramLabel='R'
swapLabel='S'
R=''
S=''

updateMemoryData() {
  memoryData=$(free | grep -E "Mem|Swap" | awk '{print $1" "(1-$NF/$2)*100}')
  ramPercentage=$(grep 'Mem' <<< $memoryData | sed -r 's/[^0-9\.]//g')
  swapPercentage=$(grep 'Swap' <<< $memoryData | sed -r 's/[^0-9\.]//g')
}

#RAM functions
constructR() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='ram'
  local entryDisplay=$ramLabel
  if (( $(bc -l <<< "$ramPercentage>=$ramThresholdD") ))
  then
    entryColour=$colourDanger
    ramStrain=true
  elif (( $(bc -l <<< "$ramPercentage>=$ramThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    R='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $ramPercentage)$memUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    R='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#SWAP functions
constructS() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='swap'
  local entryDisplay=$swapLabel
  if (( $(bc -l <<< "$swapPercentage>=$swapThresholdD") ))
  then
    entryColour=$colourDanger
  elif (( $(bc -l <<< "$swapPercentage>=$swapThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    S='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $swapPercentage)$memUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    S='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#Disk usage variables and functions
diskGigsAvailable=0
diskThresholdD=40
diskThresholdW=100
diskUnit='GB'
diskLabel='D'
D=''

updateDiskData() {
  diskGigsAvailable=$(df ~ | grep /dev/ | awk '{print $4/1024/1024}')
}

constructD() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='disk'
  local entryDisplay=$diskLabel
  if (( $(bc -l <<< "$diskGigsAvailable<=$diskThresholdD") ))
  then
    entryColour=$colourDanger
  elif (( $(bc -l <<< "$diskGigsAvailable<=$diskThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    D='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $diskGigsAvailable)$diskUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    D='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#Wifi variables and functions
wifiNetworkInterface=''
wifiSignalStrength=0
wifiThresholdD=1
wifiThresholdW=50
wifiUnit='%'
wifiLabel='W'
W=''

updateWifiData() {
  wifiNetworkInterface=$(cat /proc/net/wireless | grep -E "^[a-zA-Z0-9]+:" | sed -r 's/(^[a-zA-Z0-9]+).*/\1/')
  if [ "$wifiNetworkInterface" = "" ]
  then
    wifiSignalStrength=0
  else
    wifiSignalStrength=$(iwconfig $wifiNetworkInterface | grep Quality | sed -r 's/[^=]+=[ ]*([0-9]+)\/([0-9]+).*/\1\/\2*100/')
    wifiSignalStrength=$(bc -l <<< "scale=2; $wifiSignalStrength")
  fi
}

constructW() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='wifi'
  local entryDisplay=$wifiLabel
  if (( $(bc -l <<< "$wifiSignalStrength<=$wifiThresholdD") ))
  then
    entryColour=$colourDanger
  elif (( $(bc -l <<< "$wifiSignalStrength<=$wifiThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    W='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $wifiSignalStrength)$wifiUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    W='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#Volume variables and functions
volumeMuted=false
volumeLevel=0
volumeThresholdD=85
volumeThresholdW=70
volumeUnit='%'
volumeLabel='V'
V=''

updateVolumeData() {
  local volArray=( $(amixer sget Master | grep "%" | awk '{print $(NF-1)" "$NF}' | sed -r 's/[]\[%]+//g') )
  local volArrLength=${#volArray[@]}
  local maxVol=0
  local muted=true
  for ((i=0;i<$volArrLength;i++))
  do
    if (($i % 2 == 0 && ${volArray[$i]} > $maxVol))
    then
      maxVol=${volArray[$i]}
    elif (($i % 2 == 1))
    then
      if [ "${volArray[$i]}" = "on" ] && [ "$muted" = true ]
      then
        muted=false
      fi
    fi
  done
  volumeMuted=$muted
  volumeLevel=$maxVol
}

constructV() {
  local entryColour=$colourFine
  local entryName='system'
  local entryInstance='volume'
  if [ "$volumeMuted" = true ]
  then
    volumeLabel='m'
  else
    volumeLabel='V'
  fi
  local entryDisplay=$volumeLabel
  if (( $(bc -l <<< "$volumeLevel>=$volumeThresholdD") ))
  then
    entryColour=$colourDanger
  elif (( $(bc -l <<< "$volumeLevel>=$volumeThresholdW") ))
  then
    entryColour=$colourWarn
  fi
  if [ "$showSystemStats" = true ]
  then
    V='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},{"name":"'$entryName'","instance":"'$entryInstance'_value","markup":"none","full_text":"'$(printf '%.*f\n' 0 $volumeLevel)$volumeUnit'","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  else
    V='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":"'$entryDisplay'","color":"'$entryColour'","separator":false,"separator_block_width":'$system_state_summary_spacing'},'
  fi
}

#process variables and functions
numProcesses=3
topFiveProcessesData=0
processNames=0
processPIDs=0
processC=0
processM=0
processIndex=0
processInfoJSON=''
processInfoSpacing=10
showProcessView=false

updateProcessData() {
  updateStrainState
  if [ "$systemResourceStrain" = true ] && [ "$showProcessView" == true ]
  then
    topFiveProcessesData=$(ps -eo pid,cmd,%cpu,%mem --sort=-%cpu,-%mem | head -n $(($numProcesses + 1)) | tail -n $(($numProcesses)))
    processNames=( $(awk '{print $2}' <<< "$topFiveProcessesData" | awk -F  "/" '{print $NF}') )
    processPIDs=( $(awk '{print $1}' <<< "$topFiveProcessesData") )
    processC=( $(awk '{print $(NF-1)}' <<< "$topFiveProcessesData") )
    processM=( $(awk '{print $NF}' <<< "$topFiveProcessesData") )
  else
    hideProcessView
  fi
}

upProcess() {
  if (($processIndex > 0))
  then
    processIndex=$(($processIndex-1))
  fi
}

downProcess() {
  if (($processIndex < ($numProcesses - 1)))
  then
    processIndex=$(($processIndex+1))
  fi
}

constructProcessView() {  
  if [ "$showProcessView" == true ]
  then
  processInfoJSON='{"name":"process_dialog","instance":"icon","markup":"none","full_text":"!","background":"'$colourDanger'","color":"'$colourBarBackground'","border":"'$colourDanger'","separator":false,"separator_block_width":0},{"name":"process_dialog","instance":"details","markup":"none","full_text":" '$(($processIndex + 1))' '${processNames[$processIndex]}' CPU '${processC[$processIndex]}'% MEM '${processM[$processIndex]}'% ","color":"'$colourDanger'","border":"'$colourDanger'","separator":false,"separator_block_width":0},{"name":"process_dialog","instance":"kill_button","markup":"none","full_text":" kill ","background":"'$colourDanger'","color":"'$colourBarBackground'","border":"'$colourDanger'","separator":false,"separator_block_width":'$processInfoSpacing'},'
  fi
}

hideProcessView() {
  if [ "$processInfoJSON" != "" ]
  then
    processInfoJSON=''
  fi
  showProcessView=false
}

switchProcessView() {
  if [ "$showProcessView" = true ]
  then
    showProcessView=false
  else
    showProcessView=true
  fi
}

killFocusedProcess() {
  kill ${processPIDs[$processIndex]}
}

#Timew widget
timewData=''
timewTracking=false
timewTasks=''
timewTotal=''
timewLabel='⧗'
timewShowDetails=false
tw=''

updateTimewData() {
  timewData=$(timew)
  local testState=$(grep "no active" <<< "$timewData")
  if [[ $testState = '' ]]
  then
    timewTracking=true
    timewTasks=$(grep "Tracking" <<< "$timewData" | sed -r 's/^Tracking //' | sed -r "s/\"/'/g" | sed -r "s/\&/\\\&/g")
    timewTotal=$(tail -n 1 <<< "$timewData" | awk '{print $NF}')
  else
    timewTracking=false
    if [[ $timewTasks = '' ]]
    then
      timewTasks=$(timew export | tail -n 2 | head -n 1 | sed -r 's/.*:\[(.*)\]\}/\1/' | sed -r "s/(\",\")/' '/g" | sed -r "s/\"/'/"g | sed -r "s/\&/\\\&/g")
    fi
  fi
}

constructTimew() {
  local entryName='time_tracker'
  local entryInstance='icon'
  local entryDisplay=$timewLabel
  local entryColour=$colourNeutral
  local entryAdditionalInfo=''
  local timewSpacing=10
  if [[ $timewTracking = true ]]
  then
    entryColour=$colourInfo
    entryAdditionalInfo=$timewTasks' '$timewTotal
  else
    entryAdditionalInfo='Last tracked: '$timewTasks
  fi
  if [[ $timewShowDetails = true ]]
  then
    tw='{"name":"'$entryName'","instance":"'$entryInstance'_details","markup":"none","full_text":" '$entryAdditionalInfo' ","color":"'$entryColour'","border":"'$entryColour'","separator":false,"separator_block_width":0},{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":" '$entryDisplay' ","color":"'$colourBarBackground'","background":"'$entryColour'","separator":false,"separator_block_width":'$timewSpacing'},'
  else
    tw='{"name":"'$entryName'","instance":"'$entryInstance'","markup":"none","full_text":" '$entryDisplay' ","color":"'$entryColour'","separator":false,"separator_block_width":'$timewSpacing'},'
  fi
}

switchTimewView() {
  if [[ $timewShowDetails = true ]]
  then
    timewShowDetails=false
  else
    timewShowDetails=true
  fi
}

toggleTimew() {
  updateTimewData
  if [[ $timewTracking = true ]]
  then
    $(timew stop)
  else
    $(timew continue)
  fi
  #timewShowDetails=false
  updateTimewData
  constructTimew
}

#Script execution starts here
i3statusCapture
i3barProcessHeader
drawMyWidget
