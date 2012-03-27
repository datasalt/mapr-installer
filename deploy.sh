#!/bin/bash

if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
    echo "args: [cluster_name] [master|slaves] [install|config-hadoop|config-snappy|config-thrift|run-script|stop|start|restart] [OPTIONAL_SCRIPT]"
    exit 1
fi

cluster_name=$1
master_or_slaves=$2
operation=$3
script=$4



user=`whoami`
all_hosts_public="cut -f3 $HOME/.whirr/$cluster_name/instances"
all_hosts_private="cut -f4 $HOME/.whirr/$cluster_name/instances"
num_hosts=`$all_hosts_public | wc -l`
master_public=`${all_hosts_public} | head -1`
master_private=`${all_hosts_private} | head -1`
num_slaves=`echo $num_hosts - 1 | bc`
slaves_public=`$all_hosts_public | tail -${num_slaves}`

SSH_OPTIONS="-i /home/$user/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
echo $SSH_OPTIONS
echo Num hosts:$num_hosts
echo Num slaves: $num_slaves
echo Master publicIP: $master_public

echo Slaves public: $slaves_public
echo "Copying master script to  $master_host"


if [ $master_or_slaves = "master" ]; then
  if [ $operation = "run-script" ]; then 
    #scp $SSH_OPTIONS $script ${master_public}:
    cat $script
    cat $script | ssh $SSH_OPTIONS $master_public &
  else 
    scp $SSH_OPTIONS common.sh set_in_mapred.rb ${master_public}:
    ssh $SSH_OPTIONS $master_public bash ./common.sh $user $master_private "master" $operation
    #scp $SSH_OPTIONS /usr/lib/hadoop/lib/native/Linux-amd64-64/lib* $slave_host:
    #ssh $SSH_OPTIONS $slave_host sudo cp lib* /opt/mapr/hadoop/hadoop-0.20.2/lib/native/Linux-amd64-64/
    #ssh $SSH_OPTIONS $slave_host sudo cp lib* /usr/lib
  fi
elif [ $master_or_slaves = "slaves" ]; then
  for slave_host in $slaves_public
  do
  if [ $operation = "run-script" ]; then 
    #scp $SSH_OPTIONS $script ${master_public}:
    #ssh $SSH_OPTIONS $master_public bash ./$script &
    cat $script | ssh $SSH_OPTIONS $slave_host &
  else 
    echo "Copying slave scripts to  $slave_host"
    scp $SSH_OPTIONS common.sh set_in_mapred.rb $user@${slave_host}: 
    ssh $SSH_OPTIONS $slave_host bash ./common.sh $user $master_private "slave" $operation &
    #scp $SSH_OPTIONS /usr/lib/hadoop/lib/native/Linux-amd64-64/lib* $slave_host:
    #ssh $SSH_OPTIONS $slave_host sudo cp lib* /opt/mapr/hadoop/hadoop-0.20.2/lib/native/Linux-amd64-64/
    #ssh $SSH_OPTIONS $slave_host sudo cp lib* /usr/lib

  fi
  done
else 
  echo "Unknown host_type $master_or_slave"
  exit -1
fi



