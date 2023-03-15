defmodule Protohackers.PrimeTimeServerTest do
  use ExUnit.Case, async: true

  test "accepts a requests and replies to each" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)

    request = """
    {\"method\":\"isPrime\",\"number\":123,\"something_else\":333}
    {\"method\":\"isPrime\"}
    {\"method\":\"isPrime\",\"number\":13}
    """

    assert :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":13}\n") == :ok
    assert :gen_tcp.send(socket, request) == :ok

    :gen_tcp.shutdown(socket, :write)

    expected_response = """
    {\"method\":\"isPrime\",\"prime\":true}
    {\"method\":\"isPrime\",\"prime\":false}
    noop
    """

    assert :gen_tcp.recv(socket, 0, 5000) == {:ok, expected_response}

    assert :gen_tcp.send(socket, "yet another request") == {:error, :closed}
  end
end
