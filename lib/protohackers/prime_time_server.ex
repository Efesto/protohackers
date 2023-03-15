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

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false
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
        Logger.debug("Received connection to #{inspect(__MODULE__)}")

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

  defp recv_until_valid_or_closed(socket) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} ->
        # this assumes that data is always a valid request

        Logger.debug("Parsing data: #{inspect(data)}")

        case process_data(data) do
          {:ok, response} ->
            :gen_tcp.send(socket, response)
            recv_until_valid_or_closed(socket)

          {:error, response} ->
            :gen_tcp.send(socket, response)
        end

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @request_separator "\n"

  defp process_data(data) do
    response =
      data
      |> String.trim()
      |> String.split(@request_separator)
      |> Enum.reduce_while(_response = "", fn request, acc ->
        case parse_request(request) do
          {:ok, response} -> {:cont, [acc, Jason.encode!(response) <> @request_separator]}
          {:error, :malformed_request} -> {:halt, {:error, [acc, "noop#{@request_separator}"]}}
        end
      end)

    case response do
      {:error, response} -> {:error, response}
      response -> {:ok, response}
    end
  end

  defp parse_request(request) do
    case Jason.decode(request) do
      {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
        {:ok, %{method: "isPrime", prime: Prime.test(number)}}

      _ ->
        {:error, :malformed_request}
    end
  end
end
