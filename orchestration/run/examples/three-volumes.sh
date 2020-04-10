#!/bin/bash

python3.6 run-logged-aws-playlist.py \
--mode benchmark \
--playlist-file playlists/tiny-test.json \
--aws-config-file /path/to/my/aws-config.json \
--loadgen-instance c4.xlarge \
--gap-seconds 120 \
--repeat 1 \
--parallel 1 \
--config-count 1 \
--config-tag c1 \
--technology rabbitmq \
--instance c4.xlarge \
--volume ebs-gp2 \
--volume1-size 100 \
--volume2-size 10 \
--volume3-size 50 \
--data-volume volume1 \
--logs-volume volume2 \
--wal-volume volume3 \
--filesystem xfs \
--tenancy default \
--core-count 2 \
--threads-per-core 2 \
--cluster-size 1 \
--version 3.8.2 \
--generic-unix-url https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.8.2/rabbitmq-server-generic-unix-3.8.2.tar.xz \
--tags volumes-test