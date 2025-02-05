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
    create_session(client_node_name())
  end

  def start_link(engine_name) do
    relay_name = my_node_name()

    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()

    ## subのキーをたてる
    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        "key_prefix/giocci/engine_to_relay/" <> engine_name <> "/" <> relay_name
      )

    ## pubキーをたてる
    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        "key_prefix/giocci/relay_to_engine/" <> relay_name <> "/" <> engine_name
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
    Logger.info("key_prefix/giocci/relay_to_engine/" <> relay_name <> "/" <> engine_name)
    ## subの開始
    subscriber_loop_engine_to_relay(state)
    {:ok, state}
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  ## Clientから送られたデータを解析して、やりたい動作ごとに割り振るコールバック関数
  def callback_from_client(_state, message) do
    message_value = Map.get(message, :value)
    relay_name = my_node_name()

    engine_name_tosend = engine_name_tosend()

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
        [publisher] = GenServer.call(id, :call_publisher_toengine)

        Zenohex.Publisher.put(publisher, message_value)

      ## module_saveの場合
      [_, :module_save] ->
        engine_name_tosend = engine_name_tosend()

        id = (relay_name <> engine_name_tosend) |> String.to_atom()
        ## publisherをセッションから作成しpublishする
        [publisher] = GenServer.call(id, :call_publisher_toengine)

        Zenohex.Publisher.put(publisher, message_value)

      _ ->
        Logger.error(inspect("no match"))
    end
  end

  ## Engineから送られたメッセージを抽出し、Clientに返送
  def callback_from_engine(_state, message) do
    message_value = Map.get(message, :value)

    relay_name = my_node_name()

    client_name_tosend = client_name_tosend()

    id = (client_name_tosend <> relay_name) |> String.to_atom()
    ## publisherをセッションから作成しpublishする
    [publisher] = GenServer.call(id, :call_publisher_toclient)

    Zenohex.Publisher.put(publisher, message_value)
  end

  def handle_call(:call_publisher_toengine, _from, state) do
    reply = [state.publisher_relay_to_engine]
    {:reply, reply, state}
  end

  def handle_call(:call_publisher_toclient, _from, state) do
    reply = [state.publisher_relay_to_client]
    {:reply, reply, state}
  end

  ##   subをループするhandle info
  def handle_info(:loop_engine_to_relay, state) do
    subscriber_loop_engine_to_relay(state)
    {:noreply, state}
  end

  ##   subをループするhandle info
  def handle_info(:loop_client_to_relay, state) do
    subscriber_loop_client_to_relay(state)
    {:noreply, state}
  end

  defp create_clientsession(client_name) do
    relay_name = my_node_name()
    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()

    ## pub,subそれぞれのキーをたてる

    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        "key_prefix/giocci/client_to_relay/" <> client_name <> "/" <> relay_name
      )

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        "key_prefix/giocci/relay_to_client/" <> relay_name <> "/" <> client_name
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
    Logger.info("key_prefix/giocci/client_to_relay/" <> relay_name)
    ## subの開始
    subscriber_loop_client_to_relay(state)
    {:ok, state}
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

  defp my_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:my_node_name]

  defp engine_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:engine_node_name]

  defp client_node_name(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:client_node_name]

  defp client_name_tosend(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:client_name_tosend]

  defp engine_name_tosend(),
    do: Application.fetch_env!(:giocci_relay, :giocci_relay_zenoh)[:engine_name_tosend]
end
