defmodule GiocciRelay.Zenoh.Impl do
  @moduledoc false
  use GenServer
  require Logger

  alias Zenohex.Session
  alias Zenohex.Subscriber
  alias Zenohex.Publisher

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    my_node_name = Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name]
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]

    {:ok, session} = Zenohex.open()

    {:ok, subscriber} =
      Session.declare_subscriber(session, key_space <> "relay/" <> my_node_name <> "/*")

    ## 状態として次の状態をもつ
    state = %{session: session, subscriber: subscriber}

    recv_timeout(state)
    {:ok, state}
  end

  def handle_info(:loop, state) do
    recv_timeout(state)
    {:noreply, state}
  end

  defp recv_timeout(state) do
    case Subscriber.recv_timeout(state.subscriber) do
      {:ok, sample} ->
        detect(sample, state.session)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end

  defp detect(sample, session) do
    key_space = Application.fetch_env!(:giocci_relay, :system_variables)[:key_space]
    sample_decoded = :erlang.binary_to_term(sample.value)
    engine = Map.get(sample_decoded, "engine") |> to_string()
    magic_number = Map.get(sample_decoded, "magic_number") |> to_string()
    pub_key = key_space <> "engine/" <> engine <> "/" <> magic_number

    {:ok, publisher} = Session.declare_publisher(session, pub_key)

    Logger.info(
      "Relay: from #{Application.fetch_env!(:giocci_relay, :system_variables)[:my_node_name]} to #{engine}"
    )

    Publisher.put(publisher, sample.value)
  end
end
