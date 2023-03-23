defmodule ExRedshiftProxy.MessagesHelper do
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
      :length,
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

  def get_message_length_by_type(:msgNoTag, buffer) when byte_size(buffer) >= 4 do
    <<body_length::binary-size(4), _rest::binary>> = buffer

    %MessageLength{
      header_length: 4,
      body_length: :binary.decode_unsigned(body_length) - 4
    }
  end

  def get_message_length_by_type(:msgNoticeResponse, _buffer) do
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
end
