defmodule ZenflowsTest.Valflow.Validate do
use ExUnit.Case, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.Validate

@spec name_chset(map()) :: Changeset.t()
defp name_chset(changes) do
	Changeset.change({%{}, %{name: :string}}, changes)
end

@spec note_chset(map()) :: Changeset.t()
defp note_chset(changes) do
	Changeset.change({%{}, %{note: :string}}, changes)
end

@spec uri_chset(map()) :: Changeset.t()
defp uri_chset(changes) do
	Changeset.change({%{}, %{uri: :string}}, changes)
end

@spec class_chset(map()) :: Changeset.t()
defp class_chset(changes) do
	Changeset.change({%{}, %{list: {:array, :string}}}, changes)
end

describe "name/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{name: "a"}
			|> name_chset()
			|> Validate.name(:name)

		assert {:ok, _} = Keyword.fetch(errs, :name)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{name: String.duplicate("a", 256 + 1)}
			|> name_chset()
			|> Validate.name(:name)

		assert {:ok, _} = Keyword.fetch(errs, :name)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{name: "aa"}
			|> name_chset()
			|> Validate.name(:name)

		assert :error = Keyword.fetch(errs, :name)
	end
end

describe "note/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{note: "a"}
			|> note_chset()
			|> Validate.note(:note)

		assert {:ok, _} = Keyword.fetch(errs, :note)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{note: String.duplicate("a", 2048 + 1)}
			|> note_chset()
			|> Validate.note(:note)

		assert {:ok, _} = Keyword.fetch(errs, :note)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{note: "aa"}
			|> note_chset()
			|> Validate.note(:note)

		assert :error = Keyword.fetch(errs, :note)
	end
end

describe "uri/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{uri: "aa"}
			|> uri_chset()
			|> Validate.uri(:uri)

		assert {:ok, _} = Keyword.fetch(errs, :uri)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{uri: String.duplicate("a", 512 + 1)}
			|> uri_chset()
			|> Validate.uri(:uri)

		assert {:ok, _} = Keyword.fetch(errs, :uri)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{uri: "https://example.test/example.jpg"}
			|> uri_chset()
			|> Validate.uri(:uri)

		assert :error = Keyword.fetch(errs, :uri)
	end
end

describe "class/2" do
	test "with too few items" do
		assert %Changeset{errors: errs} =
			%{list: []}
			|> class_chset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with too many items" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..127 + 1, &("uri #{&1}"))}
			|> class_chset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with one of the items too short" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..64, &("uri #{&1}")) ++ ["aa"]}
			|> class_chset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with one of the items too long" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..64, &("uri #{&1}")) ++ [String.duplicate("a", 513)]}
			|> class_chset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with everthing just right" do
		assert %Changeset{errors: errs} =
			%{list: ["aaa"]}
			|> class_chset()
			|> Validate.class(:list)

		assert :error = Keyword.fetch(errs, :list)
	end
end
end
