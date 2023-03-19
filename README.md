# GiocciRelay

## 起動方法
`start_node.sh` ファイルを実行後、GiocciEngineに `Node.connect()` すると起動完了となります。

### 準備
`start_node.sh` をエディタで開き、実際の内容に修正します。

特に `NODE_IPADDR` の項目の確認は必須となります。

| 項目 | 初期値 | 説明 |
| --- | --- | --- |
| NODE_NAME | "relay" | 起動する `node` の名前 |
| NODE_IPADDR | "192.168.10.100" | 起動する `node` のIPアドレス（`ifconfig` や `ip a` 等のコマンドで確認後入力してください） |
| COOKIE | "idkp" | COOKIEの値 |
| INET_DIST_LISTEN_MIN | "9100" | epmdが利用するノード間通信ポート |
| INET_DIST_LISTEN_MAX | "9155" | epmdが利用するノード間通信ポート |
| MY_PROCESS_NAME | "{:global, :relay}" | 起動するGenServerの名前 |
| TARGET_ENGINE_NAME | "{:global, :engine}" | 通信するGiocciEngineの名前 |

```sh
#!/bin/sh

#
# set variables
#
NODE_NAME="relay"
NODE_IPADDR="192.168.10.100"
COOKIE="idkp"
INET_DIST_LISTEN_MIN="9100"
INET_DIST_LISTEN_MAX="9155"
MY_PROCESS_NAME="{:global, :relay}"
TARGET_ENGINE_NAME="{:global, :engine}"

#
# start node
#
echo "exec: 
MY_PROCESS_NAME=\"${MY_PROCESS_NAME}\" TARGET_ENGINE_NAME=\"${TARGET_ENGINE_NAME}\" iex \
--name \"${NODE_NAME}@${NODE_IPADDR}\" \
--cookie \"${COOKIE}\" \
--erl \"-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}\" -S mix
"

MY_PROCESS_NAME="${MY_PROCESS_NAME}" TARGET_ENGINE_NAME="${TARGET_ENGINE_NAME}" iex \
  --name "${NODE_NAME}@${NODE_IPADDR}" \
  --cookie "${COOKIE}" \
  --erl "-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}" -S mix
```


### 起動
`start_node.sh` を実行します。

```sh
$ chmod 755 start_node.sh
$ ./start_node.sh
```

#### 起動の確認
`:sys.get_status(MY_PROCESS_NAME)` を実行して、GenServerのstateにTARGET_ENGINE_NAMEが登録されているか確認します。

```sh
$ ./start_node.sh
exec: 
MY_PROCESS_NAME="{:global, :relay}" TARGET_ENGINE_NAME="{:global, :engine}" iex --name "relay@192.168.10.100" --cookie "idkp" --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9155" -S mix

Erlang/OTP 25 [erts-13.1.4] [source] [64-bit] [smp:10:10] [ds:10:10:10] [async-threads:1] [jit]

Interactive Elixir (1.14.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(relay@192.168.10.100)1>  :sys.get_state({:global, :relay}) 
%{engine: {:global, :engine}}
```


### 起動後の手続き
GiocciEngineに `Node.connect()` してErlangクラスタを構築します。

注意事項：
- GiocciEngineが起動している必要がある
- GiocciEngineからGiocciRelayに対して `Node.connect()` してもよい

#### Node.connect()と確認
```elixir
iex(relay@192.168.10.100)1> Node.connect(:"engine@192.168.10.101")
True

iex(relay@192.168.10.100)2> Node.list()
[engine@192.168.10.101]
```
