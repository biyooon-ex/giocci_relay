defmodule GiocciRelay.Server do
  @moduledoc """
  ## Examples

      iex> GiocciRelay.Server.start_link([{:global, :relay}, {:global, :engine}], :"engine@127.0.0.1")

  """

  use GenServer
  require Logger

  @timeout_ms 180_000

  #
  # Client API
  #
  def start_link([pname, node_engine_name, rpc_engine_name]) do
    state = %{node_engine: node_engine_name, rpc_engine: rpc_engine_name}
    GenServer.start_link(__MODULE__, state, name: pname)
  end

  def stop(pname) do
    GenServer.stop(pname)
  end

  #
  # Callback
  #
  @impl true
  def handle_call({:detect, binary, destination}, _from, state) do
    detection = detect(binary, destination)

    {:reply, detection, state}
  end

  @impl true
  def handle_call({:get, vcontact_id}, _from, state) do
    vcontact = get(state.node_engine, vcontact_id)

    {:reply, vcontact, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    current_list = list(state.node_engine)

    {:reply, current_list, state}
  end

  @impl true
  def handle_call({:list_filter, filter_key, filter_value}, _from, state) do
    filter_list =
      list(state.node_engine)
      |> Enum.map(fn {vcontact_id, vcontact_element} ->
        Map.put(vcontact_element, :vcontact_id, vcontact_id)
      end)
      |> Enum.filter(fn vcontact -> vcontact[filter_key] == filter_value end)

    {:reply, filter_list, state}
  end

  @impl true
  def handle_call({:module_save, encode_module}, _from, state) do
    module_save_reply = module_save(state.node_engine, {:module_save, encode_module})

    {:reply, module_save_reply, state}
  end

  @impl true
  def handle_call({:rpc, module, function, arity}, _from, state) do
    rpc_engine = state.rpc_engine
    rpc_reply = rpc({rpc_engine, module, function, arity})

    {:reply, rpc_reply, state}
  end

  @impl true
  def handle_cast({:delete, vcontact_id}, state) do
    delete(state.node_engine, vcontact_id)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, vcontact_id, vcontact_element}, state) do
    put(state.node_engine, vcontact_id, vcontact_element)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put_detect_log, total_time, processing_time, model, backend}, state) do
    put_detect_log(total_time, processing_time, model, backend)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, vcontact_id, update_vcontact_key, update_vcontact_value}, state) do
    Logger.info(
      "=> #{inspect(vcontact_id)}, #{inspect(update_vcontact_key)}, #{inspect(update_vcontact_value)}"
    )

    update(state.node_engine, vcontact_id, update_vcontact_key, update_vcontact_value)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_contact, node_name, contact_name, contact_value}, state) do
    Logger.info("<= #{inspect(node_name)}, #{inspect(contact_name)}, #{inspect(contact_value)}")

    update_contact(node_name, {:update_contact, contact_name, contact_value})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reg_contact, vcontact_element}, state) do
    reg_contact(state.node_engine, vcontact_element)
    {:noreply, state}
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def terminate(reason, _) do
    reason
  end

  #
  # Function
  #
  def delete(engine, vcontact_id) do
    GenServer.cast(engine, {:delete, vcontact_id})
  end

  def detect(binary, destination) do
    case destination do
      :aws ->
        Logger.info("relay to ===> #{inspect(:aws)}")
        GenServer.call({:global, :yolo_aws}, binary, @timeout_ms)

      :mec ->
        Logger.info("relay to ===> #{inspect(:mec)}")
        GenServer.call({:global, :yolo_mec}, binary, @timeout_ms)

      :sakura ->
        Logger.info("relay to ===> #{inspect(:sakura)}")
        GenServer.call({:global, :yolo_sakura}, binary, @timeout_ms)

      _ ->
        false
    end
  end

  def get(engine, vcontact_id) do
    GenServer.call(engine, {:get, vcontact_id})
  end

  def list(engine) do
    GenServer.call(engine, :list)
  end

  def module_save(engine, {:module_save, encode_module}) do
    GenServer.call(engine, {:module_save, encode_module})
  end

  def put(engine, vcontact_id, vcontact_element) do
    GenServer.cast(engine, {:put, vcontact_id, vcontact_element})
  end

  def update(engine, vcontact_id, update_vcontact_key, update_vcontact_value) do
    GenServer.cast(engine, {:update, vcontact_id, update_vcontact_key, update_vcontact_value})
  end

  def update_contact(node_name, {:update_contact, contact_name, contact_value}) do
    GenServer.cast(node_name, {:update_contact, contact_name, contact_value})
  end

  def reg_contact(engine, vcontact_element) do
    GenServer.cast(engine, {:reg_contact, vcontact_element})
  end

  def put_detect_log(total_time, processing_time, model, backend) do
    {{year, month, day}, {time, min, sec}} = :calendar.local_time()

    file_name =
      "#{year}" <> String.pad_leading("#{month}", 2, "0") <> String.pad_leading("#{day}", 2, "0")

    local_time = "#{year}-#{month}-#{day} #{time}:#{min}:#{sec}"

    log =
      local_time <>
        ", " <>
        Float.to_string(total_time) <>
        ", " <> Float.to_string(processing_time) <> ", " <> model <> ", " <> backend <> "\n"

    File.write("data/#{file_name}_detect_log.txt", log, [:append])
  end

  def rpc({rpc_engine, module, function, arity}) do
    :rpc.call(rpc_engine, module, function, arity , 10000)
  end







  def callback(m) do
    # ここで時間のlogを取りたい？
    msg = m |> String.trim        ##msgをバイナリからlistに変換
      |> Base.decode64!
      |> :erlang.binary_to_list
    case msg do
      [function_binary , arity_binary, :module_exec]=msg ->  ##module_execの場合
        session = GenServer.call(__MODULE__, :call_session)
        {:ok, publisher} = Session.declare_publisher(session, "to/engine")
        Publisher.put(publisher , msg |> :erlang.term_to_binary() |> Base.encode64())

      [encode_module , :module_save] = msg ->  ##module_saveの場合
        session = GenServer.call(Giocci, :call_session)
        {:ok, publisher} = Session.declare_publisher(session, "to/engine")
        Publisher.put(publisher , msg |> :erlang.term_to_binary() |> Base.encode64())
      _ =msg
        IO.inspect("no match")
    end
  end


  def callbacken(state,m) do
    %{
      key_expr: erkey,
      value: msg,
      kind: kind,
      reference: reference
    } = m
    # session = GenServer.call(ERSession, :call_session)
    # {:ok, publisher} = Zenohex.Session.declare_publisher(session, "from/relay/to/client")
    Zenonex.Publisher.put(state.publisher , msg )
  end

  @spec start_link_session_erc() ::
          {:ok, %{callback: (any() -> any()), id: ERsession, subscriber: Zenohex.Subscriber.t()}}
  def start_link_session_erc() do
    ##RelayのZenohセッションを起動
    {:ok,session} = Zenohex.open
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "from/engine/to/relay")
    {:ok, publisher} = Zenohex.Session.declare_publisher(session, "from/relay/to/client")
    state = %{publisher: publisher, subscriber: subscriber, callback: &callbacken/2,id: ERsession,session: session}
    GenServer.start_link(__MODULE__, state, name: ERsession)


    recv_timeout(state)
    {:ok, state}
  end

  def start_link_session_cre() do
    ##RelayのZenohセッションを起動
    {:ok,session} = Zenohex.open
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session,"from/client/to/relay")
    state = %{subscriber: subscriber, callback: &IO.inspect/1 ,id: CRsession}
    GenServer.start_link(__MODULE__, state, name: CRsession)

    recv_timeout(state)
    {:ok, state}

  end

  # def init(session) do
  #   IO.inspect("pass")
  #   {:ok, session}
  # end

  def handle_call(:call_session, _from, state) do
    session = state.session
    {:reply, session, state}
  end

  def handle_info(:loop, state) do
    IO.inspect("pass3")
    recv_timeout(state)
    {:noreply, state}
  end


  def setup_relay do

    ##GenServerにsession情報を保存
    {:ok, statee} = start_link_session_erc()
    {:ok, statec} = start_link_session_cre()
    # sessioncl = GenServer.call(CRsession,:call_session)
    # sessionen = GenServer.call(ERsession,:call_session)
    ##ClientからRelay，EngineからRelayへののサブスクライブの準備

    # GenServer.cast(pide, {:sub_start,"from/client/to/relay"})
    # {:ok, subscribercl} = Zenohex.Session.declare_subscriber(sessioncl, "from/client/to/relay" )
    # {:ok, subscriberen} = Zenohex.Session.declare_subscriber(sessionen, "from/engine/to/relay" )

    # {:ok, msg} = Zenohex.Subscriber.recv_timeout(subscriberen,10000000)
    # {:ok, msg} = Zenohex.Subscriber.recv_timeout(subscribercl,50000000)
  end



  defp recv_timeout(state) do



    IO.inspect(state.id)


    # GenServer.cast(ERsession, {:sub_start,"from/client/to/relay"})
    case Zenohex.Subscriber.recv_timeout(state.subscriber,10000000) do
      {:ok, sample} ->
        state.callback.(state,sample)
        send(state.id, :loop)

      {:error, :timeout} ->
        IO.inspect("pass")
        send(state.id, :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end






end
