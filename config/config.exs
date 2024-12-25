import Config

config :giocci_relay_zenoh, :system_variables,
  my_node_name: "relay1",
  engine_node_name: ["engine1", "engine2", "engine3", "engine4", "engine5"],
  client_node_name: "client1"

# import_config "#{config_env()}.exs"
