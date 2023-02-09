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

defmodule Zenflows.VF.ProductBatch.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.ProductBatch.Domain

def product_batch(params, _) do
	Domain.one(params)
end

def product_batches(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_product_batch(%{product_batch: params}, _) do
	with {:ok, batch} <- Domain.create(params) do
		{:ok, %{product_batch: batch}}
	end
end

def update_product_batch(%{product_batch: %{id: id} = params}, _) do
	with {:ok, batch} <- Domain.update(id, params) do
		{:ok, %{product_batch: batch}}
	end
end

def delete_product_batch(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
