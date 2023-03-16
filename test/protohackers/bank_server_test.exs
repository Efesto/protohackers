defmodule Protohackers.BankServerTest do
  use ExUnit.Case, async: true

  test "implements example" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false)

    assert :gen_tcp.send(socket, query_message(0, 1000)) == :ok
    assert :gen_tcp.recv(socket, 4, 5000) == {:ok, <<0::32-signed-big>>}

    assert :gen_tcp.send(socket, query_message(1000, 0)) == :ok
    assert :gen_tcp.recv(socket, 4, 5000) == {:ok, <<0::32-signed-big>>}

    assert :gen_tcp.send(socket, insert_message(12345, 101)) == :ok
    assert :gen_tcp.send(socket, insert_message(12346, 102)) == :ok
    assert :gen_tcp.send(socket, insert_message(12347, 100)) == :ok
    assert :gen_tcp.send(socket, insert_message(40960, 5)) == :ok

    assert :gen_tcp.send(socket, query_message(12288, 16485)) == :ok
    assert :gen_tcp.recv(socket, 4, 5000) == {:ok, <<101::32-signed-big>>}
  end

  test "average value is rounded down" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false)

    assert :gen_tcp.send(socket, insert_message(0, 1)) == :ok
    assert :gen_tcp.send(socket, insert_message(0, 0)) == :ok

    assert :gen_tcp.send(socket, query_message(0, 100)) == :ok
    assert :gen_tcp.recv(socket, 4, 5000) == {:ok, <<0::32-signed-big>>}
  end

  defp query_message(min_time, max_time) do
    "Q" <> <<min_time::32-signed-big>> <> <<max_time::32-signed-big>>
  end

  defp insert_message(timestamp, price) do
    "I" <> <<timestamp::32-signed-big>> <> <<price::32-signed-big>>
  end
end
