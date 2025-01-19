defmodule GiocciRelay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {my_process_name, _} =
      Application.get_env(:giocci_relay, :system_variables)[:my_process_name]
      |> Code.eval_string()

    {node_engine_name, _} =
      Application.get_env(:giocci_relay, :system_variables)[:node_engine_name]
      |> Code.eval_string()

    rpc_engine_name =
      Application.get_env(:giocci_relay, :system_variables)[:rpc_engine_name] |> String.to_atom()

    children = [
      # Starts a worker by calling: GiocciRelay.Worker.start_link(arg)
      GiocciRelay.Zenoh,
      {GiocciRelay.Server, [my_process_name, node_engine_name, rpc_engine_name]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
