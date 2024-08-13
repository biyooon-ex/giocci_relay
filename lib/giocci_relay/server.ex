defmodule GiocciRelay.Server do
  @moduledoc """
  ## Examples

      iex> GiocciRelay.Server.start_link([{:global, :relay}, {:global, :engine}])

  """

  use GenServer
  require Logger

  @timeout_ms 180_000

  #
  # Client API
  #
  def start_link([pname, state]) do
    state = %{engine: state}
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
    vcontact = get(state.engine, vcontact_id)

    {:reply, vcontact, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    current_list = list(state.engine)

    {:reply, current_list, state}
  end

  @impl true
  def handle_call({:list_filter, filter_key, filter_value}, _from, state) do
    filter_list =
      list(state.engine)
      |> Enum.map(fn {vcontact_id, vcontact_element} ->
        Map.put(vcontact_element, :vcontact_id, vcontact_id)
      end)
      |> Enum.filter(fn vcontact -> vcontact[filter_key] == filter_value end)

    {:reply, filter_list, state}
  end

  @impl true
  def handle_call({:module_save, encode_module}, _from, state) do
    module_save_reply = module_save(state.engine, {:module_save, encode_module})

    {:reply, module_save_reply, state}
  end

  @impl true
  def handle_cast({:delete, vcontact_id}, state) do
    delete(state.engine, vcontact_id)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, vcontact_id, vcontact_element}, state) do
    put(state.engine, vcontact_id, vcontact_element)

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

    update(state.engine, vcontact_id, update_vcontact_key, update_vcontact_value)

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
    reg_contact(state.engine, vcontact_element)
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
end
