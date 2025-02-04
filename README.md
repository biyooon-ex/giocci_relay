# GiocciRelay

## 環境
- Erlang after 27.1.2 
- Elixir after 1.17.3-otp-27
- Zenoh 0.11.0

## 準備方法

`mix deps.get`により必要なモジュールを読み込みます。

## 起動方法

`iex -S mix`後に`GiocciRelayZenoh.setup_relay`を実行すると起動完了となります。




### 起動後の手続き
giocci_engineの手続きをすべて完了した後以下のコマンドでZenohルータを別ターミナルに起動します。
```sh
zenohd -e tcp/EngineのGlobalIP:7447
```


