#! /bin/bash
# MiGError CRIU implementation with bash for source
#1: send base image to Destination (or send from the cloud);
sudo podman run -d --name=srcimage testimage
#2: create pre-dump memory snapshots (after tree is pid of the container);
sudo podman container checkpoint srcimage -R --compress=none --export=checkpoint.tar
#3: send pre-dump to Destination;
sudo rsync -av -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/checkpoint.tar fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
sleep 5 #to give time for the remote server to load and run
#4: wait for migrationRequest;
sleep 5
#5: handoffSignalReceived = False;
handoffSignalReceived=0
#6: while handoffSignalReceived == False
var=3 # when handoff_counter hits this value we will handoff
handoff_counter=0 #the counter that tries to reach var before we handoff
start_time=$(date +%s.%3N)
precheckpointname="pre-checkpoint"
endcheckpointname=".tar.gz"
while [ $handoffSignalReceived -eq 0 ]
do
#7: switch (Event)
    if [ $handoff_counter -ne "$var" ]
    then
        #pre copy so time-gated to do updates, we will do every 2 seconds here
        sleep 2
        #9: checkpoint();
        #10: calculate_memory_difference();
        newcheckpointname="$precheckpointname$handoff_counter$endcheckpointname"
        sudo podman container checkpoint -P -e $newcheckpointname srcimage
        #11: send_sync_event();
        sudo rsync -av --log-file=src.log -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/$newcheckpointname fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
        ((++handoff_counter))
#12: case handoffRequest
    else
#13: handoffSignalReceived = True
        handoffSignalReceived=1
#14: do hand-off();
        sudo podman container checkpoint srcimage --print-stats --compress=none --export=checkpoint.tar
        sudo rsync -av --log-file=src.log -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/checkpoint.tar fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
        scp -i /home/fedora/.ssh/othervmkey signal fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
    fi
done
end_time=$(date +%s.%3N)
elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
printf "Migration Time: %s" "$elapsed" >> total_time
#15: stop VM/container; (we use kill as we are running on detached mode)
#16: wait for T seconds then release VM/container
sleep 5
sudo podman rm srcimage