#!/usr/bin/env bash

die () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 3 ] || die "3 arguments required, $# provided - <prefix of container to add to pool> <port of container adding to pool> <name or id of load balancing container>"

NAME_PREFIX="$1"
PORT="$2"
LB_CONTAINER="$3"

IDS="$(docker ps --no-trunc=true -f name=$NAME_PREFIX | tail -n +2 | cut -f1 -d ' ')"

POOL=""

echo -e $IDS

while read -r id; do
	ip="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $id)"
	name="$(docker inspect -f '{{ .Name }}' $id | tr -d '/')"
        POOL="server $ip:$PORT;\n$POOL"
done <<< "$IDS"

echo "Wiping existing pool configuration"

docker exec -ti $LB_CONTAINER bash -c "sed -i '/### start pool ###/,/### end pool ###/{//!d}' /etc/nginx/sites-available/default"

echo "Updating with the latest configuration"
echo -e $POOL

docker exec -ti $LB_CONTAINER bash -c "sed -i '/### end pool ###/i $POOL' /etc/nginx/sites-available/default"

docker exec -ti $LB_CONTAINER bash -c 'bounce_nginx'

echo "Loadbalancer IP: $(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $LB_CONTAINER)"
