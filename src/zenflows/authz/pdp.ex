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

defmodule Zenflows.Authz.Pdp do
@moduledoc """
Cross-service authorization decision point.

The other Interfacer services (DPP, wallet, …) hold no controllers,
memberships or epochs; those facts live here.  A service's thin
enforcement point (PEP) sends a decision request in the fixed shape of
the cross-service authorization contract
(`docs/cross-service-authz-contract.md` §4), and this module answers
allow/deny with a reason, the permission epoch, and any obligations.

The decision is split in two, so the policy is testable without a
database, exactly as the Go PEP's authentication floor is:

  * `decide/2` is **pure** — it maps a request and the facts a loader
    produced to a response.  The shared contract vectors
    (`docs/cross-service-authz/contract.json`, layer `contract`) drive
    it directly.
  * `load_facts/1` reads those facts from the database, reusing
    `Zenflows.Authz.ResourceControl`.

It fails closed: a fact-loader error, an unproven subject, or an action
with no registered rule all deny.  This is authorization only; the
caller's signature is checked by the service's PEP (authentication
floor, contract §2) before the request reaches here.

Transport (how a request arrives, and how the acting user's proof is
carried and verified so a service cannot assert an arbitrary subject —
contract §4.3 property 2) is a deliberate follow-up: `load_facts/1`
takes `principal_proven` from an already-verified field and defaults it
to false, so nothing is granted on a service's unbacked say-so.
"""

require Logger

alias Zenflows.Authz.ResourceControl
alias Zenflows.DB.Repo
alias Zenflows.VF.Person

@policy_version "cross-service-authz/1"

# Registry of cross-service actions.  The value is the capability the
# PDP checks; an action absent from this map is refused (default deny).
# `:resource_control` means "the principal must control the bound parent
# resource".  The action is fixed by the service's handler, never chosen
# by the client (contract §3).
@actions %{
	"dpp.create" => :resource_control,
	"dpp.spec.update" => :resource_control,
	"dpp.status.update" => :resource_control,
	"dpp.delete" => :resource_control,
	"dpp.attachment.add" => :resource_control,
	"dpp.attachment.delete" => :resource_control,
	"dpp.file.upload" => :resource_control,
	"wallet.points.issue" => :resource_control
}

@doc "The policy version recorded with every decision."
@spec policy_version() :: String.t()
def policy_version(), do: @policy_version

@doc "The cross-service actions this PDP has a rule for."
@spec actions() :: [String.t()]
def actions(), do: Map.keys(@actions)

@doc """
Full decision for a decoded request map: load facts, decide, and tag the
response with the request id and policy version.  Any crash in loading
or deciding becomes a fail-closed deny.
"""
@spec decision(map()) :: map()
def decision(request) when is_map(request) do
	facts = load_facts(request)
	request
	|> decide(facts)
	|> tag(request)
rescue
	e ->
		Logger.error("pdp decision crashed: #{inspect(e)}")
		deny("pdp_unavailable", nil, %{}) |> tag(request)
end

defp tag(response, request) do
	response
	|> Map.put("request_id", request["request_id"])
	|> Map.put("policy_version", @policy_version)
end

@doc """
Pure decision.  `request` is the contract request (string-keyed, as
decoded from JSON); `facts` is what `load_facts/1` produced.  Returns the
contract response: `decision`, `reason_code`, `permission_epoch`,
`obligations`.
"""
@spec decide(map(), map()) :: map()
# A fact-loader error fails closed, with no epoch to report.
def decide(_request, %{"error" => err}) when not is_nil(err),
	do: deny("pdp_unavailable", nil, %{})

def decide(request, facts) do
	epoch = facts["epoch"]
	action = request["action"]

	cond do
		# A service's assertion of who the user is, without the user's own
		# proof, is not trusted (contract §4.3 property 2).
		facts["principal_proven"] != true ->
			deny("unproven_subject", epoch, %{})

		# An action with no rule is refused, never allowed by default.
		not Map.has_key?(@actions, action) ->
			deny("unknown_action", epoch, %{})

		true ->
			case Map.fetch!(@actions, action) do
				:resource_control ->
					if facts["controls_parent"] == true,
						do: allow(epoch, facts["obligations"] || %{}),
						else: deny("not_controller", epoch, %{})
			end
	end
end

defp allow(epoch, obligations) do
	%{
		"decision" => "allow",
		"reason_code" => "ok",
		"permission_epoch" => epoch,
		"obligations" => obligations
	}
end

defp deny(reason, epoch, obligations) do
	%{
		"decision" => "deny",
		"reason_code" => reason,
		"permission_epoch" => epoch,
		"obligations" => obligations
	}
end

@doc """
Read the facts a decision needs from the database.  Reuses
`ResourceControl`: the principal controls the bound parent when they are
its recorded controller, and the control row carries the epoch.

Returns a `facts` map for `decide/2`, or `%{"error" => reason}` so the
decision fails closed when a fact cannot be established.

`principal_proven` is taken from a field the verified transport sets and
defaults to false (see the moduledoc): this slice establishes the
control facts; verifying the acting user's proof is the transport
follow-up.
"""
@spec load_facts(map()) :: map()
def load_facts(request) do
	proven? = request["principal_proven"] == true
	pk = get_in(request, ["principal", "pk"])
	parent_id = get_in(request, ["binding", "parent_id"])

	with %Person{id: person_id} <- resolve_principal(pk),
			{:ok, control} <- ResourceControl.Domain.one(Repo, parent_id) do
		%{
			"principal_proven" => proven?,
			"controls_parent" => control.controller_id == person_id,
			"epoch" => control.epoch,
			"obligations" => %{}
		}
	else
		nil ->
			# Unknown principal: authenticated to no registered agent.
			%{"principal_proven" => proven?, "controls_parent" => false,
				"epoch" => nil, "obligations" => %{}}

		{:error, _} ->
			# No control row for the bound parent: nobody controls it here, so
			# a resource-control action cannot be allowed.
			%{"principal_proven" => proven?, "controls_parent" => false,
				"epoch" => nil, "obligations" => %{}}
	end
rescue
	e ->
		Logger.error("pdp load_facts crashed: #{inspect(e)}")
		%{"error" => "fact_load_failed"}
end

defp resolve_principal(nil), do: nil
defp resolve_principal(pk) do
	case Person.Domain.one(eddsa_public_key: pk) do
		{:ok, %Person{} = per} -> per
		_ -> nil
	end
end
end
