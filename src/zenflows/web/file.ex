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

defmodule Zenflows.Web.File do
@moduledoc """
Plug router that deals with file uploads and downloads (serve).
"""

use Plug.Router

alias Ecto.Multi
alias Plug.{Conn, Conn.Utils}
alias Zenflows.DB.Repo
alias Zenflows.{File, Restroom}

plug :match
plug :dispatch

post "/" do
	with :ok <- check_content_type(conn),
			{:ok, conn, hash} <- fetch_hash(conn) do
		Multi.new()
		|> Multi.put(:hash, hash)
		|> Multi.run(:one, &File.Domain.one/2)
		|> Multi.run(:check, fn _, %{one: %{size: size, hash: hash}} ->
			{conn, bin} = read_multipart_body(conn, size)
			with ^size <- byte_size(bin),
					{:ok, hash_left} <- Base.url_decode64(hash, padding: false),
					hash_right = :crypto.hash(:sha512, bin),
					true <- Restroom.byte_equal?(hash_left, hash_right) do
				{:ok, {conn, bin}}
			else _ ->
				{:error, conn}
			end
		end)
		|> Multi.update(:update, fn %{one: file, check: {_, bin}} ->
			Ecto.Changeset.change(file, bin: Base.encode64(bin))
		end)
		|> Repo.transaction()
		|> case do
			{:ok, %{check: {conn, _}}} -> send_resp(conn, 201, "Created")
			{:error, :one, _, _} -> send_resp(conn, 404, "Not Found")
			{:error, :check, conn, _} -> send_resp(conn, 422, "Unprocessable Content")
			{:error, :update, _, %{check: {conn, _}}} -> send_resp(conn, 501, "Internal Server Error")
		end
	end
end

get "/:hash" do
	hash = Map.fetch!(conn.path_params, "hash")
	case File.Domain.one(hash: hash) do
		{:ok, file} ->
			conn
			|> put_resp_content_type(file.mime_type)
			|> send_resp(200, file.bin)
		_ -> send_resp(conn, 404, "Not Found")
	end
end

match _ do
	send_resp(conn, 404, "Not Found")
end

@spec check_content_type(Conn.t()) :: :ok | Conn.t() | no_return()
defp check_content_type(conn) do
	with [hdr] <- get_req_header(conn, "content-type"),
			{:ok, "multipart", "form-data", %{}} <- Utils.content_type(hdr) do
		:ok
	else _ ->
		send_resp(conn, 415, "Unsupported Media Type")
	end
end

@spec fetch_hash(Conn.t()) :: {:ok, Conn.t(), String.t()} | Conn.t() | no_return()
defp fetch_hash(conn) do
	with {:ok, hdrs, conn} <- read_part_headers(conn),
		[val] <- for({"content-disposition", val} <- hdrs, do: val),
			%{"name" => hash} <- Utils.params(val) do
		{:ok, conn, hash}
	else _ ->
		send_resp(conn, 422, "Unprocessable Content")
	end
end

@spec read_multipart_body(Conn.t(), non_neg_integer()) :: {Conn.t(), binary()}
defp read_multipart_body(conn, size) do
	read_multipart_body(conn, size, "")
end

@spec read_multipart_body(Conn.t(), non_neg_integer(), binary())
	:: {Conn.t(), binary()}
defp read_multipart_body(conn, size, acc) do
	case read_part_body(conn, length: size, read_length: size) do
		{:ok, body, conn} -> {conn, body}
		{:more, read, conn} -> read_multipart_body(conn, size, <<acc::binary, read::binary>>)
		{:done, conn} -> {conn, acc}
	end
end
end
