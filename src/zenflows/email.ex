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

defmodule Zenflows.Email do
@moduledoc """
A module to interact with the SendGrid API.
"""

alias Zenflows.HTTPC

def child_spec(_) do
	Supervisor.child_spec(
		{Zenflows.HTTPC,
			name: __MODULE__,
			scheme: :https,
			host: "api.sendgrid.com",
			port: 443,
		},
		id: __MODULE__)
end

@doc """
Send an email using the SendGrid API.

* `email_to` is the email address of the receiver,
* `subject` is the subject of the email message,
* `body` is the body of the email message.

Returns `:ok` when the message is sent.
"""
@spec request(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
def request(email_to, subject, body) do
	hdrs = [
		{"content-type", "application/json"},
		{"authorization", "bearer #{api_key()}"},
	]
	data = %{
		personalizations: [%{to: [%{email: email_to}]}],
		from: %{email: email_from()},
		subject: subject,
		content: [%{type: "text/plain", value: body}],
	}
	with {:ok, post_body} <- Jason.encode(data),
			{:ok, %{status: stat, data: body}} <-
				HTTPC.request(__MODULE__, "POST", "/v3/mail/send", hdrs, post_body) do
		# sendgrid reponses with an empty body, 202 is the
		# only way to see if we're successful.
		if stat == 202 do
			:ok
		else
			{:error, body}
		end
	end
end

# Return the SendGrid API key from the configs.
@spec api_key() :: String.t()
defp api_key() do
	Keyword.fetch!(conf(), :api_key)
end

# Return the email address from the configs, that is used for "From:"
# in emails.
@spec email_from() :: String.t()
defp email_from() do
	Keyword.fetch!(conf(), :email_from)
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
