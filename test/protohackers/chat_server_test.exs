defmodule Protohackers.ChatServerTest do
  use ExUnit.Case, async: true

  test "accepts multiple user connections" do
    user_1_socket = connect()
    user_2_socket = connect()

    on_exit(fn ->
      :gen_tcp.close(user_1_socket)
      :gen_tcp.close(user_2_socket)
    end)

    assert :gen_tcp.recv(user_1_socket, 0, 5000) ==
             {:ok, "Welcome to budgetchat! What shall I call you?"}

    assert :gen_tcp.recv(user_2_socket, 0, 5000) ==
             {:ok, "Welcome to budgetchat! What shall I call you?"}

    tcp_send(user_1_socket, "Mike")
    assert :gen_tcp.recv(user_1_socket, 0, 5000) == {:ok, "* The room contains: "}

    tcp_send(user_2_socket, "Bob")

    assert :gen_tcp.recv(user_1_socket, 0, 5000) == {:ok, "* Bob has entered the room"}
    assert :gen_tcp.recv(user_2_socket, 0, 5000) == {:ok, "* The room contains: Mike"}

    tcp_send(user_1_socket, "Hello Bob")
    assert :gen_tcp.recv(user_2_socket, 0, 5000) == {:ok, "[Mike] Hello Bob"}
    tcp_send(user_2_socket, "Hello Mike")
    assert :gen_tcp.recv(user_1_socket, 0, 5000) == {:ok, "[Bob] Hello Mike"}

    :gen_tcp.close(user_1_socket)

    assert :gen_tcp.recv(user_2_socket, 0, 5000) == {:ok, "* Bob has left the room"}

    :gen_tcp.close(user_2_socket)
  end

  defp tcp_send(socket, data) do
    assert :gen_tcp.send(socket, data <> "\n") == :ok
  end

  defp connect do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5005, mode: :binary, active: false)
    socket
  end
end
