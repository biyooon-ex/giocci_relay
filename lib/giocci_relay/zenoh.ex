defmodule GiocciRelay.Zenoh do
  @moduledoc false

  use GenServer
  require Logger

  alias Zenohex.Session
  alias Zenohex.Publisher
  alias Zenohex.Sample

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    my_node_name = Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name]
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]

    {:ok, session} = Session.open()

    key_expr_payload = key_space <> "relay/" <> my_node_name <> "/*"
    {:ok, sub_payload} = Session.declare_subscriber(session, key_expr_payload)
    callback_payload = &callback_payload/4

    key_expr_to_engine = key_space <> "relay/to_engine"
    {:ok, sub_to_engine} = Session.declare_subscriber(session, key_expr_to_engine)

    state = %{
      session: session,
      key_expr_payload: key_expr_payload,
      sub_payload: sub_payload,
      callback_payload: callback_payload,
      key_expr_to_engine: key_expr_to_engine,
      sub_to_engine: sub_to_engine,
      to_engine: my_node_name
    }

    {:ok, state}
  end

  def handle_info(
        %Sample{key_expr: key_expr_to_engine} = sample,
        %{key_expr_to_engine: key_expr_to_engine} = state
      ) do
    Logger.info("Relay: to_engine has changed to #{inspect(sample.payload)}")
    {:noreply, %{state | to_engine: sample.payload}}
  end

  def handle_info(%Sample{} = sample, state) do
    %{session: session, callback_payload: callback_payload} = state
    magic_number = sample.key_expr |> String.split("/") |> List.last()
    callback_payload.(session, sample, state.to_engine, magic_number)
    {:noreply, state}
  end

  defp callback_payload(session, sample, to_engine, magic_number) do
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]
    pub_key = key_space <> "engine/" <> to_engine <> "/" <> magic_number

    {:ok, publisher} = Session.declare_publisher(session, pub_key)

    Logger.info(
      "Relay: from #{inspect(Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name])} to #{inspect(to_engine)} with magic number #{inspect(magic_number)}"
    )

    Publisher.put(publisher, sample.payload)

    Publisher.undeclare(publisher)
  end
end
