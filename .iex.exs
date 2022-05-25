if Code.ensure_loaded?(ExSync) and function_exported?(ExSync, :register_group_leader, 0) do
	ExSync.register_group_leader()
end

alias Zenflows.DB
alias Zenflows.DB.Repo
alias Zenflows.VF
alias Zenflows.GQL
alias Zenflows.GQL.Schema
