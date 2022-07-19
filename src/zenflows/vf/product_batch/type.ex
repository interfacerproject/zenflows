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

defmodule Zenflows.VF.ProductBatch.Type do
@moduledoc "GraphQL types of ProductBatches."

use Absinthe.Schema.Notation

alias Zenflows.VF.ProductBatch.Resolv

@batch_number """
An informal or formal textual identifier for a recipe exchange.  Does not
imply uniqueness.
"""
@expiry_date "A textual description or comment."
@production_date ""

@desc """
A lot or batch, defining a resource produced at the same
time in the same way.  From DataFoodConsortium vocabulary
https://datafoodconsortium.gitbook.io/dfc-standard-documentation/.
"""
object :product_batch do
	field :id, non_null(:id)

	@desc @batch_number
	field :batch_number, non_null(:string)

	@desc @expiry_date
	field :expiry_date, :datetime

	@desc @production_date
	field :production_date, :datetime
end

object :product_batch_response do
	field :product_batch, non_null(:product_batch)
end

input_object :product_batch_create_params do
	@desc @batch_number
	field :batch_number, non_null(:string)

	@desc @expiry_date
	field :expiry_date, :datetime

	@desc @production_date
	field :production_date, :datetime
end

input_object :product_batch_update_params do
	field :id, non_null(:id)

	@desc @batch_number
	field :batch_number, :string

	@desc @expiry_date
	field :expiry_date, :datetime

	@desc @production_date
	field :production_date, :datetime
end

object :query_product_batch do
	field :product_batch, :product_batch do
		arg :id, non_null(:id)
		resolve &Resolv.product_batch/2
	end
end

object :mutation_product_batch do
	field :create_product_batch, non_null(:product_batch_response) do
		arg :product_batch, non_null(:product_batch_create_params)
		resolve &Resolv.create_product_batch/2
	end

	field :update_product_batch, non_null(:product_batch_response) do
		arg :product_batch, non_null(:product_batch_update_params)
		resolve &Resolv.update_product_batch/2
	end

	field :delete_product_batch, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_product_batch/2
	end
end
end
