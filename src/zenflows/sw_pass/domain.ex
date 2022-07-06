defmodule Zenflows.SWPass.Domain do
@moduledoc """
Domain logic of interacting with softwarepassport instances over
HTTP.
"""

alias Zenflows.DB.Repo
alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
	Person,
	Process,
	ResourceSpecification,
	Unit,
}
alias Ecto.Multi

# TODO: not the best piece of code, but will do okay for now.
@doc """
Import repos by a URL to `/repositories` route of a softwarepassport
instance, and generate necessary things to link Person Agents to
EconomicResource Procjets.
"""
@spec import_repos(String.t()) :: {:ok, term()} | {:error, term()}
def import_repos(url) do
	url = to_charlist(url)
	hdrs = [
		{'user-agent', useragent()},
		{'accept', 'application/json'},
	]
	http_opts = [
		{:timeout, 30000}, # 30 seconds
		{:connect_timeout, 5000}, # 5 seconds
		{:autoredirect, false},
	]
	with {:ok, {{_, 200, _}, _, body_charlist}} <-
				:httpc.request(:get, {url, hdrs}, http_opts, []),
			{:ok, map} <- body_charlist |> to_string() |> Jason.decode() do
		proj = get_emails(map)

		result = Enum.map(proj, fn {url, emails} ->
			now = DateTime.utc_now()
			mult =
				Multi.new()
				|> Multi.run(:commit_spec, fn repo, _ ->
					params = %{name: "committing"}

					case repo.get_by(ResourceSpecification, params) do
						nil ->
							params
							|> ResourceSpecification.chgset()
							|> repo.insert()
						res_spec -> {:ok, res_spec}
					end
				end)
				|> Multi.run(:proj_spec, fn repo, _ ->
					params = %{name: "project"}

					case repo.get_by(ResourceSpecification, params) do
						nil ->
							params
							|> ResourceSpecification.chgset()
							|> repo.insert()
						res_spec -> {:ok, res_spec}
					end
				end)
				|> Multi.run(:unit, fn repo, _ ->
					params = %{label: "one", symbol: "one"}

					case repo.get_by(Unit, params) do
						nil ->
							params
							|> Unit.chgset()
							|> repo.insert()
						unit -> {:ok, unit}
					end
				end)
				|> Multi.run(:proc, fn repo, _ ->
					params = %{name: url}

					case repo.get_by(Process, params) do
						nil ->
							params
							|> Process.chgset()
							|> repo.insert()
						proc -> {:ok, proc}
					end
				end)
			Enum.reduce(emails, mult, fn e, mult ->
				mult
				|> Multi.run("per:#{e}", fn repo, _ ->
					params = %{email: e, user: e, name: e}

					case repo.get_by(Person, params) do
						nil ->
							params
							|> Person.chgset()
							|> repo.insert()
						per -> {:ok, per}
					end
				end)
				|> Multi.run("evt:#{e}", fn repo, %{proc: proc, commit_spec: commit_spec} = chgs ->
					per = Map.fetch!(chgs ,"per:#{e}")
					params = %{
						action_id: "deliverService",
						input_of_id: proc.id,
						provider_id: per.id,
						receiver_id: per.id,
						resource_conforms_to_id: commit_spec.id,
						note: url,
					}

					case repo.get_by(EconomicEvent, params) do
						nil ->
							params
							|> Map.put(:has_point_in_time, now)
							|> EconomicEvent.chgset()
							|> repo.insert()
						evt -> {:ok, evt}
					end
				end)
			end)
			|> Multi.merge(fn changes ->
				first_email = emails |> MapSet.to_list() |> List.first()
				first_person = Map.fetch!(changes, "per:#{first_email}")
				Multi.put(Multi.new(), :org, first_person) # TODO: make this really an organization
			end)
			|> Multi.run(:produce, fn repo, %{org: org, proc: proc, proj_spec: proj_spec, unit: unit} ->
				params = %{
					action_id: "produce",
					output_of_id: proc.id,
					provider_id: org.id,
					receiver_id: org.id,
					resource_conforms_to_id: proj_spec.id,
					note: url,
				}

				case repo.get_by(EconomicEvent,
							params
							|> Map.put(:resource_quantity_has_unit_id, unit.id)
							|> Map.put(:resource_quantity_has_numerical_value, 1)
						) do
					nil ->
						params
						|> Map.put(:resource_quantity, %{
							has_unit_id: unit.id,
							has_numerical_value: 1,
						})
						|> Map.put(:has_point_in_time, now)
						|> EconomicEvent.chgset()
						|> repo.insert()
					evt -> {:ok, evt}
				end
			end)
			|> Multi.run(:resource, fn repo, %{unit: unit, org: org, proj_spec: proj_spec} ->
				params = %{
					name: url,
					primary_accountable_id: org.id,
					custodian_id: org.id,
					conforms_to_id: proj_spec.id,
					accounting_quantity_has_unit_id: unit.id,
					accounting_quantity_has_numerical_value: 1,
					onhand_quantity_has_unit_id: unit.id,
					onhand_quantity_has_numerical_value: 1,
				}

				case repo.get_by(EconomicResource, params) do
					nil ->
						params
						|> EconomicResource.chgset()
						|> repo.insert()
					res -> {:ok, res}
				end
			end)
			|> Multi.run(:update_produce_evt, fn repo, %{produce: evt, resource: res} ->
				Ecto.Changeset.change(evt, resource_inventoried_as_id: res.id) |> repo.update()
			end)
			|> Repo.transaction()
			|> case do
				{:ok, res} -> {:ok, res}
				{:error, op, val, chng} -> {:error, op, val, chng}
			end
		end)

		if Enum.all?(result, &match?({:ok, _}, &1)) do
			{:ok, result}
		else
			{:error, result}
		end
	else
		{:ok, {{_, stat, _}, _, body_charlist}} ->
			{:error, "the http call result in non-200 status code #{stat}: #{to_string(body_charlist)}"}

		other -> other
	end
end

@spec project_agents(String.t()) :: [Agent.t()]
def project_agents(url) do
	import Ecto.Query

	from(p in Process,
		join: e in assoc(p, :inputs),
		join: a in assoc(e, :provider),
		where: p.name == ^url,
		select: a)
	|> Repo.all()
end

# Get emails from the softwarepassport repositories output.
@spec get_emails(map()) :: %{String.t() => MapSet.t()}
defp get_emails(map) do
	Enum.reduce(map, %{}, fn p, acc ->
		# the scanning might be in proccess, so it might be `nil`
		if p["scancode_report"] do
			emails =
				Enum.reduce(p["scancode_report"]["files"], MapSet.new(), fn f, acc ->
					Enum.reduce(f["emails"], acc, fn e, acc ->
						MapSet.put(acc, String.downcase(e["email"]))
					end)
				end)
			if emails == MapSet.new() do # empty?
				acc
			else
				Map.put(acc, p["url"], emails)
			end
		else
			acc
		end
	end)
end

# Return the useragent to be used by the HTTP client, this module.
@spec useragent() :: charlist()
defp useragent() do
	'zenflows/' ++ Application.spec(:zenflows, :vsn)
end
end
