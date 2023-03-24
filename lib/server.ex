defmodule ExRedshiftProxy.Server do
  require Logger

  alias ExRedshiftProxy.MessagesHelper

  def listen(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: true, reuseaddr: true, packet: 0, nodelay: true])

    Logger.info("Listening to 0.0.0.0:#{port}")

    # Handle incoming connections
    accept(socket)
  end

  defp accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pg_socket} =
      :gen_tcp.connect('0.0.0.0', 5432, [:binary, active: true, packet: 0, nodelay: true])

    {:ok, pid} =
      Task.Supervisor.start_child(ExRedshiftProxy.TaskSupervisor, fn ->
        serve_upstream(client, pg_socket)
      end)

    # Assign process responsible to receive the data from socket
    :ok = :gen_tcp.controlling_process(client, pid)

    {:ok, pid_postgres} =
      Task.Supervisor.start_child(ExRedshiftProxy.TaskSupervisor, fn ->
        serve_downstream(pg_socket, client)
      end)

    # Assign process responsible to receive the data from socket
    :ok = :gen_tcp.controlling_process(pg_socket, pid_postgres)

    accept(socket)
  end

  defp serve_upstream(source, destination, buffer \\ <<>>) do
    data = source |> receive_data
    buffer = handle_message_buffer(buffer <> data, destination)

    serve_upstream(source, destination, buffer)
  end

  defp serve_downstream(source, destination) do
    data = source |> receive_data
    :ok = :gen_tcp.send(destination, data)

    serve_downstream(source, destination)
  end

  defp handle_message_buffer(buffer, destination) when byte_size(buffer) >= 1 do
    message_type = MessagesHelper.get_message_type(buffer)
    message_length_info = MessagesHelper.get_message_length_by_type(message_type, buffer)

    # Handle Message from Buffer
    buffer |> handle_message(message_type, message_length_info.header_length, message_length_info.body_length, destination)
  end

  defp handle_message_buffer(buffer, _), do: buffer

  defp handle_message(buffer, type, header_length, body_length, destination) when byte_size(buffer) >= header_length + body_length do
    <<header::binary-size(header_length), rest::binary>> = buffer
    <<body::binary-size(body_length), other::binary>> = rest

    # Entire message buffer was received, we can handle it
    send_buffer =
      %MessagesHelper.Message{
        type: type,
        body_length: body_length,
        body: body,
        header: header,
        header_length: header_length
      } |> MessagesHelper.prepare_message_buffer()

    # Redirect message to Postgres connection
    :ok = :gen_tcp.send(destination, send_buffer)

    other
  end

  defp handle_message(buffer, _, _, _, _), do: buffer

  defp receive_data(socket) do
    receive do
      {:tcp, ^socket, data} -> data
    end
  end
end
