defmodule GiocciRelayZenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelayZenoh.setup_relay()

  """

  use GenServer
  require Logger

  @doc """
    最初に指定された数のEngineノードとのZenohコネクションを作成する（clientは一個想定
  """
  def setup_relay() do
    create_session(engine_node_name())
  end

  def start_link(engine_name) do
    relay_name = my_node_name()
    client_name = client_node_name()
    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる
    {:ok, subscriber1} =
      Zenohex.Session.declare_subscriber(session, "from/" <> engine_name <> "/to/" <> relay_name)

    {:ok, publisher1} =
      Zenohex.Session.declare_publisher(session, "from/" <> relay_name <> "/to/" <> client_name)

    {:ok, subscriber2} =
      Zenohex.Session.declare_subscriber(session, "from/" <> client_name <> "/to/" <> relay_name)

    {:ok, publisher2} =
      Zenohex.Session.declare_publisher(session, "from/" <> relay_name <> "/to/" <> engine_name)

    id_string = client_name <> engine_name
    ## 状態として次の状態をもつ
    state = %{
      publisher_relay2client: publisher1,
      subscriber_engine2relay: subscriber1,
      callback_engine2relay: &callback_fromengine/2,
      publisher_relay2engine: publisher2,
      subscriber_client2relay: subscriber2,
      callback_client2relay: &callback_fromclient/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    Logger.info("from/" <> relay_name <> "/to/" <> engine_name)
    ## subの開始
    subscriber_loop_engine2relay(state)
    subscriber_loop_client2relay(state)
    {:ok, state}
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  ## Clientから送られたデータを解析して、やりたい動作ごとに割り振るコールバック関数
  def callback_fromclient(state, message) do
    ## msgをバイナリからlistにもどす
    message_readable =
      Map.get(message, :value)
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case message_readable do
      ## module_execの場合
      [_, _, _, :module_exec] ->
        Zenohex.Publisher.put(state.publisher_relay2engine, Map.get(message, :value))

      ## module_saveの場合
      [_, :module_save] ->
        Zenohex.Publisher.put(state.publisher_relay2engine, Map.get(message, :value))

      _ ->
        Logger.error(inspect("no match"))
    end
  end

  ## Engineから送られたメッセージを抽出し、Clientに返送
  def callback_fromengine(state, message) do
    message_intermediate = Map.get(message, :message_intermediate)
    Zenohex.Publisher.put(state.publisher_relay2client, message_intermediate)
  end

  ##   subをループするhandle info
  def handle_info(:loop_engine2relay, state) do
    subscriber_loop_engine2relay(state)
    {:noreply, state}
  end

  ##   subをループするhandle info
  def handle_info(:loop_client2relay, state) do
    subscriber_loop_client2relay(state)
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
  defp subscriber_loop_engine2relay(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber_engine2relay, 10_000) do
      {:ok, sample} ->
        state.callback_engine2relay.(state, sample)
        send(state.id, :loop_engine2relay)

      {:error, :timeout} ->
        send(state.id, :loop_engine2relay)

      {:error, error} ->
        Logger.error(inspect(error))

      {_, _} ->
        Logger.error("unexpected error")
    end
  end

  ## subを永続化する関数
  defp subscriber_loop_client2relay(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber_client2relay, 10_000) do
      {:ok, sample} ->
        state.callback_client2relay.(state, sample)
        send(state.id, :loop_client2relay)

      {:error, :timeout} ->
        send(state.id, :loop_client2relay)

      {:error, error} ->
        Logger.error(inspect(error))

      {_, _} ->
        Logger.error("unexpected error")
    end
  end

  defp my_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:my_node_name]

  defp engine_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:engine_node_name]

  defp client_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:client_node_name]
end
