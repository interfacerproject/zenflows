defmodule Zenflows.Valflow.Measure.Resolv do
@moduledoc "Resolvers of Measures."

alias Zenflows.Valflow.{Measure, Measure.Domain}

def has_unit(%Measure{} = meas, _args, _info) do
	meas = Domain.preload(meas, :has_unit)
	{:ok, meas.has_unit}
end
end
