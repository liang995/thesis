#! /bin/bash
# MiGError CRIU implementation with bash for destination
#1: receive base image;
#2: start VM/container;
# sudo podman load -i ./testimage.tar
# sudo podman run -d --name=dstimage testimage
#3: receive pre-dump from Source;
sleep 3
#4: apply pre-dump;
#5: restore VM/container;
sudo podman container restore --import checkpoint.tar
# sudo criu restore --images-dir /~/home
#6: wait for migrationRequest;
sleep 5
#7: handoffSignalReceived = False;
handoffSignalReceived=0
#8: while handoffSignalReceived == False
while [ $handoffSignalReceived -eq 0 ]
do
    #9: receive memoryDifference;
    #10: apply memoryDifference;
    if [[ ! -f signal ]]
    then
        if [[ -f update ]]
        then
            # sudo criu dump --tree "$containerid" --images-dir ./after \
            # --prev-images-dir ./before --leave-stopped --track-mem
            # #11: restore VM/container;
            # sudo criu restore --images-dir /~/home
            start_time=$(date +%s.%3N)
            sudo podman kill srcimage
            sudo podman rm srcimage
            sudo podman container restore --import-previous pre-checkpoint.tar.gz --import checkpoint.tar
            end_time=$(date +%s.%3N)
            elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
            printf "Before Hand-off migration restore downtime: %s\n" "$elapsed" >> updates_log
            rm update
        fi
    #12: case handoffRequest
    else
        #13: handoffSignalReceived = True
        handoffSignalReceived=1
        #14: do hand-off();
        start_time1=$(date +%s.%3N)
        sudo podman kill srcimage
        sudo podman rm srcimage
        sudo podman container restore --import checkpoint.tar
        end_time1=$(date +%s.%3N)
        elapsed1=$(echo "scale=3; $end_time1 - $start_time1" | bc)
        printf "Hand-off migration restore downtime: %s\n" "$elapsed1" >> handoff_log
    fi
#15: communicate from this edgeNode to UE;
done