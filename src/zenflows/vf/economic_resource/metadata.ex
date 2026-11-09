# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule Zenflows.VF.EconomicResource.Metadata do
@moduledoc """
Content fingerprint for metadata compare-and-set (not a revision counter).
Object-key order is irrelevant; arrays retain order. A return to identical
content has the same token. This token is not an authorization credential.
"""

@spec hash(map() | nil) :: String.t()
def hash(value) do
	value
	|> canonical()
	|> Jason.encode!()
	|> then(&:crypto.hash(:sha256, &1))
	|> Base.encode16(case: :lower)
end

@doc "Validate/normalize JSON fields, then compare and merge the locked current map."
def merge(current, fields, opts) do
	with {:ok, fields} <- normalize(fields),
			:ok <- precondition(current, opts) do
		if is_nil(current) or is_map(current),
			do: {:ok, Map.merge(current || %{}, fields)},
			else: {:error, :invalid_metadata_patch}
	end
end

def changed_fields(before, after_map) do
	after_map
	|> Enum.filter(fn {key, value} -> not Map.has_key?(before || %{}, key) or Map.get(before || %{}, key) != value end)
	|> Enum.map(&elem(&1, 0))
	|> Enum.sort()
end

defp normalize(fields) when is_map(fields) and not is_struct(fields) do
	case Jason.encode(fields) do
		{:ok, json} -> Jason.decode(json)
		_ -> {:error, :invalid_metadata_patch}
	end
rescue
	_ -> {:error, :invalid_metadata_patch}
end
defp normalize(_), do: {:error, :invalid_metadata_patch}

defp precondition(current, opts) do
	if Keyword.keyword?(opts) do
		case Keyword.fetch(opts, :expected_metadata_hash) do
			:error -> :ok
			{:ok, expected} when is_binary(expected) ->
				if expected == hash(current), do: :ok, else: {:error, :conflict}
			_ -> {:error, :invalid_metadata_patch}
		end
	else
		{:error, :invalid_metadata_patch}
	end
end

defp canonical(value) when is_map(value) do
	value
	|> Enum.sort_by(fn {key, _} -> to_string(key) end)
	|> Enum.map(fn {key, val} -> {to_string(key), canonical(val)} end)
	|> Jason.OrderedObject.new()
end
defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
defp canonical(value), do: value
end
