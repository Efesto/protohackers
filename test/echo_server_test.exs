defmodule Protohackers.EchoServerTest do
  use ExUnit.Case

  test "accepts a connection and echoes back" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5002, mode: :binary, active: false)

    on_exit(fn ->
      :ok = :gen_tcp.close(socket)
    end)

    assert :gen_tcp.send(socket, "hey there") == :ok
    :gen_tcp.shutdown(socket, :write)

    assert :gen_tcp.recv(socket, 0, 5000) == {:ok, "hey there"}
  end
end
