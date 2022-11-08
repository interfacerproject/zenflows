# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.EconomicEvent.Domain do
@moduledoc "Domain logic of EconomicEvents."

import Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	Action,
	EconomicEvent,
	EconomicResource,
	Measure,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, EconomicEvent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(EconomicEvent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: EconomicEvent.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [EconomicEvent.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(EconomicEvent, page)}
end

@spec all!(Page.t()) :: [EconomicEvent.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(Schema.params(), nil | Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def create(evt_params, res_params \\ nil) do
	key = multi_key()
	Multi.new()
	|> multi_insert(evt_params, res_params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(Schema.params(), nil | Schema.params()) :: EconomicEvent.t()
def create!(evt_params, res_params \\ nil) do
	{:ok, value} = create(evt_params, res_params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def update(id, params) do
	key = multi_key()
	Multi.new()
	|> multi_update(id, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(Schema.id(), Schema.params()) :: EconomicEvent.t()
def update!(id, params) do
	# `__MODULE__` because it confilicts with `import Ecto.Query`
	{:ok, value} = __MODULE__.update(id, params)
	value
end

@spec preload(EconomicEvent.t(), :action | :input_of | :output_of
		| :provider | :receiver
		| :resource_inventoried_as | :to_resource_inventoried_as
		| :resource_conforms_to | :resource_quantity | :effort_quantity
		| :to_location | :at_location | :realization_of | :triggered_by)
	:: EconomicEvent.t()
def preload(eco_evt, x) when x in ~w[
	input_of output_of provider receiver
	resource_inventoried_as to_resource_inventoried_as
	resource_conforms_to to_location at_location realization_of
	triggered_by
]a do
	Repo.preload(eco_evt, x)
end
def preload(eco_evt, :action),
	do: Action.preload(eco_evt, :action)
def preload(eco_evt, x) when x in ~w[resource_quantity effort_quantity]a,
	do: Measure.preload(eco_evt, x)

@spec multi_key() :: atom()
def multi_key(), do: :economic_event

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params(), nil | Schema.params())
	:: Multi.t()
def multi_insert(m, key \\ multi_key(), evt_params, res_params) do
	m
	|> Multi.insert("#{key}.created", EconomicEvent.changeset(evt_params))
	|> Multi.merge(&handle_insert(key, Map.fetch!(&1, "#{key}.created"), res_params))
end

# Handle the part after the event is created.  These clauses deal with
# validations, creation of resources, and any other side-effects.
#
# It either returns the given `evt` as it is under the name `key`,
# or updates `evt` and returns it under the name `key`.
@spec handle_insert(term(), EconomicEvent.t(), nil | Schema.params()) :: Multi.t()
defp handle_insert(key, %{action_id: action_id} = evt, res_params)
		when action_id in ["raise", "produce"] do
	cond do
		evt.resource_conforms_to_id != nil ->
			res_params =
				(res_params || %{})
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, evt.resource_conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> Map.put(:classified_as, evt.resource_classified_as)

			Multi.new()
			|> EconomicResource.Domain.multi_insert("#{key}.eco_res", res_params)
			|> Multi.update(key, &Changeset.change(evt,
				resource_inventoried_as_id: &1 |> Map.fetch!("#{key}.eco_res") |> Map.fetch!(:id)))
		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run("#{key}.checks", fn repo, _ ->
				fields = ~w[
					primary_accountable_id custodian_id
					accounting_quantity_has_unit_id
				]a
				res = from(
					r in EconomicResource,
					where: [id: ^evt.resource_inventoried_as_id],
					select: merge(map(r, ^fields), %{
						contained?: not is_nil(r.contained_in_id), # is it contained in something?
					})
				)
				|> repo.one!()
				res = Map.put(res, :container?,
					where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id)
					|> repo.exists?())

				cond do
					evt.provider_id != res.primary_accountable_id or evt.provider_id != res.custodian_id ->
						{:error, "you don't have ownership over this resource"}
					evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
						{:error, "the unit of resource quantity must match with the unit of this resource"}
					res.contained? ->
						{:error, "you can't #{action_id} into a contained resource"}
					res.container? ->
						{:error, "you can't #{action_id} into a container resource"}
					true ->
						{:ok, nil}
				end
			end)
			|> Multi.update_all("#{key}.inc", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
			|> Multi.put(key, evt)
	end
end
defp handle_insert(key, %{action_id: action_id} = evt, _)
		when action_id in ["lower", "consume"] do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		fields = ~w[
			primary_accountable_id custodian_id
			accounting_quantity_has_unit_id
		]a
		res = from(
			r in EconomicResource,
			where: [id: ^evt.resource_inventoried_as_id],
			select: merge(map(r, ^fields), %{
				contained?: not is_nil(r.contained_in_id), # is it contained in something?
			})
		)
		|> repo.one!()
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id)
			|> repo.exists?())

		cond do
			evt.provider_id != res.primary_accountable_id or evt.provider_id != res.custodian_id ->
				{:error, "you don't have ownership over this resource"}
			evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of this resource"}
			res.contained? -> # TODO: study combine-separate
				{:error, "you can't #{action_id} a contained resource"}
			res.container? ->
				{:error, "you can't #{action_id} a container resource"}
			true ->
				{:ok, nil}
		end
	end)
	|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
		onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
	])
	|> Multi.put(key, evt)
end
defp handle_insert(key, %{action_id: action_id} = evt, _)
		when action_id in ~w[work deliverService] do
	Multi.put(Multi.new(), key, evt)
end
defp handle_insert(key, %{action_id: "use"} = evt, _) do
	cond do
		evt.resource_conforms_to_id != nil ->
			Multi.put(Multi.new(), key, evt)
		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run("#{key}.checks", fn repo, _ ->
				fields = if evt.resource_quantity != nil,
					do: [:accounting_quantity_has_unit_id],
					else: []

				res = from(
					r in EconomicResource,
					where: [id: ^evt.resource_inventoried_as_id],
					select: merge(map(r, ^fields), %{
						contained?: not is_nil(r.contained_in_id), # is it contained in something?
					})
				)
				|> repo.one!()
				res = Map.put(res, :container?,
					where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id)
					|> repo.exists?())

				cond do
					evt.resource_quantity && (evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id) ->
						{:error, "the unit of resource quantity must match with the unit of this resource"}
					res.contained? -> # TODO: study combine-separate
						{:error, "you can't use a contained resource"}
					res.container? ->
						{:error, "you can't use a container resource"}
					true ->
						{:ok, nil}
				end
			end)
			|> Multi.put(key, evt)
	end
end
defp handle_insert(key, %{action_id: "cite"} = evt, _) do
	cond do
		evt.resource_conforms_to_id != nil ->
			Multi.put(Multi.new(), key, evt)
		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run("#{key}.checks", fn repo, _ ->
				res = from(
					r in EconomicResource,
					where: [id: ^evt.resource_inventoried_as_id],
					select: merge(map(r, [:accounting_quantity_has_unit_id]), %{
						contained?: not is_nil(r.contained_in_id), # is it contained in something?
					})
				)
				|> repo.one!()
				res = Map.put(res, :container?,
					where(EconomicResource, contained_in_id: ^res.id) |> repo.exists?())

				cond do
					evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
						{:error, "the unit of resource quantity must match with the unit of this resource"}
					res.contained? -> # TODO: study combine-separate
						{:error, "you can't cite a contained resource"}
					res.container? ->
						{:error, "you can't cite a container resource"}
					true ->
						{:ok, nil}
				end
			end)
			|> Multi.put(key, evt)
	end
end
defp handle_insert(key, %{action_id: "pickup"} = evt, _) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		fields = ~w[
			custodian_id
			onhand_quantity_has_numerical_value onhand_quantity_has_unit_id
		]a
		res = from(
			r in EconomicResource,
			where: [id: ^evt.resource_inventoried_as_id],
			select: merge(map(r, ^fields), %{
				contained?: not is_nil(r.contained_in_id), # is it contained in something?
			})
		)
		|> repo.one!()

		not_single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "pickup"
					and e.input_of_id == ^evt.input_of_id)
			|> repo.exists?()
		end

		cond do
			evt.provider_id != res.custodian_id ->
				{:error, "you don't have custody over this resource"}
			res.contained? -> # TODO: study combine-separate
				{:error, "you can't pickup a contained resource"}
			evt.resource_quantity_has_unit_id != res.onhand_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of this resource"}
			# This also handles the requirement that the
			# resource's onhand quantity must be positive.
			# This is guranteed because of the check below
			# and the requriment that the resource quantity
			# of events must be positive.
			evt.resource_quantity_has_numerical_value != res.onhand_quantity_has_numerical_value ->
				{:error, "the pickup events need to fully pickup the resource"}
			not_single_ref?.() ->
				{:error,
					"no more than one pickup event in the same process, referring to the same resource is allowed"}
			true ->
				{:ok, nil}
		end
	end)
	|> Multi.put(key, evt)
end
defp handle_insert(key, %{action_id: "dropoff"} = evt, _) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		pair_evt =
			from(e in EconomicEvent,
				where: e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.action_id == "pickup"
					and e.input_of_id == ^evt.output_of_id,
				select: map(e, ~w[
					provider_id
					resource_quantity_has_numerical_value resource_quantity_has_unit_id
				]a))
			|> repo.one!()

		not_single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "dropoff"
					and e.output_of_id == ^evt.output_of_id)
			|> repo.exists?()
		end

		container? = fn ->
			where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id)
			|> repo.exists?()
		end

		cond do
			evt.provider_id != pair_evt.provider_id ->
				{:error, "you don't have custody over this resource"}
			evt.resource_quantity_has_unit_id != pair_evt.resource_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of the paired event"}
			container?.() && evt.resource_quantity_has_numerical_value != pair_evt.resource_quantity_has_numerical_value ->
				{:error, "the dropoff events need to fully dropoff the resource"}
			not_single_ref?.() ->
				{:error,
					"no more than one dropoff event in the same process, referring to the same resource is allowed"}
			true ->
				{:ok, nil}
		end
	end)
	|> Multi.run("#{key}.set", fn repo, _ ->
		if evt.to_location_id do
			q = where(EconomicResource, [r],
					r.id == ^evt.resource_inventoried_as_id
						or r.contained_in_id == ^evt.resource_inventoried_as_id)
			{:ok, repo.update_all(q, set: [current_location_id: evt.to_location_id])}
		else
			{:ok, nil}
		end
	end)
	|> Multi.put(key, evt)
end
defp handle_insert(key, %{action_id: "accept"} = evt, _) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		fields = ~w[
			custodian_id
			onhand_quantity_has_numerical_value onhand_quantity_has_unit_id
		]a
		res = from(
			r in EconomicResource,
			where: [id: ^evt.resource_inventoried_as_id],
			select: merge(map(r, ^fields), %{
				contained?: not is_nil(r.contained_in_id), # is it contained in something?
			})
		)
		|> repo.one!()
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id)
			|> repo.exists?())

		not_single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "accept"
					and e.input_of_id == ^evt.input_of_id)
			|> repo.exists?()
		end

		any_combine_separate? = fn ->
			where(EconomicEvent, [e],
				(e.action_id == "combine" and e.input_of_id == ^evt.input_of_id)
				or
				(e.action_id == "separate" and e.output_of_id == ^evt.input_of_id))
			|> repo.exists?()
		end

		cond do
			evt.provider_id != res.custodian_id ->
				{:error, "you don't have custody over this resource"}

			res.contained? ->
				{:error, "you can't accept a contained resource"}

			evt.resource_quantity_has_unit_id != res.onhand_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of this resource"}

			evt.resource_quantity_has_numerical_value != res.onhand_quantity_has_numerical_value ->
				{:error, "the accept events need to fully accept the resource"}

			res.container? and res.onhand_quantity_has_numerical_value <= 0 ->
				{:error, "the accept events need container resources to have positive onhand quantity"}

			any_combine_separate?.() ->
				{:error, "you can't add another accept event to the same process where there are at least one combine or separate events"}

			not_single_ref?.() ->
				{:error, "no more than one accept event in the same process, referring to the same resource is allowed"}

			true ->
				{:ok, nil}
		end
	end)
	|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
	])
	|> Multi.put(key, evt)
end
defp handle_insert(key, %{action_id: "modify"} = evt, _) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		pair_evt =
			from(e in EconomicEvent,
				where: e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.action_id == "accept"
					and e.input_of_id == ^evt.output_of_id,
				select: map(e, ~w[
					provider_id
					resource_quantity_has_numerical_value resource_quantity_has_unit_id
				]a))
			|> repo.one!()

		not_single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "modify"
					and e.output_of_id == ^evt.output_of_id)
			|> repo.exists?()
		end

		cond do
			evt.provider_id != pair_evt.provider_id ->
				{:error, "you don't have custody over this resource"}
			evt.resource_quantity_has_unit_id != pair_evt.resource_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of the paired event"}
			evt.resource_quantity_has_numerical_value != pair_evt.resource_quantity_has_numerical_value ->
				{:error, "the modify events need to fully modify the resource"}
			not_single_ref?.() ->
				{:error, "no more than one modify event in the same process, referring to the same resource is allowed"}
			true ->
				{:ok, nil}
		end
	end)
	|> Multi.update_all("#{key}.inc", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
	])
	|> Multi.update_all("#{key}.stage", fn _ ->
		from(r in EconomicResource,
			join: e in EconomicEvent, on: e.id == ^evt.id,
			join: p in assoc(e, :output_of),
			where: r.id == e.resource_inventoried_as_id,
			update: [set: [stage_id: p.based_on_id]])
	end, [])
	|> Multi.put(key, evt)
end
defp handle_insert(key, %{action_id: "transferCustody"} = evt, res_params) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		%{resource_inventoried_as_id: res_id, to_resource_inventoried_as_id: to_res_id} = evt
		res_ids =
			if to_res_id do
				[res_id, to_res_id]
			else
				[res_id]
			end
		fields = ~w[
			id custodian_id conforms_to_id
			onhand_quantity_has_numerical_value onhand_quantity_has_unit_id

			name note tracking_identifier okhv repo version licensor license metadata
			classified_as
		]a
		{res, to_res} =
			from(r in EconomicResource,
				where: r.id in ^res_ids,
				select: merge(map(r, ^fields), %{
					contained?: not is_nil(r.contained_in_id), # is it contained in something?
				}))
			|> repo.all()
			|> case do
				[%{id: ^res_id} = res] -> {res, nil}
				[%{id: ^res_id} = res, %{id: ^to_res_id} = to_res] -> {res, to_res}
				[%{id: ^to_res_id} = to_res, %{id: ^res_id} = res] -> {res, to_res}
			end
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^res_id) |> repo.exists?())
		to_res = to_res
			&& Map.put(to_res, :container?,
				where(EconomicResource, contained_in_id: ^to_res_id) |> repo.exists?())

		cond do
			evt.provider_id != res.custodian_id ->
				{:error, "you don't have custody over this resource"}
			res.contained? ->
				{:error, "you can't transfer-custody a contained resource"}
			evt.resource_quantity_has_unit_id != res.onhand_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"}
			res.container? and res.onhand_quantity_has_numerical_value <= 0 ->
				{:error, "the transfer-custody events need container resources to have positive onhand-quantity"}
			res.container? && evt.resource_quantity_has_numerical_value != res.onhand_quantity_has_numerical_value ->
				{:error, "the transfer-custody events need to fully transfer the resource"}
			res.container? && to_res ->
				{:error, "you can't transfer-custody a container resource into another resource"}
			to_res && to_res.contained? ->
				{:error, "you can't transfer-custody into a contained resource"}
			to_res && to_res.container? ->
				{:error, "you can't transfer-custody into a container resource"}
			to_res && evt.resource_quantity_has_unit_id != to_res.onhand_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"}
			to_res && res.conforms_to_id != to_res.conforms_to_id ->
				{:error, "the resources must conform to the same specification"}
			true ->
				# some fields of the resource is required for the following multis
				{:ok, res}
		end
	end)
	|> Multi.merge(fn changes ->
		res = Map.fetch!(changes, "#{key}.checks")
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all("#{key}.inc", where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
			|> Multi.put(key, evt)
		else
			res_params =
				(res_params || %{})
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, 0)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> Map.put(:classified_as, evt.resource_classified_as || res.classified_as)
				|> Map.put_new(:name, res.name)
				|> Map.put_new(:note, res.note)
				|> Map.put_new(:tracking_identifier, res.tracking_identifier)
				|> Map.put_new(:okhv, res.okhv)
				|> Map.put_new(:repo, res.repo)
				|> Map.put_new(:version, res.version)
				|> Map.put_new(:licensor, res.licensor)
				|> Map.put_new(:license, res.license)
				|> Map.put_new(:metadata, res.metadata)

			Multi.new()
			|> EconomicResource.Domain.multi_insert("#{key}.to_eco_res", res_params)
			|> Multi.update(key, &Changeset.change(evt,
				to_resource_inventoried_as_id: &1 |> Map.fetch!("#{key}.to_eco_res") |> Map.fetch!(:id)))
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{^key => evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), "#{key}.set",
						where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
							contained_in_id: evt.to_resource_inventoried_as_id,
							custodian_id: evt.receiver_id,
						])
				else
					Multi.new()
				end
			end)
		end
	end)
end
defp handle_insert(key, %{action_id: "transferAllRights"} = evt, res_params) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		%{resource_inventoried_as_id: res_id, to_resource_inventoried_as_id: to_res_id} = evt
		res_ids =
			if to_res_id do
				[res_id, to_res_id]
			else
				[res_id]
			end
		fields = ~w[
			id primary_accountable_id conforms_to_id
			accounting_quantity_has_numerical_value accounting_quantity_has_unit_id

			name note tracking_identifier okhv repo version licensor license metadata
			classified_as
		]a
		{res, to_res} =
			from(r in EconomicResource,
				where: r.id in ^res_ids,
				select: merge(map(r, ^fields), %{
					contained?: not is_nil(r.contained_in_id), # is it contained in something?
				}))
			|> repo.all()
			|> case do
				[%{id: ^res_id} = res] -> {res, nil}
				[%{id: ^res_id} = res, %{id: ^to_res_id} = to_res] -> {res, to_res}
				[%{id: ^to_res_id} = to_res, %{id: ^res_id} = res] -> {res, to_res}
			end
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^res_id) |> repo.exists?())
		to_res = to_res
			&& Map.put(to_res, :container?,
				where(EconomicResource, contained_in_id: ^to_res_id) |> repo.exists?())

		cond do
			evt.provider_id != res.primary_accountable_id ->
				{:error, "you don't have accountability over this resource"}
			res.contained? ->
				{:error, "you can't transfer-all-rights a contained resource"}
			evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"}
			res.container? and res.accounting_quantity_has_numerical_value <= 0 ->
				{:error, "the transfer-all-rights events need container resources to have positive accounting-quantity"}
			res.container? && evt.resource_quantity_has_numerical_value != res.accounting_quantity_has_numerical_value ->
				{:error, "the transfer-all-rights events need to fully transfer the resource"}
			res.container? && to_res ->
				{:error, "you can't transfer-all-rights a container resource into another resource"}
			to_res && to_res.contained? ->
				{:error, "you can't transfer-all-rights into a contained resource"}
			to_res && to_res.container? ->
				{:error, "you can't transfer-all-rights into a container resource"}
			to_res && evt.resource_quantity_has_unit_id != to_res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"}
			to_res && res.conforms_to_id != to_res.conforms_to_id ->
				{:error, "the resources must conform to the same specification"}
			true ->
				# some fields of the resource is required for the following multis
				{:ok, res}
		end
	end)
	|> Multi.merge(fn changes ->
		res = Map.fetch!(changes, "#{key}.checks")
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
			|> Multi.put(key, evt)
		else
			res_params =
				(res_params || %{})
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, 0)
				|> Map.put(:classified_as, evt.resource_classified_as || res.classified_as)
				|> Map.put_new(:name, res.name)
				|> Map.put_new(:note, res.note)
				|> Map.put_new(:tracking_identifier, res.tracking_identifier)
				|> Map.put_new(:okhv, res.okhv)
				|> Map.put_new(:repo, res.repo)
				|> Map.put_new(:version, res.version)
				|> Map.put_new(:licensor, res.licensor)
				|> Map.put_new(:license, res.license)
				|> Map.put_new(:metadata, res.metadata)

			Multi.new()
			|> EconomicResource.Domain.multi_insert("#{key}.to_eco_res", res_params)
			|> Multi.update(key, &Changeset.change(evt,
				to_resource_inventoried_as_id: &1 |> Map.fetch!("#{key}.to_eco_res") |> Map.fetch!(:id)))
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{^key => evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), "#{key}.set", where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
						contained_in_id: evt.to_resource_inventoried_as_id,
						primary_accountable_id: evt.receiver_id,
					])
				else
					Multi.new()
				end
			end)
		end
	end)
end
defp handle_insert(key, %{action_id: "transfer"} = evt, res_params) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		%{resource_inventoried_as_id: res_id, to_resource_inventoried_as_id: to_res_id} = evt
		res_ids =
			if to_res_id do
				[res_id, to_res_id]
			else
				[res_id]
			end
		fields = ~w[
			id primary_accountable_id custodian_id conforms_to_id
			accounting_quantity_has_numerical_value accounting_quantity_has_unit_id
			onhand_quantity_has_numerical_value

			name note tracking_identifier okhv repo version licensor license metadata
			classified_as
		]a
		{res, to_res} =
			from(r in EconomicResource,
				where: r.id in ^res_ids,
				select: merge(map(r, ^fields), %{
					contained?: not is_nil(r.contained_in_id), # is it contained in something?
				}))
			|> repo.all()
			|> case do
				[%{id: ^res_id} = res] -> {res, nil}
				[%{id: ^res_id} = res, %{id: ^to_res_id} = to_res] -> {res, to_res}
				[%{id: ^to_res_id} = to_res, %{id: ^res_id} = res] -> {res, to_res}
			end
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^res_id) |> repo.exists?())
		to_res = to_res
			&& Map.put(to_res, :container?,
				where(EconomicResource, contained_in_id: ^to_res_id) |> repo.exists?())

		cond do
			evt.provider_id != res.primary_accountable_id ->
				{:error, "you don't have accountability over this resource"}
			evt.provider_id != res.custodian_id ->
				{:error, "you don't have custody over this resource"}
			res.contained? ->
				{:error, "you can't transfer a contained resource"}
			evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"}
			res.container? and res.accounting_quantity_has_numerical_value <= 0 ->
				{:error, "the transfer events need container resources to have positive accounting-quantity"}
			res.container? and res.onhand_quantity_has_numerical_value <= 0 ->
				{:error, "the transfer events need container resources to have positive onhand-quantity"}
			res.container? && evt.resource_quantity_has_numerical_value != res.accounting_quantity_has_numerical_value ->
				{:error, "the transfer events need to fully transfer the resource"}
			res.container? && evt.resource_quantity_has_numerical_value != res.onhand_quantity_has_numerical_value ->
				{:error, "the transfer events need to fully transfer the resource"}
			res.container? && to_res ->
				{:error, "you can't transfer a container resource into another resource"}
			to_res && to_res.contained? ->
				{:error, "you can't transfer into a contained resource"}
			to_res && to_res.container? ->
				{:error, "you can't transfer into a container resource"}
			to_res && evt.resource_quantity_has_unit_id != to_res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"}
			to_res && res.conforms_to_id != to_res.conforms_to_id ->
				{:error, "the resources must conform to the same specification"}
			true ->
				# some fields of the resource is required for the following multis
				{:ok, res}
		end
	end)
	|> Multi.merge(fn changes ->
		res = Map.fetch!(changes, "#{key}.checks")
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all("#{key}.inc", where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
			|> Multi.put(key, evt)
		else
			res_params =
				(res_params || %{})
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> Map.put(:classified_as, evt.resource_classified_as || res.classified_as)
				|> Map.put_new(:name, res.name)
				|> Map.put_new(:note, res.note)
				|> Map.put_new(:tracking_identifier, res.tracking_identifier)
				|> Map.put_new(:okhv, res.okhv)
				|> Map.put_new(:repo, res.repo)
				|> Map.put_new(:version, res.version)
				|> Map.put_new(:licensor, res.licensor)
				|> Map.put_new(:license, res.license)
				|> Map.put_new(:metadata, res.metadata)

			Multi.new()
			|> EconomicResource.Domain.multi_insert("#{key}.to_eco_res", res_params)
			|> Multi.update(key, &Changeset.change(evt,
				to_resource_inventoried_as_id: &1 |> Map.fetch!("#{key}.to_eco_res") |> Map.fetch!(:id)))
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{^key => evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), "#{key}.set", where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
						contained_in_id: evt.to_resource_inventoried_as_id,
						primary_accountable_id: evt.receiver_id,
						custodian_id: evt.receiver_id,
					])
				else
					Multi.new()
				end
			end)
		end
	end)
end
defp handle_insert(key, %{action_id: "move"} = evt, res_params) do
	Multi.new()
	|> Multi.run("#{key}.checks", fn repo, _ ->
		%{resource_inventoried_as_id: res_id, to_resource_inventoried_as_id: to_res_id} = evt
		res_ids =
			if to_res_id do
				[res_id, to_res_id]
			else
				[res_id]
			end
		fields = ~w[
			id primary_accountable_id custodian_id conforms_to_id
			accounting_quantity_has_numerical_value accounting_quantity_has_unit_id
			onhand_quantity_has_numerical_value

			name note tracking_identifier okhv repo version licensor license metadata
			classified_as
		]a
		{res, to_res} =
			from(r in EconomicResource,
				where: r.id in ^res_ids,
				select: merge(map(r, ^fields), %{
					contained?: not is_nil(r.contained_in_id), # is it contained in something?
				}))
			|> repo.all()
			|> case do
				[%{id: ^res_id} = res] -> {res, nil}
				[%{id: ^res_id} = res, %{id: ^to_res_id} = to_res] -> {res, to_res}
				[%{id: ^to_res_id} = to_res, %{id: ^res_id} = res] -> {res, to_res}
			end
		res = Map.put(res, :container?,
			where(EconomicResource, contained_in_id: ^res_id) |> repo.exists?())
		to_res = to_res
			&& Map.put(to_res, :container?,
				where(EconomicResource, contained_in_id: ^to_res_id) |> repo.exists?())

		cond do
			evt.provider_id != res.primary_accountable_id ->
				{:error, "you don't have accountability over resource-inventoried-as"}
			evt.provider_id != res.custodian_id ->
				{:error, "you don't have custody over resource-inventoried-as"}
			res.contained? ->
				{:error, "you can't move a contained resource"}
			evt.resource_quantity_has_unit_id != res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"}
			res.container? and res.accounting_quantity_has_numerical_value <= 0 ->
				{:error, "the move events need container resources to have positive accounting-quantity"}
			res.container? and res.onhand_quantity_has_numerical_value <= 0 ->
				{:error, "the move events need container resources to have positive onhand-quantity"}
			res.container? && evt.resource_quantity_has_numerical_value != res.accounting_quantity_has_numerical_value ->
				{:error, "the move events need to fully move the resource"}
			res.container? && evt.resource_quantity_has_numerical_value != res.onhand_quantity_has_numerical_value ->
				{:error, "the move events need to fully move the resource"}
			res.container? && to_res ->
				{:error, "you can't move a container resource into another resource"}
			to_res && evt.provider_id != to_res.primary_accountable_id ->
				{:error, "you don't have accountability over to-resource-inventoried-as"}
			to_res && evt.provider_id != to_res.custodian_id ->
				{:error, "you don't have custody over to-resource-inventoried-as"}
			to_res && to_res.contained? ->
				{:error, "you can't move into a contained resource"}
			to_res && to_res.container? ->
				{:error, "you can't move into a container resource"}
			to_res && evt.resource_quantity_has_unit_id != to_res.accounting_quantity_has_unit_id ->
				{:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"}
			to_res && res.conforms_to_id != to_res.conforms_to_id ->
				{:error, "the resources must conform to the same specification"}
			true ->
				# some fields of the resource is required for the following multis
				{:ok, res}
		end
	end)
	|> Multi.merge(fn changes ->
		res = Map.fetch!(changes, "#{key}.checks")
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all("#{key}.dec", where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all("#{key}.inc", where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
			|> Multi.put(key, evt)
		else
			res_params =
				(res_params || %{})
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> Map.put(:classified_as, evt.resource_classified_as || res.classified_as)
				|> Map.put_new(:name, res.name)
				|> Map.put_new(:note, res.note)
				|> Map.put_new(:tracking_identifier, res.tracking_identifier)
				|> Map.put_new(:okhv, res.okhv)
				|> Map.put_new(:repo, res.repo)
				|> Map.put_new(:version, res.version)
				|> Map.put_new(:licensor, res.licensor)
				|> Map.put_new(:license, res.license)
				|> Map.put_new(:metadata, res.metadata)

			Multi.new()
			|> EconomicResource.Domain.multi_insert("#{key}.to_eco_res", res_params)
			|> Multi.update(key, &Changeset.change(evt,
				to_resource_inventoried_as_id: &1 |> Map.fetch!("#{key}.to_eco_res") |> Map.fetch!(:id)))
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{^key => evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), "#{key}.set", where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
						contained_in_id: evt.to_resource_inventoried_as_id,
						primary_accountable_id: evt.receiver_id,
						custodian_id: evt.receiver_id,
					])
				else
					Multi.new()
				end
			end)
		end
	end)
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&EconomicEvent.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
