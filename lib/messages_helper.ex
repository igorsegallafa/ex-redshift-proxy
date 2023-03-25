defmodule ExRedshiftProxy.MessagesHelper do
  alias ExRedshiftProxy.QueryInterceptor

  # References:
  # https://github.com/kfzteile24/postgresql-proxy
  # https://docs.statetrace.com/blog/build-a-postgres-proxy/

  defmodule MessageLength do
    defstruct [
      :header_length,
      :body_length,
    ]
  end

  defmodule Message do
    defstruct [
      :type,
      :body_length,
      :header_length,
      :header,
      :body,
    ]
  end

  @messages_type %{
    ?1 => :parse_complete,
    ?2 => :bind_complete,
    ?3 => :close_complete,
    ?A => :notification_response,
    ?c => :copy_done,
    ?C => :command_complete,
    ?d => :copy_data,
    ?D => :data_row,
    ?E => :error_response,
    ?f => :fail,
    ?G => :copy_in_response,
    ?H => :copy_out_response,
    ?I => :empty_query_response,
    ?K => :backend_key_data,
    ?n => :no_data,
    ?N => :notice_response,
    ?R => :authentication,
    ?s => :portal_suspended,
    ?S => :parameter_status,
    ?t => :parameter_description,
    ?T => :row_description,
    ?p => :password_message,
    ?W => :copy_both_response,
    ?Q => :query,
    ?X => :terminate,
    ?Z => :ready_for_query,
    ?P => :parse,
    ?B => :bind
  }

  def get_message_type(buffer) do
    <<type::size(8), _rest::binary>> = buffer

    @messages_type |> Map.get(type, :undefined)
  end

  def get_message_type_value(type) do
    @messages_type
    |> Enum.find(fn {_k, v} -> v == type end)
    |> elem(0)
  end

  def get_message_length_by_type(:undefined, buffer) when byte_size(buffer) >= 4 do
    <<body_length::binary-size(4), _rest::binary>> = buffer

    %MessageLength{
      header_length: 4,
      body_length: :binary.decode_unsigned(body_length) - 4
    }
  end

  def get_message_length_by_type(:notice_response, _buffer) do
    %MessageLength{
      header_length: 1,
      body_length: 0
    }
  end

  def get_message_length_by_type(_, buffer) when byte_size(buffer) >= 5 do
    <<_type::binary-size(1), rest::binary>> = buffer
    <<body_length::binary-size(4), _rest::binary>> = rest

    %MessageLength{
      header_length: 5,
      body_length: :binary.decode_unsigned(body_length) - 4
    }
  end

  def get_message_length_by_type(_, _), do: :undefined

  def prepare_message_buffer(message = %Message{type: message_type}) when message_type not in [:undefined, :notice_response] do
    message_type_value = get_message_type_value(message_type)

    message = process_message(message)
    length = byte_size(message.body) + message.header_length - 1

    header = <<message_type_value::size(8), length::size(32)>>
    header <> message.body
  end

  def prepare_message_buffer(%Message{body: body, header: header}), do: header <> body

  defp process_message(message = %Message{type: :query}) do
    query = QueryInterceptor.handle_query(message.body)

    %Message{message | body: query, body_length: byte_size(query)}
  end

  defp process_message(message = %Message{body: buffer, type: :parse}) do
    query_length = message.body_length - 3 # Body Length - Statement - Params

    <<statement::binary-size(1), rest::binary>> = buffer
    <<query::binary-size(query_length), params::binary>> = rest
    <<params::binary-size(2)>> = params

    query = QueryInterceptor.handle_query(query)
    body = statement <> query <> params

    %Message{message | body: body, body_length: byte_size(body)}
  end

  defp process_message(message = %Message{}), do: message
end
