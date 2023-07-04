#! /bin/bash
# MiGError CRIU implementation with bash for destination
#1: receive base image;
#2: start VM/container;
sleep 3 # to give time when being called for the source to send the image over here
# sudo podman load -i ./testimage.tar
# sudo podman run -d --name=dstimage testimage
#3: receive pre-dump from Source;
#4: apply pre-dump;
#5: restore VM/container;
# containerid=$(pgrep -f runc)
# sudo criu dump --tree "$containerid" --images-dir ./after \
# --prev-images-dir /~/home/before --leave-stopped --track-mem
sudo podman container restore --import checkpoint.tar
# sudo criu restore --images-dir /~/home
#6: wait for migrationRequest;
sleep 5
#7: handoffSignalReceived = False;
handoffSignalReceived=false
newcontainername="srcimage"
basecheckpointname="pre-checkpoint"
endcheckpointname=".tar.gz"
i=1
counter=0
#8: while handoffSignalReceived == False
while [ $handoffSignalReceived == false ]
do
    #9: receive memoryDifference;
    #10: apply memoryDifference;
    if [[ ! -f signal ]]
    then
        if [[ counter -ne 3 ]]
        # if [[ -f update ]]
        then
            # sudo criu dump --tree "$containerid" --images-dir ./after \
            # --prev-images-dir ./before --leave-stopped --track-mem
            # #11: restore VM/container;
            # sudo criu restore --images-dir /~/home
            # echo "got here"
            newcontainername1="$newcontainername$i"
            prevcheckpointname="$basecheckpointname$counter$endcheckpointname" #added
            if [[ -f "$prevcheckpointname" ]] #added
            then #added
                start_time=$(date +%s.%3N)
                # sudo podman container restore --name $newcontainername1 --import-previous pre-checkpoint.tar.gz --import checkpoint.tar
                sudo podman container restore --name $newcontainername1 --import-previous $prevcheckpointname --import checkpoint.tar
                end_time=$(date +%s.%3N)
                elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
                printf "Before Hand-off migration restore downtime: %s\n" "$elapsed" >> updates_log
                # rm update
                ((++i))
                ((++counter))
            fi
        fi
    #12: case handoffRequest
    else
        #13: handoffSignalReceived = True
        handoffSignalReceived=true
        #14: do hand-off();
        start_time1=$(date +%s.%3N)
        newcontainername1="$newcontainername$i"
        sudo podman container restore --name $newcontainername1 --import checkpoint.tar
        end_time1=$(date +%s.%3N)
        elapsed1=$(echo "scale=3; $end_time1 - $start_time1" | bc)
        printf "Hand-off migration restore downtime: %s\n" "$elapsed1" >> handoff_log
    fi
#15: communicate from this edgeNode to UE;
done