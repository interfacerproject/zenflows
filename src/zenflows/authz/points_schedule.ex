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

defmodule Zenflows.Authz.PointsSchedule do
@moduledoc """
The authoritative point schedule — server side, not the client.  Phase 1
covers only the `accept` event: the owner is credited `idea` and the
contributor `strengths` (correcting the GUI's buggy OnAccept mapping; see
`docs/cross-service-authz-wallet-design.md` appendix).  Amounts are integers
×100 as the wallet stores them.  The remaining six events arrive with the
owner-ratified full schedule in a follow-on slice.
"""

# event type => %{amount, roles: [{fact_role, token}]}.  `fact_role` is the
# key the fact loader fills with the recipient id (e.g. "owner", "contributor").
@schedule %{
	"accept" => %{amount: 10_000, roles: [{"owner", "idea"}, {"contributor", "strengths"}]}
}

@doc "The schedule entry for an event type, or nil if the type earns no points."
@spec for_event(String.t()) :: %{amount: non_neg_integer(), roles: [{String.t(), String.t()}]} | nil
def for_event(type), do: Map.get(@schedule, type)
end
