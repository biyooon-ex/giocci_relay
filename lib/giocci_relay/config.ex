defmodule GiocciRelay.Config do
  def my_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:my_node_name]

  def engine_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:engine_node_name]

  def client_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:client_node_name]

  def client_name_tosend(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:client_name_tosend]

  def engine_name_tosend(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:engine_name_tosend]

  def key_prefix() do
    prefix = Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:key_prefix]

    if prefix == "" || prefix == nil do
      ""
    else
      prefix <> "/"
    end
  end
end
