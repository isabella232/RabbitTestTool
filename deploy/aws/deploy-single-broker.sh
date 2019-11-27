#!/bin/bash

echo "---------------------------"
echo "Deploy single broker with args:"
AMI="$1"
echo "AMI=$AMI"
BROKER_VERSION="$2"
echo "BROKER_VERSION=$BROKER_VERSION"
CORE_COUNT="$3"
echo "CORE_COUNT=$CORE_COUNT"
FS="$4"
echo "FS=$FS"
INSTANCE="$5"
echo "INSTANCE=$INSTANCE"
KEY_PAIR="$6"
echo "KEY_PAIR=$KEY_PAIR"
LG_INSTANCE="$7"
echo "LG_INSTANCE=$LG_INSTANCE"
LG_SG="$8"
echo "LG_SG=$LG_SG"
LOG_LEVEL="$9"
echo "LOG_LEVEL=$LOG_LEVEL"
NODE_NUMBER="${10}"
echo "NODE_NUMBER=$NODE_NUMBER"
RUN_TAG="${11}"
echo "RUN_TAG=$RUN_TAG"
SG="${12}"
echo "SG=$SG"
SN="${13}"
echo "SN=$SN"
TECHNOLOGY="${14}"
echo "TECHNOLOGY=$TECHNOLOGY"
TENANCY="${15}"
echo "TENANCY=$TENANCY"
TPC="${16}"
echo "TPC=$TPC"
VARS_FILE="${17}"
echo "VARS_FILE=$VARS_FILE"
VOL_SIZE="${18}"
echo "VOL_SIZE=$VOL_SIZE"
VOL_TYPE="${19}"
echo "VOL_TYPE=$VOL_TYPE"
echo "---------------------------"

set -e

ROOT_PATH=$(pwd)

INFLUX_IP=$(aws ec2 describe-instances --filters "Name=tag:inventorygroup,Values=benchmarking_metrics" --query "Reservations[*].Instances[*].PrivateIpAddress" --output=text)
INFLUX_URL="http://$INFLUX_IP:8086"
echo "Node $NODE_NUMBER: InfluxDB url is $INFLUX_URL"

TAG=benchmarking_${TECHNOLOGY}${NODE_NUMBER}_${RUN_TAG}
RUNNING="$(aws ec2 describe-instances --filters "Name=tag:inventorygroup,Values=$TAG" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output=text)"
if [ -z $RUNNING ]; then
    echo "Node $NODE_NUMBER: Creating $TECHNOLOGY server $NODE_NUMBER with version $BROKER_VERSION"

    # if its a local storage instance then do not add extra ebs volume
    if [[ $INSTANCE == c5d* ]] || [[ $INSTANCE == i3* ]]; then
        bash deploy-local-storage-instance.sh $AMI $CORE_COUNT $INSTANCE $KEY_PAIR $LG_INSTANCE $LG_SG $NODE_NUMBER $RUN_TAG $SG $SN "rabbitmq" $TENANCY $TPC
    else
        bash deploy-ebs-instance.sh $AMI $CORE_COUNT $INSTANCE $KEY_PAIR "true" $LG_INSTANCE $LG_SG $NODE_NUMBER $RUN_TAG $SG $SN $TECHNOLOGY $TENANCY $TPC $VOL_SIZE $VOL_TYPE
    fi
else
    echo "Node $NODE_NUMBER: Instance already exists, skipping EC2 instance creation"
fi

while [ -z $RUNNING ]
do
    echo "Node $NODE_NUMBER: Broker ${TECHNOLOGY}${NODE_NUMBER} not ready yet, waiting 5 seconds"
    sleep 5
    RUNNING="$(aws ec2 describe-instances --filters "Name=tag:inventorygroup,Values=$TAG" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output=text)"
    echo $RUNNING
done

echo "Node $NODE_NUMBER: Waiting 1 minute for $TECHNOLOGY EC2 instance $NODE_NUMBER to initialize"
sleep 60

echo "Node $NODE_NUMBER: Configuring $TECHNOLOGY EC2 instance $NODE_NUMBER"
cd $ROOT_PATH/$TECHNOLOGY

if (( $VOL_SIZE > 1999 )); then 
    VOLUME_SIZE_LABEL=$(($VOL_SIZE/1000))T
else
    VOLUME_SIZE_LABEL="${VOL_SIZE}G"
fi
echo "VOLUME_SIZE_LABEL is $VOLUME_SIZE_LABEL"


SUCCESS="false"

while [ "$SUCCESS" == "false" ]
do
    ansible-playbook install-${TECHNOLOGY}.yml --private-key=~/.ssh/${KEY_PAIR}.pem --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
    --extra-vars "influx_url=$INFLUX_URL" \
    --extra-vars "${TECHNOLOGY}_version=${BROKER_VERSION}-1" \
    --extra-vars "hostname=$TECHNOLOGY$NODE_NUMBER" \
    --extra-vars "filesystem=$FS" \
    --extra-vars "node=$NODE_NUMBER" \
    --extra-vars "volume_size=$VOL_SIZE" \
    --extra-vars "run_tag=$RUN_TAG" \
    --extra-vars "volume_size_label=$VOLUME_SIZE_LABEL" \
    --extra-vars "@${VARS_FILE}" \
    --extra-vars "log_level=${LOG_LEVEL}"
       
    
    BROKER_IP=$(aws ec2 describe-instances --filters "Name=tag:inventorygroup,Values=$TAG" --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)
    echo "Node $NODE_NUMBER: Checking server configured correctly. IP $BROKER_IP"
    RESULT=$(ssh -i "~/.ssh/$KEY_PAIR.pem" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" ubuntu@$BROKER_IP "ls | grep run_check")
    if [[ $RESULT == run_check ]]; then
        SUCCESS="true"
        echo "Node $NODE_NUMBER: Server configured correctly."
    else
        echo "Node $NODE_NUMBER: Broker ansible playbook skipped, retrying in 30 seconds"
        sleep 30
    fi
done

cd ..
bash deploy-benchmark.sh $KEY_PAIR $NODE_NUMBER $TECHNOLOGY $RUN_TAG