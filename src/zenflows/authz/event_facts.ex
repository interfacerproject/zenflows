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

defmodule Zenflows.Authz.EventFacts do
@moduledoc """
Everything an event decision may look at.  `EconomicEvent.Domain`
loads it with row locks before the event is written.
"""

alias Zenflows.Authz.ResourceControl

@type t() :: %__MODULE__{
	action: nil | String.t(),
	provider_id: nil | String.t(),
	receiver_id: nil | String.t(),
	source_id: nil | String.t(),
	event: nil | struct(),
	touched: Zenflows.Authz.EventPolicy.touched(),
	resources: %{String.t() => struct()},
	controls: %{String.t() => ResourceControl.t()},
	contained: %{String.t() => [String.t()]},
	admin_of: MapSet.t(String.t()),
	claimable: MapSet.t(String.t()),
}

defstruct action: nil,
	provider_id: nil,
	receiver_id: nil,
	source_id: nil,
	event: nil,
	touched: %{changes: [], references: [], creates: :none},
	resources: %{},
	controls: %{},
	contained: %{},
	admin_of: MapSet.new(),
	claimable: MapSet.new()
end
