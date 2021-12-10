defmodule Zenflows.Valflow.TimeUnitEnum do
@moduledoc """
Custom Ecto type for TimeUnit definitions in schemas.
"""

use Ecto.Type

@type t() :: :year | :month | :week | :day | :hour | :minute | :second

@spec values() :: [t(), ...]
def values() do
	~w[year month week day hour minute second]a
end

@impl true
def type() do
	:string
end

@impl true
def cast(:year), do: {:ok, :year}
def cast(:month), do: {:ok, :month}
def cast(:week), do: {:ok, :week}
def cast(:day), do: {:ok, :day}
def cast(:hour), do: {:ok, :hour}
def cast(:minute), do: {:ok, :minute}
def cast(:second), do: {:ok, :second}
def cast(_), do: :error

@impl true
def dump(:year), do: {:ok, "year"}
def dump(:month), do: {:ok, "month"}
def dump(:week), do: {:ok, "week"}
def dump(:day), do: {:ok, "day"}
def dump(:hour), do: {:ok, "hour"}
def dump(:minute), do: {:ok, "minute"}
def dump(:second), do: {:ok, "second"}
def dump(_), do: :error

@impl true
def load("year"), do: {:ok, :year}
def load("month"), do: {:ok, :month}
def load("week"), do: {:ok, :week}
def load("day"), do: {:ok, :day}
def load("hour"), do: {:ok, :hour}
def load("minute"), do: {:ok, :minute}
def load("second"), do: {:ok, :second}
def load(_), do: :error
end
