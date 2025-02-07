defmodule GiocciRelay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias GiocciRelay.Config

  @impl true
  def start(_type, _args) do
    {my_process_name, _} =
      Application.get_env(:giocci_relay, :system_variables)[:my_process_name]
      |> Code.eval_string()

    {node_engine_name, _} =
      Application.get_env(:giocci_relay, :system_variables)[:node_engine_name]
      |> Code.eval_string()

    ## durty fix: avoid errors caused by removed variables
    rpc_engine_name = "engine1"

    # # TODO： EngineのリストはDotenvyから読み込むようにする
    # engines = ["engine1", "engine2", "engine3", "engine4", "engine5"]
    engines = Config.engine_node_name()
    client = Config.client_node_name()

    giocci_relay_zenoh_engine_childlen =
      for engine <- engines do
        Supervisor.child_spec({GiocciRelayZenoh, engine}, id: String.to_atom(engine))
      end

    giocci_relay_zenoh_client_child = [
      Supervisor.child_spec({GiocciRelay.ClientSessionNode, client}, id: String.to_atom(client))
    ]

    children =
      [
        # Starts a worker by calling: GiocciRelay.Worker.start_link(arg)
        {GiocciRelay.Server, [my_process_name, node_engine_name, rpc_engine_name]}
      ] ++
        giocci_relay_zenoh_engine_childlen ++
        giocci_relay_zenoh_client_child

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
