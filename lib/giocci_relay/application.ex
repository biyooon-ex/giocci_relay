defmodule GiocciRelay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {my_process_name, _} = System.get_env("MY_PROCESS_NAME") |> Code.eval_string()
    {target_engine_name, _} = System.get_env("TARGET_ENGINE_NAME") |> Code.eval_string()

    children = [
      # Starts a worker by calling: GiocciRelay.Worker.start_link(arg)
      # {GiocciRelay.Worker, arg}
      {GiocciRelay.Server, [my_process_name, target_engine_name]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
