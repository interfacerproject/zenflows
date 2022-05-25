defmodule Zenflows.VF.Measure.Resolv do
@moduledoc "Resolvers of Measures."

alias Zenflows.VF.{Measure, Measure.Domain}

def has_unit(%Measure{} = meas, _args, _info) do
	meas = Domain.preload(meas, :has_unit)
	{:ok, meas.has_unit}
end
end
