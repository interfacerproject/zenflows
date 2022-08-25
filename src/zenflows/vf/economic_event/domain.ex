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
alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.{
	Action,
	EconomicEvent,
	EconomicResource,
	Measure,
}

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, EconomicEvent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(EconomicEvent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result()
def all(params) do
	Paging.page(EconomicEvent, params)
end

@spec create(params(), params()) :: {:ok, EconomicEvent.t(), EconomicResource.t(), nil}
	| {:ok, EconomicEvent.t(), nil, EconomicResource.t()}
	| {:ok, EconomicEvent.t()} | {:error, String.t() | chgset()}
def create(evt_params, res_params) do
	Multi.new()
	|> Multi.insert(:created_evt, EconomicEvent.chgset(evt_params))
	|> Multi.merge(fn %{created_evt: evt} ->
		handle_multi(evt.action_id, evt, res_params)
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{updated_evt: evt} = map} ->
			if map[:eco_res] || map[:to_eco_res] do
				{:ok, evt, map[:eco_res], map[:to_eco_res]}
			else
				{:ok, evt}
			end

		{:ok, %{created_evt: evt}} ->
			{:ok, evt}

		{:error, _, msg_or_cset, _} ->
			{:error, msg_or_cset}
	end
end

# Handle the part after the event is created.  These clauses deal with
# validations, creation of resources, and any other side-effects.
#
# If they return a multi named `:updated_evt`, the value (assuming
# it is a event struct) of it will be passed back as `{:ok, value}`.
#
# They can optionally return a multi named `:eco_res` (assuming
# it is a resource struct) that can be used for a tiny optimization
# on the resolver (when create a resource, fetch it, etc.).
@spec handle_multi(Action.ID.t(), EconomicEvent.t(), params() | nil) :: Multi.t()
defp handle_multi(action_id, evt, res_params) when action_id in ["raise", "produce"] do
	cond do
		evt.resource_conforms_to_id != nil ->
			cset =
				res_params
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, evt.resource_conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> EconomicResource.chgset()

			Multi.new()
			|> Multi.insert(:eco_res, cset)
			|> Multi.update(:updated_evt, fn %{eco_res: res} ->
				Changeset.change(evt, resource_inventoried_as_id: res.id)
			end)

		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run(:checks, fn repo, _ ->
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
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
	end
end

defp handle_multi(action_id, evt, _) when action_id in ["lower", "consume"] do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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
	|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
		onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
	])
end

defp handle_multi(action_id, _evt, _) when action_id in ~w[work deliverService] do
	Multi.new()
end

defp handle_multi("use", evt, _) do
	cond do
		evt.resource_conforms_to_id != nil ->
			Multi.new()

		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run(:checks, fn repo, _ ->
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
	end
end

defp handle_multi("cite", evt, _) do
	cond do
		evt.resource_conforms_to_id != nil ->
			Multi.new()

		evt.resource_inventoried_as_id != nil ->
			Multi.new()
			|> Multi.run(:checks, fn repo, _ ->
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
	end
end

defp handle_multi("pickup", evt, _) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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

		single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "pickup"
					and e.input_of_id == ^evt.input_of_id)
			|> repo.exists?()
			|> Kernel.not()
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

			not single_ref?.() ->
				{:error, "no more than one pickup event in the same process, referring to the same resource is allowed"}

			true ->
				{:ok, nil}
		end
	end)
end

defp handle_multi("dropoff", evt, _) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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

		single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "dropoff"
					and e.output_of_id == ^evt.output_of_id)
			|> repo.exists?()
			|> Kernel.not()
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

			not single_ref?.() ->
				{:error, "no more than one dropoff event in the same process, referring to the same resource is allowed"}

			true ->
				{:ok, nil}
		end
	end)
	|> Multi.run(:set, fn repo, _ ->
		if evt.to_location_id do
			q = where(EconomicResource, [r],
				r.id == ^evt.resource_inventoried_as_id
					or r.contained_in_id == ^evt.resource_inventoried_as_id)
			{:ok, repo.update_all(q, set: [current_location_id: evt.to_location_id])}
		else
			{:ok, nil}
		end
	end)
end

defp handle_multi("accept", evt, _) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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

		single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "accept"
					and e.input_of_id == ^evt.input_of_id)
			|> repo.exists?()
			|> Kernel.not()
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

			not single_ref?.() ->
				{:error, "no more than one accept event in the same process, referring to the same resource is allowed"}

			true ->
				{:ok, nil}
		end
	end)
	|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
	])
end

defp handle_multi("modify", evt, _) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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

		single_ref? = fn ->
			where(EconomicEvent, [e],
				e.resource_inventoried_as_id == ^evt.resource_inventoried_as_id
					and e.id != ^evt.id
					and e.action_id == "modify"
					and e.output_of_id == ^evt.output_of_id)
			|> repo.exists?()
			|> Kernel.not()
		end

		cond do
			evt.provider_id != pair_evt.provider_id ->
				{:error, "you don't have custody over this resource"}

			evt.resource_quantity_has_unit_id != pair_evt.resource_quantity_has_unit_id ->
				{:error, "the unit of resource quantity must match with the unit of the paired event"}

			evt.resource_quantity_has_numerical_value != pair_evt.resource_quantity_has_numerical_value ->
				{:error, "the modify events need to fully modify the resource"}

			not single_ref?.() ->
				{:error, "no more than one modify event in the same process, referring to the same resource is allowed"}

			true ->
				{:ok, nil}
		end
	end)
	|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
		onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
	])
	|> Multi.update_all(:stage, fn _ ->
		from(r in EconomicResource,
			join: e in EconomicEvent, on: e.id == ^evt.id,
			join: p in assoc(e, :output_of),
			where: r.id == e.resource_inventoried_as_id,
			update: [set: [stage_id: p.based_on_id]])
	end, [])
end

defp handle_multi("transferCustody", evt, res_params) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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
	|> Multi.merge(fn %{checks: res} ->
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
		else
			cset =
				(res_params || %{}) # since it can be empty
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, 0)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> EconomicResource.chgset()

			Multi.new()
			|> Multi.insert(:to_eco_res, cset)
			|> Multi.update(:updated_evt, fn %{to_eco_res: res} ->
				Changeset.change(evt, to_resource_inventoried_as_id: res.id)
			end)
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{updated_evt: evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), :set, where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
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

defp handle_multi("transferAllRights", evt, res_params) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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
	|> Multi.merge(fn %{checks: res} ->
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
		else
			cset =
				(res_params || %{}) # since it can be empty
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, 0)
				|> EconomicResource.chgset()

			Multi.new()
			|> Multi.insert(:to_eco_res, cset)
			|> Multi.update(:updated_evt, fn %{to_eco_res: res} ->
				Changeset.change(evt, to_resource_inventoried_as_id: res.id)
			end)
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{updated_evt: evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), :set, where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
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

defp handle_multi("transfer", evt, res_params) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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
	|> Multi.merge(fn %{checks: res} ->
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
		else
			cset =
				(res_params || %{}) # since it can be empty
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> EconomicResource.chgset()

			Multi.new()
			|> Multi.insert(:to_eco_res, cset)
			|> Multi.update(:updated_evt, fn %{to_eco_res: res} ->
				Changeset.change(evt, to_resource_inventoried_as_id: res.id)
			end)
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{updated_evt: evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), :set, where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
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

defp handle_multi("move", evt, res_params) do
	Multi.new()
	|> Multi.run(:checks, fn repo, _ ->
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
	|> Multi.merge(fn %{checks: res} ->
		if evt.to_resource_inventoried_as_id do
			Multi.new()
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.update_all(:inc, where(EconomicResource, id: ^evt.to_resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: evt.resource_quantity_has_numerical_value,
			])
		else
			cset =
				(res_params || %{}) # since it can be empty
				|> Map.put(:primary_accountable_id, evt.receiver_id)
				|> Map.put(:custodian_id, evt.receiver_id)
				|> Map.put(:conforms_to_id, res.conforms_to_id)
				|> Map.put(:accounting_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:accounting_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:onhand_quantity_has_unit_id, evt.resource_quantity_has_unit_id)
				|> Map.put(:onhand_quantity_has_numerical_value, evt.resource_quantity_has_numerical_value)
				|> Map.put(:current_location_id, evt.to_location_id)
				|> EconomicResource.chgset()

			Multi.new()
			|> Multi.insert(:to_eco_res, cset)
			|> Multi.update(:updated_evt, fn %{to_eco_res: res} ->
				Changeset.change(evt, to_resource_inventoried_as_id: res.id)
			end)
			|> Multi.update_all(:dec, where(EconomicResource, id: ^evt.resource_inventoried_as_id), inc: [
				accounting_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
				onhand_quantity_has_numerical_value: -evt.resource_quantity_has_numerical_value,
			])
			|> Multi.merge(fn %{updated_evt: evt} ->
				if res.container? do
					Multi.update_all(Multi.new(), :set, where(EconomicResource, contained_in_id: ^evt.resource_inventoried_as_id), set: [
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

@spec update(id(), params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &EconomicEvent.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: ee}} -> {:ok, ee}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(EconomicEvent.t(), :action | :input_of | :output_of
		| :provider | :receiver
		| :resource_inventoried_as | :to_resource_inventoried_as
		| :resource_conforms_to | :resource_quantity | :effort_quantity
		| :to_location | :at_location | :realization_of | :triggered_by)
	:: EconomicEvent.t()
def preload(eco_evt, :action) do
	Action.preload(eco_evt, :action)
end

def preload(eco_evt, :input_of) do
	Repo.preload(eco_evt, :input_of)
end

def preload(eco_evt, :output_of) do
	Repo.preload(eco_evt, :output_of)
end

def preload(eco_evt, :provider) do
	Repo.preload(eco_evt, :provider)
end

def preload(eco_evt, :receiver) do
	Repo.preload(eco_evt, :receiver)
end

def preload(eco_evt, :resource_inventoried_as) do
	Repo.preload(eco_evt, :resource_inventoried_as)
end

def preload(eco_evt, :to_resource_inventoried_as) do
	Repo.preload(eco_evt, :to_resource_inventoried_as)
end

def preload(eco_evt, :resource_conforms_to) do
	Repo.preload(eco_evt, :resource_conforms_to)
end

def preload(eco_evt, :resource_quantity) do
	Measure.preload(eco_evt, :resource_quantity)
end

def preload(eco_evt, :effort_quantity) do
	Measure.preload(eco_evt, :effort_quantity)
end

def preload(eco_evt, :to_location) do
	Repo.preload(eco_evt, :to_location)
end

def preload(eco_evt, :at_location) do
	Repo.preload(eco_evt, :at_location)
end

def preload(eco_evt, :realization_of) do
	Repo.preload(eco_evt, :realization_of)
end

def preload(eco_evt, :triggered_by) do
	Repo.preload(eco_evt, :triggered_by)
end
end
