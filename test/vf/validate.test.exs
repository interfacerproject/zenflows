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

defmodule ZenflowsTest.VF.Validate do
use ExUnit.Case, async: true

alias Ecto.Changeset
alias Zenflows.VF.Validate

@spec key_chgset(map()) :: Changeset.t()
defp key_chgset(changes) do
	Changeset.change({%{}, %{key: :string}}, changes)
end

@spec name_chgset(map()) :: Changeset.t()
defp name_chgset(changes) do
	Changeset.change({%{}, %{name: :string}}, changes)
end

@spec note_chgset(map()) :: Changeset.t()
defp note_chgset(changes) do
	Changeset.change({%{}, %{note: :string}}, changes)
end

@spec img_chgset(map()) :: Changeset.t()
defp img_chgset(changes) do
	Changeset.change({%{}, %{img: :string}}, changes)
end

@spec uri_chgset(map()) :: Changeset.t()
defp uri_chgset(changes) do
	Changeset.change({%{}, %{uri: :string}}, changes)
end

@spec class_chgset(map()) :: Changeset.t()
defp class_chgset(changes) do
	Changeset.change({%{}, %{list: {:array, :string}}}, changes)
end

describe "key/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{key: String.duplicate("a", 15)}
			|> key_chgset()
			|> Validate.key(:key)

		assert {:ok, _} = Keyword.fetch(errs, :key)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{key: String.duplicate("a", 2048 + 1)}
			|> key_chgset()
			|> Validate.key(:key)

		assert {:ok, _} = Keyword.fetch(errs, :key)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{key: String.duplicate("a", 16)}
			|> key_chgset()
			|> Validate.key(:key)

		assert :error = Keyword.fetch(errs, :key)
	end
end

describe "name/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{name: ""}
			|> name_chgset()
			|> Validate.name(:name)

		assert {:ok, _} = Keyword.fetch(errs, :name)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{name: String.duplicate("a", 256 + 1)}
			|> name_chgset()
			|> Validate.name(:name)

		assert {:ok, _} = Keyword.fetch(errs, :name)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{name: "aa"}
			|> name_chgset()
			|> Validate.name(:name)

		assert :error = Keyword.fetch(errs, :name)
	end
end

describe "note/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{note: ""}
			|> note_chgset()
			|> Validate.note(:note)

		assert {:ok, _} = Keyword.fetch(errs, :note)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{note: String.duplicate("a", 2048 + 1)}
			|> note_chgset()
			|> Validate.note(:note)

		assert {:ok, _} = Keyword.fetch(errs, :note)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{note: "aa"}
			|> note_chgset()
			|> Validate.note(:note)

		assert :error = Keyword.fetch(errs, :note)
	end
end

describe "img/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{img: ""}
			|> img_chgset()
			|> Validate.img(:img)

		assert {:ok, _} = Keyword.fetch(errs, :img)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{img: String.duplicate("a", 25 * 1024 * 1024 + 1)}
			|> img_chgset()
			|> Validate.img(:img)

		assert {:ok, _} = Keyword.fetch(errs, :img)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{img: String.duplicate("a", 1024)}
			|> img_chgset()
			|> Validate.img(:img)

		assert :error = Keyword.fetch(errs, :img)
	end
end

describe "uri/2" do
	test "with too short param" do
		assert %Changeset{errors: errs} =
			%{uri: ""}
			|> uri_chgset()
			|> Validate.uri(:uri)

		assert {:ok, _} = Keyword.fetch(errs, :uri)
	end

	test "with too long param" do
		assert %Changeset{errors: errs} =
			%{uri: String.duplicate("a", 512 + 1)}
			|> uri_chgset()
			|> Validate.uri(:uri)

		assert {:ok, _} = Keyword.fetch(errs, :uri)
	end

	test "with the right size param" do
		assert %Changeset{errors: errs} =
			%{uri: "https://example.test/example.jpg"}
			|> uri_chgset()
			|> Validate.uri(:uri)

		assert :error = Keyword.fetch(errs, :uri)
	end
end

describe "class/2" do
	test "with too few items" do
		assert %Changeset{errors: errs} =
			%{list: []}
			|> class_chgset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with too many items" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..127 + 1, &("uri #{&1}"))}
			|> class_chgset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with one of the items too short" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..64, &("uri #{&1}")) ++ [""]}
			|> class_chgset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with one of the items too long" do
		assert %Changeset{errors: errs} =
			%{list: Enum.map(0..64, &("uri #{&1}")) ++ [String.duplicate("a", 513)]}
			|> class_chgset()
			|> Validate.class(:list)

		assert {:ok, _} = Keyword.fetch(errs, :list)
	end

	test "with everthing just right" do
		assert %Changeset{errors: errs} =
			%{list: ["aaa"]}
			|> class_chgset()
			|> Validate.class(:list)

		assert :error = Keyword.fetch(errs, :list)
	end
end
end
