#! /bin/bash
# MiGError podman implementation with bash for source
#1: start the base image container;
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
var=3 # totalmigration = some value
do_update=2 # totalchanges = some value
handoff_counter=0 #currentmigrations = 0
counter=0 #currentchanges = 0
start_time=$(date +%s.%3N) #to keep track of the time for evaluation purposes
precheckpointname="pre-checkpoint" #prefix of pre-checkpoint name
endcheckpointname=".tar.gz" #suffix of pre-checkpoint name
while [ $handoffSignalReceived -eq 0 ]
do
#7: while handoffSignalReceived == False and currentmigrations != totalmigrations
    if [ $handoff_counter -ne "$var" ]
    then
        #8: case Memory change
        sudo bash -c "echo 4 > /proc/$containerid/clear_refs" #put 4 to reset soft-dirty bit
        #use the pagemap dwks pagemap c program to check any memory change(page writes)
        pagemapcheck=$(sudo ./pagemap2 "$containerid" | grep 'soft-dirty 1')
        #if there is a memory change
        if [[ -n "$pagemapcheck" ]]
        then
            #if the counter of memory change is not the same as we want before we do update increment
            #(we don't want to send the mirror too often as that causes too much delay)
            if [[ $counter -ne "$do_update" ]] #if currentchanges<totalchanges
            then
                ((++counter))
            else #otherwise we should do the updates
                #pre_checkpoint();
                newcheckpointname="$precheckpointname$handoff_counter$endcheckpointname"
                echo $newcheckpointname
                sudo podman container checkpoint -P -e $newcheckpointname srcimage
                #send_pre_checkpoint();
                sudo rsync -av --log-file=src.log -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/$newcheckpointname fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
                scp -i /home/fedora/.ssh/othervmkey update fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
                counter=0 #currentchanges=0
                ((++handoff_counter)) #currentmigrations+=1
            fi
        fi
    else #9: case handoffRequest
        handoffSignalReceived=1 #handoffSignalReceived = True
        #checkpoint and stop container;
        sudo podman container checkpoint srcimage --print-stats --compress=none --export=checkpoint.tar
        #send checkpoint
        sudo rsync -av --log-file=src.log -e "ssh -i $HOME/.ssh/othervmkey" /home/fedora/checkpoint.tar fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
        scp -i /home/fedora/.ssh/othervmkey signal fedora@sts6440-vm2.cloud.sci.uwo.ca:/home/fedora/
    fi
done
#this is logging for evaluation
end_time=$(date +%s.%3N)
elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
printf "Migration Time: %s" "$elapsed" >> total_time
#10: wait for T seconds then release VM/container
sleep 5
sudo podman rm srcimage