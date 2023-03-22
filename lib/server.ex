defmodule ExRedshiftProxy.Server do
  require Logger

  def listen(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true, packet: 0, nodelay: true])

    Logger.info("Listening to 0.0.0.0:#{port}")

    # Handle incoming connections
    accept(socket)
  end

  defp accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pg_socket} =
      :gen_tcp.connect('0.0.0.0', 5432, [:binary, active: false, packet: 0, nodelay: true])

    {:ok, pid} =
      Task.Supervisor.start_child(ExRedshiftProxy.TaskSupervisor, fn ->
        serve(client, pg_socket)
      end)

    # Assign process responsible to receive the data from socket
    :ok = :gen_tcp.controlling_process(client, pid)

    {:ok, pid_postgres} =
      Task.Supervisor.start_child(ExRedshiftProxy.TaskSupervisor, fn ->
        serve(pg_socket, client)
      end)

    # Assign process responsible to receive the data from socket
    :ok = :gen_tcp.controlling_process(pg_socket, pid_postgres)

    accept(socket)
  end

  defp serve(source, destination, buffer \\ <<>>) do
    # Receive message from source socket until doesn't have any packet to receive anymore
    case :gen_tcp.recv(source, 0) do
      {:ok, data} ->
        # Redirect received data to destination socket
        :gen_tcp.send(destination, data)

        # Loop serve function to receive the rest of message
        serve(source, destination, data <> buffer)
      {:error, :closed} ->
        # Entire message received, we can parse it
        buffer
      {:error, reason} ->
        Logger.error("An error occurred while receiving socket message #{inspect reason}")
    end
  end
end
