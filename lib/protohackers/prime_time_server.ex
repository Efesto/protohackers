defmodule Protohackers.PrimeTimeServer do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    # see https://www.erlang.org/doc/man/inet.html#setopts-2 for options
    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      packet: :line,
      buffer: _100_kb = 1024 * 100
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Logger.debug("Received connection to: #{inspect(__MODULE__)}")

        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(socket)
        end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp handle_connection(socket) do
    with {:error, reason} <- recv_until_valid_or_closed(socket) do
      Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  @request_separator ?\n

  defp recv_until_valid_or_closed(socket) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} ->
        case parse_request(data) do
          {:ok, response} ->
            :gen_tcp.send(socket, [Jason.encode!(response), @request_separator])
            recv_until_valid_or_closed(socket)

          {:error, :malformed_request} ->
            :gen_tcp.send(socket, ["noop", @request_separator])
        end

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_request(request) do
    case Jason.decode(request) do
      {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
        {:ok, %{method: "isPrime", prime: prime?(number)}}

      _ ->
        {:error, :malformed_request}
    end
  end

  defp prime?(number) when is_float(number), do: false
  defp prime?(number) when number <= 1, do: false
  defp prime?(number) when number in [2, 3], do: true

  defp prime?(number) do
    not Enum.any?(2..trunc(:math.sqrt(number)), &(rem(number, &1) == 0))
  end
end
