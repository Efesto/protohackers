defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @servers [
    Protohackers.EchoServer,
    Protohackers.PrimeTimeServer,
    Protohackers.BankServer,
    Protohackers.ChatServer
  ]

  @impl true
  def start(_type, _args) do
    {children, _} =
      Enum.map_reduce(@servers, 5002, fn server, port ->
        {{server, port: port}, port + 1}
      end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
