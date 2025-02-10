defmodule GiocciRelay.ClientSessionNode do
  use GenServer
  alias GiocciRelay.Config, as: RelayConfig
  require Logger

  def start_link(client_name) do
    relay_name = RelayConfig.my_node_name()
    Logger.info("(GiocciRelay) Start GenServer ID: " <> client_name <> relay_name)
    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()

    ## pub,subそれぞれのキーをたてる
    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        RelayConfig.key_prefix() <> "giocci/client_to_relay/" <> client_name <> "/" <> relay_name
      )

    Logger.info(
      "(GiocciRelay) Start subscriber (client to relay) :" <>
        RelayConfig.key_prefix() <> "giocci/client_to_relay/" <> client_name <> "/" <> relay_name
    )

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        RelayConfig.key_prefix() <> "giocci/relay_to_client/" <> relay_name <> "/" <> client_name
      )

    Logger.info(
      "(GiocciRelay) Start publisher (relay to client) :" <>
        RelayConfig.key_prefix() <> "giocci/relay_to_client/" <> relay_name <> "/" <> client_name
    )

    id_string = client_name <> relay_name
    ## 状態として次の状態をもつ
    state = %{
      subscriber_client_to_relay: subscriber,
      publisher_relay_to_client: publisher,
      callback_client_to_relay: &callback_from_client/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
  end

  def init(state) do
    ## subの開始
    subscriber_loop_client_to_relay(state)
    {:ok, state}
  end

  ## Clientから送られたデータを解析して、やりたい動作ごとに割り振るコールバック関数
  def callback_from_client(_state, message) do
    message_value = Map.get(message, :value)
    relay_name = RelayConfig.my_node_name()

    engine_name_tosend = RelayConfig.engine_name_tosend()

    ## msgをバイナリからlistにもどす
    message_readable =
      Map.get(message, :value)
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case message_readable do
      ## module_execの場合
      [_, _, _, :module_exec] ->
        id = (relay_name <> engine_name_tosend) |> String.to_atom()
        ## publisherをセッションから作成しpublishする
        [publisher] = GenServer.call(id, :call_publisher_to_engine)
        Zenohex.Publisher.put(publisher, message_value)

      ## module_saveの場合
      [_, :module_save] ->
        id = (relay_name <> engine_name_tosend) |> String.to_atom()
        ## publisherをセッションから作成しpublishする
        [publisher] = GenServer.call(id, :call_publisher_to_engine)
        Zenohex.Publisher.put(publisher, message_value)

      _ ->
        Logger.error(inspect("no match"))
    end
  end

  ##   subをループするhandle info
  def handle_info(:loop_client_to_relay, state) do
    subscriber_loop_client_to_relay(state)
    {:noreply, state}
  end

  def handle_call(:call_publisher_to_client, _from, state) do
    reply = [state.publisher_relay_to_client]
    {:reply, reply, state}
  end

  ## subを永続化する関数
  defp subscriber_loop_client_to_relay(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber_client_to_relay, 10_000) do
      {:ok, sample} ->
        state.callback_client_to_relay.(state, sample)
        send(state.id, :loop_client_to_relay)

      {:error, :timeout} ->
        send(state.id, :loop_client_to_relay)

      {:error, error} ->
        Logger.error(inspect(error))

      {_, _} ->
        Logger.error("unexpected error")
    end
  end
end
