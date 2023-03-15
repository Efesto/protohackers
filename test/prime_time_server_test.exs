defmodule Protohackers.PrimeTimeServerTest do
  use ExUnit.Case, async: true

  test "accepts a requests and replies to each" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)

    assert :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":13}\n") == :ok

    assert :gen_tcp.recv(socket, 0, 10000) == {:ok, "{\"method\":\"isPrime\",\"prime\":true}\n"}

    request = """
    {\"method\":\"isPrime\",\"number\":-5,\"something_else\":333}
    {\"number\":141256,\"method\":\"isPrime\"}
    {\"method\":\"isPrime\"}
    {\"method\":\"isPrime\",\"number\":13}
    """

    assert :gen_tcp.send(socket, request) == :ok

    expected_response = """
    {\"method\":\"isPrime\",\"prime\":false}
    {\"method\":\"isPrime\",\"prime\":false}
    noop
    """

    assert :gen_tcp.recv(socket, 0, 10000) == {:ok, expected_response}
    assert :gen_tcp.recv(socket, 0, 5000) == {:error, :closed}
  end
end
