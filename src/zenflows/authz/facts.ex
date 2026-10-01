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

defmodule Zenflows.Authz.Facts do
@moduledoc """
Everything a policy decision may look at.  Domain functions load it
(with row locks) inside their transaction, then hand it to the policy.
"""

alias Zenflows.Authz.ResourceControl

@type t() :: %__MODULE__{
	target: nil | struct() | map(),
	control: nil | ResourceControl.t(),
	admin_of: MapSet.t(String.t()),
	role_key: nil | String.t(),
	new_subject_id: nil | String.t(),
	active_admin_count: nil | non_neg_integer(),
}

defstruct target: nil,
	control: nil,
	admin_of: MapSet.new(),
	role_key: nil,
	new_subject_id: nil,
	active_admin_count: nil
end
