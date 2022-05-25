defmodule Zenflows.VF.Process.Type do
@moduledoc "GraphQL types of Processs."

use Absinthe.Schema.Notation

alias Zenflows.VF.Process.Resolv

@name """
An informal or formal textual identifier for a process.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@has_beginning "The planned beginning of the process."
@has_end "The planned end of the process."
@finished """
The process is complete or not.  This is irrespective of if the original
goal has been met, and indicates that no more will be done.
"""
@deletable """
The process can be safely deleted, has no dependent information.
"""
@classified_as """
References one or more concepts in a common taxonomy or other
classification scheme for purposes of categorization or grouping.
"""
@based_on "The definition or specification for a process."
@planned_within """
The process with its inputs and outputs is part of the plan.
"""
@nested_in """
The process with its inputs and outputs is part of the scenario.
"""

@desc """
A logical collection of processes that constitute a body of processned work
with defined deliverable(s).
"""
object :process do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, non_null(:boolean)

	@desc @deletable
	field :deletable, non_null(:boolean)

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	@desc @based_on
	field :based_on, :process_specification,
		resolve: &Resolv.based_on/3

	@desc @planned_within
	field :planned_within, :plan,
		resolve: &Resolv.planned_within/3

	@desc @nested_in
	field :nested_in, :scenario, resolve: &Resolv.nested_in/3
end

object :process_response do
	field :process, non_null(:process)
end

input_object :process_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`ProcessSpecification`) " <> @based_on
	field :based_on_id, :id, name: "based_on"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Plan`) " <> @planned_within
	field :planned_within_id, :id, name: "planned_within"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @nested_in
	field :nested_in_id, :id, name: "nested_in"
end

input_object :process_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`ProcessSpecification`) " <> @based_on
	field :based_on_id, :id, name: "based_on"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Plan`) " <> @planned_within
	field :planned_within_id, :id, name: "planned_within"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @nested_in
	field :nested_in_id, :id, name: "nested_in"
end

object :query_process do
	field :process, :process do
		arg :id, non_null(:id)
		resolve &Resolv.process/2
	end

	#processes(start: ID, limit: Int): [Process!]
end

object :mutation_process do
	field :create_process, non_null(:process_response) do
		arg :process, non_null(:process_create_params)
		resolve &Resolv.create_process/2
	end

	field :update_process, non_null(:process_response) do
		arg :process, non_null(:process_update_params)
		resolve &Resolv.update_process/2
	end

	field :delete_process, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_process/2
	end
end
end
