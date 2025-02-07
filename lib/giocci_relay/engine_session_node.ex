defmodule GiocciRelay.EngineSessionNode do
  use GenServer
  alias GiocciRelay.Config
  alias GiocciRelay.ClientSessionNode
  require Logger

  def start_link(engine_name) do
    relay_name = Config.my_node_name()
    Logger.info("(GiocciRelay) Start GenServer ID:" <> relay_name <> engine_name)

    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()

    ## subのキーをたてる
    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        Config.key_prefix() <> "giocci/engine_to_relay/" <> engine_name <> "/" <> relay_name
      )

    Logger.info(
      "(GiocciRelay)  Start subscriber(engine to relay) :" <>
        Config.key_prefix() <> "giocci/engine_to_relay/" <> engine_name <> "/" <> relay_name
    )

    ## pubキーをたてる
    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        Config.key_prefix() <> "giocci/relay_to_engine/" <> relay_name <> "/" <> engine_name
      )

    Logger.info(
      "(GiocciRelay)  Start publisher (relay to engine) :" <>
        Config.key_prefix() <> "giocci/relay_to_engine/" <> relay_name <> "/" <> engine_name
    )

    id_string = relay_name <> engine_name
    ## 状態として次の状態をもつ
    state = %{
      publisher_relay_to_engine: publisher,
      subscriber_engine_to_relay: subscriber,
      callback_engine_to_relay: &callback_from_engine/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
  end

  def init(state) do
    ## subの開始
    subscriber_loop_engine_to_relay(state)
    {:ok, state}
  end

  ## Engineから送られたメッセージを抽出し、Clientに返送
  def callback_from_engine(_state, message) do
    message_value = Map.get(message, :value)

    relay_name = Config.my_node_name()

    client_name_tosend = Config.client_name_tosend()

    id = (client_name_tosend <> relay_name) |> String.to_atom()
    ## publisherをセッションから作成しpublishする
    [publisher] = GenServer.call(id, :call_publisher_to_client)

    Zenohex.Publisher.put(publisher, message_value)
  end

  def handle_call(:call_publisher_to_engine, _from, state) do
    reply = [state.publisher_relay_to_engine]
    {:reply, reply, state}
  end

  ##   subをループするhandle info
  def handle_info(:loop_engine_to_relay, state) do
    subscriber_loop_engine_to_relay(state)
    {:noreply, state}
  end

  defp create_session([]) do
    :ok
  end

  ## セッションを作る関数
  defp create_session(engine_list) do
    [engine_name | tail] = engine_list
    start_link(engine_name)
    create_session(tail)
  end

  ## subを永続化する関数
  defp subscriber_loop_engine_to_relay(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber_engine_to_relay, 10_000) do
      {:ok, sample} ->
        state.callback_engine_to_relay.(state, sample)
        send(state.id, :loop_engine_to_relay)

      {:error, :timeout} ->
        send(state.id, :loop_engine_to_relay)

      {:error, error} ->
        Logger.error(inspect(error))

      {_, _} ->
        Logger.error("unexpected error")
    end
  end
end
