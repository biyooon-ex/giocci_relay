defmodule GiocciRelayZenoh do
  alias GiocciRelay.Config, as: RelayConfig

  @moduledoc """
  ## Examples

      iex> GiocciRelayZenoh.setup_relay()

  """
  @doc """
    最初に指定された数のEngineノードとのZenohコネクションを作成する（clientは一個想定
  """
  # @deprecated
  def setup_relay() do
    GiocciRelay.ClientSessionNode.start_link(RelayConfig.client_node_name())
    GiocciRelay.EngineSessionNode.create_session(RelayConfig.engine_node_name())
  end
end
