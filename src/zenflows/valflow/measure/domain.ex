defmodule Zenflows.Valflow.Measure.Domain do
@moduledoc "Domain logic of Measures."

alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.Measure

@spec preload(Measure.t(), :has_unit) :: Measure.t()
def preload(meas, :has_unit) do
	Repo.preload(meas, :has_unit)
end
end
