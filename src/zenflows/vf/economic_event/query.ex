# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.EconomicEvent.Query do
@moduledoc false

import Ecto.Query

alias Ecto.{Multi, Queryable}
alias Zenflows.DB.{Repo, Schema}
alias Zenflows.VF.{EconomicEvent, EconomicResource, Process}

@spec previous(Schema.id()) :: nil | Queryable.t()
def previous(id) do
	Multi.new()
	|> Multi.run(:event, fn repo, _ ->
		where(EconomicEvent, id: ^id)
		|> select(~w[
			action_id output_of_id triggered_by_id
			resource_inventoried_as_id previous_event_id
		]a)
		|> repo.one()
		|> case do
			nil -> {:error, "does not exist"}
			v -> {:ok, v}
		end
	end)
	|> Multi.run(:query, fn _, %{event: evt} ->
		{:ok, cond do
			evt.output_of_id != nil ->
				where(Process, id: ^evt.output_of_id)
			evt.triggered_by_id != nil ->
				where(EconomicEvent, id: ^evt.triggered_by_id)
			evt.action_id == "raise" and evt.previous_event_id == nil ->
				nil
			evt.resource_inventoried_as_id != nil ->
				where(EconomicResource, id: ^evt.resource_inventoried_as_id)
			true ->
				nil
		end}
	end)
	|> Repo.transaction()
	|> case do
		# Instead of returning and error, we return nil
		# just so because we did the same thing with other
		# "previous" queries.  We returned empty lists to
		# indicate nilness.
		{:ok, %{query: q}} -> q
		{:error, _, _, _} -> nil
	end
end
end
