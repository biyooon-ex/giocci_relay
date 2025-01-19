defmodule GiocciRelay.Zenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelayZenoh.setup_relay()

  """
  use Supervisor
  require Logger

  @doc "Start Subscriber."
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc false
  def init(_args) do
    children = [
      GiocciRelay.Zenoh.Impl
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
