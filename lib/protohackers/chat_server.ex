# https://protohackers.com/problem/3

defmodule Protohackers.ChatServer.User do
  defstruct [:socket, :name]
end

defmodule Protohackers.ChatServer.Session do
  require Logger

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defstruct [:users]

  @impl true
  def init(_opts) do
    state = %__MODULE__{users: []}

    {:ok, state}
  end

  @impl true
  def handle_call({:join, joiner}, _, state) do
    Logger.debug("User joined")

    Enum.each(state.users, fn user ->
      :gen_tcp.send(user.socket, "* #{joiner.name} has entered the room")
    end)

    :gen_tcp.send(
      joiner.socket,
      "* The room contains: #{Enum.map(state.users, & &1.name) |> Enum.join(", ")}"
    )

    {:reply, :ok, %{state | users: state.users ++ [joiner]}}
  end

  @impl true
  def handle_call({:left, leaver}, _, state) do
    Logger.debug("User left")

    users = Enum.reject(state.users, fn user -> user.name == leaver.name end)

    Enum.each(users, fn user ->
      :gen_tcp.send(user.socket, "* #{user.name} has left the room")
    end)

    {:reply, :ok, %{state | users: users}}
  end

  @impl true
  def handle_call({:send_message, {sender, message}}, _, state) do
    state.users
    |> Enum.reject(fn user -> user.name == sender.name end)
    |> Enum.each(fn user ->
      :gen_tcp.send(user.socket, "[#{sender.name}] #{message}")
    end)

    {:reply, :ok, state}
  end
end

defmodule Protohackers.ChatServer do
  use GenServer

  alias __MODULE__.User

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)
    {:ok, _session} = __MODULE__.Session.start_link(nil)

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      packet: :line,
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
    :gen_tcp.send(socket, "Welcome to budgetchat! What shall I call you?")

    {:ok, name} = :gen_tcp.recv(socket, 0, 10_000)

    new_user = %User{name: String.trim(name), socket: socket}

    GenServer.call(
      __MODULE__.Session,
      {:join, new_user},
      5000
    )

    with {:error, reason} <- recv_until_valid_or_closed(new_user) do
      Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  defp recv_until_valid_or_closed(user) do
    case :gen_tcp.recv(user.socket, 0, 10_000) do
      {:ok, message} ->
        GenServer.call(
          __MODULE__.Session,
          {:send_message, {user, String.trim(message)}},
          5000
        )

        recv_until_valid_or_closed(user)

      {:error, :closed} ->
        GenServer.call(
          __MODULE__.Session,
          {:left, user},
          5000
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
