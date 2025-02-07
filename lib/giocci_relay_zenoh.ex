defmodule GiocciRelayZenoh do
  @moduledoc """
  ## Examples

      iex> GiocciRelayZenoh.setup_relay()

  """
  @doc """
    最初に指定された数のEngineノードとのZenohコネクションを作成する（clientは一個想定
  """
  # @deprecated
  def setup_relay() do
    ClientSessionNode.start_link(Config.client_node_name())
    EngineSessionNode.create_session(Config.engine_node_name())
  end
end
