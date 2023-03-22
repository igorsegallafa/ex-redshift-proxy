defmodule ExRedshiftProxy do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ExRedshiftProxy.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> ExRedshiftProxy.Server.listen(5439) end},
        restart: :permanent
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
