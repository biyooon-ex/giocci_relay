import Config
import Dotenvy

source!([".env", System.get_env()])

config :giocci_relay, :system_variables,
  node_name: "relay",
  node_ipaddr: "127.0.0.1",
  cookie: "idkp",
  inet_dist_listen_min: "9100",
  inet_dist_listen_max: "9155",
  my_process_name: "{:global, :relay}",
  node_engine_name: "{:global, :engine}",
  rpc_engine_name: "engine@127.0.0.1",
  # for GiocciRelayZenoh
  my_node_name: env!("MY_NODE_NAME", :string, "relay1"),
  client_node_name: env!("CLIENT_NODE_NAME", :string, "client1"),
  engine_node_name:
    env!(
      "ENGINE_NODE_NAME",
      :string,
      "[\"engine1\", \"engine2\", \"engine3\", \"engine4\", \"engine5\"]"
    )
    |> Code.eval_string()
    |> elem(0)

# import_config "#{config_env()}.exs"
