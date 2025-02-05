# Copy this file to your application project and set
# the values accordingly to use Giocci features.
# It is recommended to prepare `.env` and gitignore it
# to keep your servers information secret.

import Config
import Dotenvy

source!([".env", System.get_env()])

config :giocci_relay, :giocci_relay_zenoh,
  my_node_name: env!("MY_RELAY_NODE_NAME", :string, "relay1"),
  engine_node_name:
    env!("ENGINE_NODE_NAME", :string, "engine1, engine2, engine3") |> String.split(~r/[ ,]+/),
  client_node_name: env!("CLIENT_NODE_NAME", :string, "client1"),
  engine_name_tosend: env!("ENGINE_NAME_TO_SEND", :string, "engine1"),
  client_name_tosend: env!("CLIENT_NODE_NAME", :string, "client1")
