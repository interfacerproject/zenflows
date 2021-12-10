defmodule Zenflows.Valflow.TimeUnit.Type do
@moduledoc "GraphQL types of TimeUnits."

use Absinthe.Schema.Notation

@desc "Defines the unit of time measured in a temporal `Duration`."
enum :time_unit do
	value :year,   name: "year"
	value :month,  name: "month"
	value :week,   name: "week"
	value :day,    name: "day"
	value :hour,   name: "hour"
	value :minute, name: "minute"
	value :second, name: "second"
end
end
