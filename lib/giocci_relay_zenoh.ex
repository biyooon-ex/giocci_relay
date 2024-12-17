defmodule GiocciRelayZenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelay.Server.start_link([{:global, :relay}, {:global, :engine}], :"engine@127.0.0.1")

  """

  use GenServer
  require Logger

  def callback_fromclient(state, m) do
    ## Clientから送られたデータを解析して、やりたい動作ごとに割り振る予定
    %{
      key_expr: erkey,
      value: msgint,
      kind: kind,
      reference: reference
    } = m

    ## msgをバイナリからlistにもどす
    msg =
      msgint
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case msg do
      ## module_execの場合
      [_, _, _, :module_exec] = msg ->
        Zenohex.Publisher.put(state.publishercre, msgint)

      ## module_saveの場合
      [_, :module_save] = msg ->
        Zenohex.Publisher.put(state.publishercre, msgint)

      _ = msg ->
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

    Zenohex.Publisher.put(state.publishererc, msg)
  end

  @spec start_link(any()) ::
          {:ok, %{callback: (any() -> any()), id: ERCsession, subscriber: Zenohex.Subscriber.t()}}
  def start_link(engine_name) do
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

    ## 状態として次の状態をもつ
    state = %{
      publishererc: publisher1,
      subscribererc: subscriber1,
      callbackerc: &callback_fromengine/2,
      publishercre: publisher2,
      subscribercre: subscriber2,
      callbackcre: &callback_fromclient/2,
      id: ERCCREsession,
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: ERCCREsession)

    ## subの開始
    recv_timeout_erc(state)
    recv_timeout_cre(state)
    {:ok, state}
  end

  def handle_info(:loop_erc, state) do
    # subをループするhandle info
    recv_timeout_erc(state)
    {:noreply, state}
  end

  def handle_info(:loop_cre, state) do
    # subをループするhandle info
    recv_timeout_cre(state)
    {:noreply, state}
  end

  defp recv_timeout_erc(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscribererc, 10_000) do
      {:ok, sample} ->
        state.callbackerc.(state, sample)
        send(state.id, :loop_erc)

      {:error, :timeout} ->
        send(state.id, :loop_erc)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end

  defp recv_timeout_cre(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscribercre, 10_000) do
      {:ok, sample} ->
        state.callbackcre.(state, sample)
        send(state.id, :loop_cre)

      {:error, :timeout} ->
        send(state.id, :loop_cre)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
