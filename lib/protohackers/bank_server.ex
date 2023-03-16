defmodule Protohackers.BankServer do
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
    with {:error, reason} <- recv_until_closed(socket, _session = []) do
      Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  defp recv_until_closed(socket, session) do
    # see https://www.erlang.org/doc/reference_manual/expressions.html#bit-syntax-expressions for bit syntax expression

    case :gen_tcp.recv(socket, _message_size = 9, 10_000) do
      {:ok, "Q" <> <<min_time::32-signed-big>> <> <<max_time::32-signed-big>>} ->
        mean_value = average(session, min_time, max_time)
        :gen_tcp.send(socket, <<mean_value::32-signed-big>>)
        recv_until_closed(socket, session)

      {:ok, "I" <> <<timestamp::32-signed-big>> <> <<value::32-signed-big>>} ->
        recv_until_closed(socket, insert(session, timestamp, value))

      {:error, :closed} ->
        {:ok, session}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert(session, timestamp, value) do
    Logger.debug("Insert #{inspect({timestamp, value})}")

    [{timestamp, value}] ++ session
  end

  defp average(session, min_time, max_time) do
    filtered_values =
      session
      |> Enum.filter(fn {timestamp, _value} ->
        min_time <= timestamp and timestamp <= max_time
      end)
      |> Enum.map(&elem(&1, 1))

    case filtered_values do
      [] ->
        0

      _ ->
        filtered_values
        |> Enum.sum()
        |> div(length(filtered_values))
    end
  end
end
