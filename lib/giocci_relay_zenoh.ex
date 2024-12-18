defmodule GiocciRelayZenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelay.Server.start_link([{:global, :relay}, {:global, :engine}], :"engine@127.0.0.1")

  """

  use GenServer
  require Logger

  def setup_relay do
    ## 最初に指定された数のEngineノードとのZenohコネクションを作成する（clientは一個想定）
    engine_number_string = System.get_env("NODE_ENGINE_NUMBER")
    engine_number = String.to_integer(engine_number_string)
    create_session(engine_number)
  end

  @spec start_link(any(), any()) ::
          {:ok, %{callback: (any() -> any()), id: ERCsession, subscriber: Zenohex.Subscriber.t()}}
  def start_link(engine_name, number) do
    relay_name = System.get_env("MY_NODE_NAME")
    client_name = System.get_env("NODE_CLIENT_NAME1")
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

    id_string = "Engine2Relay2ClientandClient2Relay2Enginesession" <> number
    ## 状態として次の状態をもつ
    state = %{
      publisher_Engine2Relay2Client: publisher1,
      subscriber_Engine2Relay2Client: subscriber1,
      callback_Engine2Relay2Client: &callback_fromengine/2,
      publisher_Client2Relay2Engine: publisher2,
      subscriber_Client2Relay2Engine: subscriber2,
      callback_Client2Relay2Engine: &callback_fromclient/2,
      id: String.to_atom(id_string),
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    IO.inspect("from/" <> relay_name <> "/to/" <> engine_name)
    ## subの開始
    recv_timeout_Engine2Relay2Client(state)
    recv_timeout_Client2Relay2Engine(state)
    {:ok, state}
  end

  def callback_fromclient(state, message) do
    ## Clientから送られたデータを解析して、やりたい動作ごとに割り振る予定
    %{
      key_expr: erkey,
      value: message_intermediate,
      kind: kind,
      reference: reference
    } = message

    ## msgをバイナリからlistにもどす
    readable_msg =
      message_intermediate
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case readable_msg do
      ## module_execの場合
      [_, _, _, :module_exec] = readable_msg ->
        Zenohex.Publisher.put(state.publisher_Client2Relay2Engine, message_intermediate)

      ## module_saveの場合
      [_, :module_save] = readable_msg ->
        Zenohex.Publisher.put(state.publisher_Client2Relay2Engine, message_intermediate)

      _ = readable_msg ->
        IO.inspect("no match")
    end
  end

  def callback_fromengine(state, m) do
    ## 　Engineから送られたメッセージを抽出し、Clientに返送
    %{
      key_expr: erkey,
      value: msg,
      kind: kind,
      reference: reference
    } = m

    Zenohex.Publisher.put(state.publisher_Engine2Relay2Client, msg)
  end

  def handle_info(:loop_Engine2Relay2Client, state) do
    # subをループするhandle info
    recv_timeout_Engine2Relay2Client(state)
    {:noreply, state}
  end

  def handle_info(:loop_Client2Relay2Engine, state) do
    # subをループするhandle info
    recv_timeout_Client2Relay2Engine(state)
    {:noreply, state}
  end

  defp create_session(0) do
    :ok
  end

  defp create_session(n) do
    ## セッションをｎ個作る関数
    number = Integer.to_string(n)
    engine_name = System.get_env("NODE_ENGINE_NAME" <> number)
    start_link(engine_name, number)
    create_session(n - 1)
  end

  defp recv_timeout_Engine2Relay2Client(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscriber_Engine2Relay2Client, 10_000) do
      {:ok, sample} ->
        state.callback_Engine2Relay2Client.(state, sample)
        send(state.id, :loop_Engine2Relay2Client)

      {:error, :timeout} ->
        send(state.id, :loop_Engine2Relay2Client)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end

  defp recv_timeout_Client2Relay2Engine(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscriber_Client2Relay2Engine, 10_000) do
      {:ok, sample} ->
        state.callback_Client2Relay2Engine.(state, sample)
        send(state.id, :loop_Client2Relay2Engine)

      {:error, :timeout} ->
        send(state.id, :loop_Client2Relay2Engine)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
