#! /bin/bash
# MiGError CRIU implementation with bash for source
# build busybox test toy image that loops numbers
# busybox /bin/sh -c 'i=0; while true; do echo $i; i=$(expr $i + 1); sleep 1; done' the command inside containerfile
# sudo podman build -t testimage .
# save the image as tar to send over
# sudo podman save -o ./testimage.tar testimage
#1: send base image to Destination (or send from the cloud);
# sudo rsync -av -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/testimage.tar fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
# sleep 5 to give time for the remote server to load and run
sudo podman run -d --name=srcimage testimage
#2: create pre-dump memory snapshots (after tree is pid of the container);
containerid=$(pgrep -f expr)
# sudo criu pre-dump --tree "$containerid" --images-dir ./before
sudo podman container checkpoint srcimage -R --compress=none --export=checkpoint.tar
#3: send pre-dump to Destination;
sudo rsync -av -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/checkpoint.tar fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
#4: wait for migrationRequest;
sleep 5
#5: handoffSignalReceived = False;
handoffSignalReceived=0
#6: while handoffSignalReceived == False
var=3 # when handoff_counter hits this value we will handoff
handoff_counter=0 #the counter that tries to reach var before we handoff
counter=0 #counter for checking when we want to do a update for the destination
do_update=2 # when counter hits this value we will do the update for the destination
start_time=$(date +%s.%3N)
precheckpointname="pre-checkpoint"
endcheckpointname=".tar.gz"
while [ $handoffSignalReceived -eq 0 ]
do
#7: switch (Event)
    if [ $handoff_counter -ne "$var" ]
    then
        #8: case Memory change
        sudo bash -c "echo 4 > /proc/$containerid/clear_refs" #put 4 to reset soft-dirty bit
        #use the pagemap dwks pagemap c program to check any memory change(page writes)
        pagemapcheck=$(sudo ./pagemap2 "$containerid" | grep 'soft-dirty 1')
        #if output is not empty
        if [[ -n "$pagemapcheck" ]]
        then
            #if the counter of memory change is not the same as we want before we do update increment
            #(we don't want to send the mirror too often as that causes too much delay)
            if [[ $counter -ne "$do_update" ]]
            then
                ((++counter))
            else #otherwise we should do the updates
                #9: checkpoint();
                #10: calculate_memory_difference();
                # sudo criu pre-dump --tree "$containerid" --images-dir ./before
                newcheckpointname="$precheckpointname$handoff_counter$endcheckpointname"
                echo $newcheckpointname
                sudo podman container checkpoint -P -e $newcheckpointname srcimage
                #11: send_sync_event();
                sudo rsync -av --log-file=src.log -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/$newcheckpointname fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
                scp -i /home/fedora/.ssh/othervmkey update fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
                counter=0
                ((++handoff_counter))
                # sleep 1.8
            fi
        fi
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
# sudo docker kill srcimage
#16: wait for T seconds then release VM/container
sleep 5
sudo podman rm srcimage