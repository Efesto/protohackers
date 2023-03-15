defmodule Protohackers.EchoServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defstruct [:listen_socket]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        state = %__MODULE__{listen_socket: listen_socket}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        {:ok, data} = :gen_tcp.recv(socket, 0, 10_000)
        :ok = :gen_tcp.send(socket, data)
        :ok = :gen_tcp.close(socket)

      {:error, reason} ->
        {:stop, reason}
    end

    {:noreply, state, {:continue, :accept}}
  end
end
