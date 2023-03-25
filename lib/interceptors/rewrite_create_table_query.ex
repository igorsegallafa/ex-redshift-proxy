defmodule ExRedshiftProxy.RewriteCreateTableQuery do
  @max_regex ~r/\(max\)/i
  @encode_regex ~r/ENCODE \w*/i
  @getdate_regex ~r/getdate\(\)/i
  @type_regex ~r/(?<=bigint)\(\d+\)/i
  @diststyle_regex ~r/(DISTSTYLE \w*|SORTKEY.*\(.*\)|DISTKEY.*\(.*\)|DISTKEY)/i

  def process(query) do
    query
    |> String.replace(@diststyle_regex, "")
    |> String.replace(@encode_regex, "")
    |> String.replace(@type_regex, "")
    |> String.replace(@max_regex, "(4096)")
    |> String.replace(@getdate_regex, "now()")
  end
end
