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

defmodule Zenflows.File.Type do
@moduledoc "GraphQL types of Files."

use Absinthe.Schema.Notation

object :file do
	field :hash, non_null(:url64)
	field :size, non_null(:integer)
	field :bin, :base64
	field :name, non_null(:string)
	field :description, non_null(:string)
	field :inserted_at, non_null(:datetime), name: "date"
	field :mime_type, non_null(:string)
	field :extension, non_null(:string)
	field :signature, :string
end

input_object :ifile, name: "IFile" do
	field :hash, non_null(:url64)
	field :size, non_null(:integer)
	field :name, non_null(:string)
	field :description, non_null(:string)
	field :mime_type, non_null(:string)
	field :extension, non_null(:string)
end
end
