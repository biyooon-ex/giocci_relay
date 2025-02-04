defmodule GiocciRelayZenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelayZenoh.setup_relay()

  """

  use GenServer
  require Logger
  use Application

  @doc """
    最初に指定された数のEngineノードとのZenohコネクションを作成する（clientは一個想定
  """
  def setup_relay() do
    relay_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:my_node_name]
    client_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:client_node_name]
    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる

    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        "key_prefix/giocci/client_to_relay/" <> relay_name
      )

    id_string = relay_name <> "sub from client"
    ## 状態として次の状態をもつ
    state = %{
      subscriber_client2relay: subscriber,
      callback_client2relay: &callback_fromclient/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    Logger.info("key_prefix/giocci/client_to_relay/" <> relay_name)
    ## subの開始
    subscriber_loop_client2relay(state)
    {:ok, state}

    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        "key_prefix/giocci/relay_to_client/" <> client_name
      )

    id_string = client_name <> relay_name <> "pub"
    ## 状態として次の状態をもつ
    state = %{
      publisher_relay2client: publisher,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    ## subの開始
    {:ok, state}

    {:ok, session} = Zenohex.open()
    ## subのキーをたてる
    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        "key_prefix/giocci/engine_to_relay/" <> relay_name
      )

    id_string = relay_name <> "sub from engine"
    ## 状態として次の状態をもつ
    state = %{
      subscriber_engine2relay: subscriber,
      callback_engine2relay: &callback_fromengine/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    ## subの開始
    subscriber_loop_engine2relay(state)
    {:ok, state}

    create_session(Application.get_env(:giocci_relay_zenoh, :system_variables)[:engine_node_name])
  end

  def start_link(engine_name) do
    relay_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:my_node_name]
    client_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:client_node_name]
    ## RelayのZenohセッションを起動
    {:ok, session} = Zenohex.open()
    ## pubキーをたてる

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        "key_prefix/giocci/relay_to_engine/" <> engine_name
      )

    id_string = relay_name <> engine_name <> "pub"
    ## 状態として次の状態をもつ
    state = %{
      publisher_relay2engine: publisher,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    Logger.info("key_prefix/giocci/relay_to_engine/" <> engine_name)
    ## subの開始
    {:ok, state}
  end

  ## Clientから送られたデータを解析して、やりたい動作ごとに割り振るコールバック関数
  def callback_fromclient(state, message) do
    %{
      key_expr: erkey,
      value: message_intermediate,
      kind: kind,
      reference: reference
    } = message

    relay_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:my_node_name]
    ## msgをバイナリからlistにもどす
    message_readable =
      message_intermediate
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case message_readable do
      ## module_execの場合
      [_, _, _, :module_exec] = message_readable ->
        engine_name_tosend =
          Application.get_env(:giocci_relay_zenoh, :system_variables)[:engine_name_tosend]

        id = (relay_name <> engine_name_tosend <> "pub") |> String.to_atom()
        ## publisherをセッションから作成しpublishする
        [publisher] =
          GenServer.call(id, :call_publisher_toengine)

        Zenohex.Publisher.put(publisher, message_intermediate)

      ## module_saveの場合
      [_, :module_save] = message_readable ->
        engine_name_tosend =
          Application.get_env(:giocci_relay_zenoh, :system_variables)[:engine_name_tosend]

        id = (relay_name <> engine_name_tosend <> "pub") |> String.to_atom()
        ## publisherをセッションから作成しpublishする
        [publisher] =
          GenServer.call(id, :call_publisher_toengine)

        Zenohex.Publisher.put(publisher, message_intermediate)

      _ = message_readable ->
        Logger.error(inspect("no match"))
    end
  end

  ## Engineから送られたメッセージを抽出し、Clientに返送
  def callback_fromengine(state, message) do
    %{
      key_expr: erkey,
      value: message_intermediate,
      kind: kind,
      reference: reference
    } = message

    relay_name = Application.get_env(:giocci_relay_zenoh, :system_variables)[:my_node_name]

    client_name_tosend =
      Application.get_env(:giocci_relay_zenoh, :system_variables)[:client_name_tosend]

    id = (client_name_tosend <> relay_name <> "pub") |> String.to_atom()
    ## publisherをセッションから作成しpublishする
    [publisher] =
      GenServer.call(id, :call_publisher_toclient)

    Zenohex.Publisher.put(publisher, message_intermediate)
  end

  def handle_call(:call_publisher_toengine, _from, state) do
    reply = [state.publisher_relay2engine]
    {:reply, reply, state}
  end

  def handle_call(:call_publisher_toclient, _from, state) do
    reply = [state.publisher_relay2client]
    {:reply, reply, state}
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
end
