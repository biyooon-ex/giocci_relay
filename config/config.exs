import Config

config :giocci_relay_zenoh, :system_variables,
  my_node_name: "relay1",
  engine_node_name: ["engine1"],
  client_node_name: "client1"

config :giocci_relay, :system_variables,
  node_name: "relay",
  node_ipaddr: "127.0.0.1",
  cookie: "idkp",
  inet_dist_listen_min: "9100",
  inet_dist_listen_max: "9155",
  my_process_name: "{:global, :relay}",
  node_engine_name: "{:global, :engine}",
  rpc_engine_name: "engine@127.0.0.1"

# import_config "#{config_env()}.exs"
