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

defmodule Zenflows.File.Type do
@moduledoc "GraphQL types of Files."

use Absinthe.Schema.Notation

alias Zenflows.File.Resolv

object :file do
	field :hash, non_null(:url64)
	field :name, non_null(:string)
	field :description, non_null(:string)
	field :date, non_null(:datetime), resolve: &Resolv.date/3
	field :mime_type, non_null(:string)
	field :extension, non_null(:string)
	field :size, non_null(:integer)
	field :signature, non_null(:string)
	field :width, :integer
	field :height, :integer
	field :bin, :base64
end

input_object :ifile, name: "IFile" do
	field :hash, non_null(:url64)
	field :name, non_null(:string)
	field :description, non_null(:string)
	field :mime_type, non_null(:string)
	field :extension, non_null(:string)
	field :size, non_null(:integer)
	field :signature, non_null(:string)
	field :width, :integer
	field :height, :integer
end
end
