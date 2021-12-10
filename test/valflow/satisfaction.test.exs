defmodule ZenflowsTest.Valflow.Satisfaction do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Satisfaction

setup do
	%{params: %{
		satisfied_by_id: Factory.insert!(:event_or_commitment).id,
		satisfies_id: Factory.insert!(:intent).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		note: Factory.uniq("note"),
	}}
end

test "create Satisfaction", %{params: params} do
	assert {:ok, %Satisfaction{} = satis} =
		params
		|> Satisfaction.chset()
		|> Repo.insert()

	assert satis.satisfied_by_id == params.satisfied_by_id
	assert satis.satisfies_id == params.satisfies_id
	assert satis.resource_quantity_id == params.resource_quantity_id
	assert satis.effort_quantity_id == params.effort_quantity_id
	assert satis.note == params.note
end

test "update Satisfaction", %{params: params} do
	assert {:ok, %Satisfaction{} = satis} =
		:satisfaction
		|> Factory.insert!()
		|> Satisfaction.chset(params)
		|> Repo.update()

	assert satis.satisfied_by_id == params.satisfied_by_id
	assert satis.satisfies_id == params.satisfies_id
	assert satis.resource_quantity_id == params.resource_quantity_id
	assert satis.effort_quantity_id == params.effort_quantity_id
	assert satis.note == params.note
end
end
