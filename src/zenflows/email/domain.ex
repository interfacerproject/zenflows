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

defmodule Zenflows.Email.Domain do
@moduledoc false

alias Zenflows.DB.{ID, Repo}
alias Zenflows.Restroom
alias Zenflows.VF.Person
alias Zenflows.Email

@spec request_email_verification(Person.t(), String.t()) :: :ok | {:error, term()}
def request_email_verification(person, url) do
	Repo.multi(fn ->
		with {:ok, token} <- token_new(:email_verification, person),
				subj = "Zenflows - Verify your email address",
				body = "Visit to verify your email address: #{url <> token}",
				{:ok, _} <- Email.request(person.email, subj, body) do
			:ok
		end
	end)
end

@spec verify_email_verification(Person.t(), String.t()) :: :ok | :error
def verify_email_verification(person, token) do
	case token_validate(person, token) do
		{:ok, :email_verification} -> :ok
		_ -> :error
	end
end

@type token_type() :: :email_verification

@spec token_encode_type(token_type()) :: {:ok, binary()} | :error
defp token_encode_type(:email_verification), do: {:ok, <<1>>}
defp token_encode_type(_), do: :error

@spec token_decode_type(binary()) :: {:ok, token_type()} | :error
defp token_decode_type(<<1>>), do: {:ok, :email_verification}
defp token_decode_type(_), do: :error

# Generate a validation code, a token, that is used for emails.
@spec token_new(token_type(), Person.t()) :: {:ok, binary()} | {:error, term()}
def token_new(type, person) do
	with {:ok, t} <- token_encode_type(type),
			{:ok, id} = ID.dump(person.id),
			ts = DateTime.utc_now() |> DateTime.to_unix() |> :binary.encode_unsigned(),
			data_raw = t <> id <> ts,
			{:ok, hash} <- data_raw |> Base.encode64() |> Restroom.hmac_new(),
			# if this fails, zenroom or the zenscript has an issue:
			{:ok, hash_raw} <- Base.decode64(hash) do
		{:ok, Base.url_encode64(hash_raw <> data_raw, padding: false)}
	else
		# for token_encode_type/1
		:error -> {:error, "bad type"}
		# for everything else
		{:error, reason} -> {:error, reason}
	end
end

# Validate the authencity of a token.
@spec token_validate(Person.t(), String.t()) :: {:ok, token_type()} | :error
def token_validate(person, tok) do
	Repo.multi(fn ->
		with {:ok, tok_raw} <- Base.url_decode64(tok, padding: false),
				<<hash_raw::binary-32, data_raw::binary>> <- tok_raw,
				hash = Base.encode64(hash_raw),
				data = Base.encode64(data_raw),
				:ok <- Restroom.hmac_verify(data, hash),
				<<type_raw::binary-1, id_raw::binary-16, ts_raw::binary>> = data_raw,
				{:ok, type} <- token_decode_type(type_raw),
				{:ok, ts} <- ts_raw |> :binary.decode_unsigned() |> DateTime.from_unix(),
				valid_until = DateTime.add(DateTime.utc_now(), expiry(), :second),
				:lt <- DateTime.compare(ts, valid_until),
				{:ok, id} <- ID.cast(id_raw),
				true <- person.id == id do
			# TODO: this needs to deal with in case if user changes email after
			# this token was given in order to prevent verifying a fake email address.
			# We're not doing that right now, since we don't
			# allow users to change email yet.
			{:ok, type}
		else
			_ -> :error
		end
	end)
end

# Returns the expiry time in seconds of a token.
@spec expiry() :: non_neg_integer()
defp expiry() do
	Keyword.fetch!(conf(), :expiry)
end

# Return the application configurations of the Zenflows.Email module«
# only used for `expiry/0`.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, Zenflows.Email)
end
end
