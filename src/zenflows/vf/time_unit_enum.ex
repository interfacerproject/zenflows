# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.TimeUnitEnum do
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
