defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias Protohackers.EchoServer
  alias Protohackers.PrimeTimeServer
  alias Protohackers.BankServer

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {EchoServer, port: 5002},
      {PrimeTimeServer, port: 5003},
      {BankServer, port: 5004}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
