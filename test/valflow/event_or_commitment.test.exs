defmodule ZenflowsTest.Valflow.EventOrCommitment do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.EventOrCommitment

setup do
	%{params: %{
		event_id: Factory.insert!(:economic_event).id,
		commitment_id: Factory.insert!(:commitment).id,
	}}
end

describe "create EventOrCommitment" do
	test "with both event and commitment", %{params: params} do
		assert {:error, %Changeset{errors: errs}} =
			params
			|> EventOrCommitment.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :event_id)
		assert {:ok, _} = Keyword.fetch(errs, :commitment_id)
	end

	test "with only event", %{params: params} do
		assert {:ok, %EventOrCommitment{} = evt_comm} =
			params
			|> Map.delete(:commitment_id)
			|> EventOrCommitment.chset()
			|> Repo.insert()

		assert evt_comm.event_id == params.event_id
		assert evt_comm.commitment_id == nil
	end

	test "with only commitment", %{params: params} do
		assert {:ok, %EventOrCommitment{} = evt_comm} =
			params
			|> Map.delete(:event_id)
			|> EventOrCommitment.chset()
			|> Repo.insert()

		assert evt_comm.event_id == nil
		assert evt_comm.commitment_id == params.commitment_id
	end
end

describe "update EventOrCommitment" do
	test "with both event and commitment", %{params: params} do
		assert {:error, %Changeset{errors: errs}} =
			:event_or_commitment
			|> Factory.insert!(event: Factory.build(:economic_event), commitment: nil)
			|> EventOrCommitment.chset(params)
			|> Repo.update()

		assert {:ok, _} = Keyword.fetch(errs, :commitment_id)

		assert {:error, %Changeset{errors: errs}} =
			:event_or_commitment
			|> Factory.insert!(event: nil, commitment: Factory.build(:commitment))
			|> EventOrCommitment.chset(params)
			|> Repo.update()

		assert {:ok, _} = Keyword.fetch(errs, :event_id)
	end

	test "with only event", %{params: params} do
		assert {:ok, %EventOrCommitment{} = evt_comm} =
			:event_or_commitment
			|> Factory.insert!(event: Factory.build(:economic_event), commitment: nil)
			|> EventOrCommitment.chset(
				Map.delete(params, :commitment_id)
			)
			|> Repo.update()

		assert evt_comm.event_id == params.event_id
		assert evt_comm.commitment_id == nil
	end

	test "with only commitment", %{params: params} do
		assert {:ok, %EventOrCommitment{} = evt_comm} =
			:event_or_commitment
			|> Factory.insert!(event: nil, commitment: Factory.build(:commitment))
			|> EventOrCommitment.chset(
				Map.delete(params, :event_id)
			)
			|> Repo.update()

		assert evt_comm.event_id == nil
		assert evt_comm.commitment_id == params.commitment_id
	end
end
end
