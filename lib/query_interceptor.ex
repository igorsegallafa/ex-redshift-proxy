defmodule ExRedshiftProxy.QueryInterceptor do
  alias ExRedshiftProxy.RewriteCreateTableQuery

  def handle_query(query) do
    query
    |> RewriteCreateTableQuery.process()
  end
end
