defmodule GiocciRelay.Zenoh do
  @moduledoc false

  use GenServer
  require Logger

  alias Zenohex.Session
  alias Zenohex.Publisher

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    my_node_name = Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name]
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]

    {:ok, session} = Session.open()

    {:ok, subscriber} =
      Session.declare_subscriber(session, key_space <> "relay/" <> my_node_name <> "/*")

    callback = &relay_callback/3

    state = %{session: session, subscriber: subscriber, callback: callback}

    {:ok, state}
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    %{session: session, callback: callback} = state
    magic_number = sample.key_expr |> String.split("/") |> List.last()
    callback.(session, sample, magic_number)
    {:noreply, state}
  end

  defp relay_callback(session, sample, magic_number) do
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]
    payload_decoded = :erlang.binary_to_term(sample.payload)
    engine = Map.get(payload_decoded, "engine") |> to_string()
    pub_key = key_space <> "engine/" <> engine <> "/" <> magic_number

    {:ok, publisher} = Session.declare_publisher(session, pub_key)

    Logger.info(
      "Relay: from #{inspect(Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name])} to #{inspect(engine)} with magic number #{inspect(magic_number)}"
    )

    Publisher.put(publisher, sample.payload)

    Publisher.undeclare(publisher)
  end
end
