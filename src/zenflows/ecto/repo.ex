defmodule Zenflows.Ecto.Repo do
@moduledoc "The Ecto Repository of Zenflows."

use Ecto.Repo,
	otp_app: :zenflows,
	adapter: Ecto.Adapters.Postgres
end
