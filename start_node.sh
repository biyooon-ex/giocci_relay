#!/bin/sh

#
# set variables
#
# TODO: 環境変数＆デフォルト値で処理（@tenbosのやり方を踏襲する）
NODE_NAME="relay"
NODE_IPADDR="127.0.0.1"
COOKIE="idkp"
INET_DIST_LISTEN_MIN="9100"
INET_DIST_LISTEN_MAX="9155"
MY_PROCESS_NAME="{:global, :relay}"
NODE_ENGINE_NAME="{:global, :engine}"
RPC_ENGINE_NAME="engine@127.0.0.1"

#
# start node
#
echo "exec: 
MY_PROCESS_NAME=\"${MY_PROCESS_NAME}\" NODE_ENGINE_NAME=\"${NODE_ENGINE_NAME}\" RPC_ENGINE_NAME=\"${RPC_ENGINE_NAME}\" iex \
--name \"${NODE_NAME}@${NODE_IPADDR}\" \
--cookie \"${COOKIE}\" \
--erl \"-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}\" -S mix
"

MY_PROCESS_NAME="${MY_PROCESS_NAME}" NODE_ENGINE_NAME="${NODE_ENGINE_NAME}" RPC_ENGINE_NAME="${RPC_ENGINE_NAME}" iex \
  --name "${NODE_NAME}@${NODE_IPADDR}" \
  --cookie "${COOKIE}" \
  --erl "-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}" -S mix
