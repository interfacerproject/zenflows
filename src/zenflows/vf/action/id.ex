defmodule Zenflows.VF.Action.ID do
@moduledoc """
Custom Ecto type for Action ID definitions in schemas.
"""

use Ecto.Type

@type t() :: String.t()

@spec values() :: [t(), ...]
def values() do
	~w[
		produce use consume cite work
		pickup dropoff accept modify
		combine separate move transfer
		transferAllRights
		transferCustody
		raise lower
	]
end

@impl true
def type(), do: :string

@impl true
def cast("produce" = x),             do: {:ok, x}
def cast("use" = x),                 do: {:ok, x}
def cast("consume" = x),             do: {:ok, x}
def cast("cite" = x),                do: {:ok, x}
def cast("work" = x),                do: {:ok, x}
def cast("deliverService" = x),      do: {:ok, x}
def cast("deliver-service"),         do: {:ok, "deliverService"}
def cast("pickup" = x),              do: {:ok, x}
def cast("dropoff" = x),             do: {:ok, x}
def cast("accept" = x),              do: {:ok, x}
def cast("modify" = x),              do: {:ok, x}
def cast("combine" = x),             do: {:ok, x}
def cast("separate" = x),            do: {:ok, x}
def cast("transfer" = x),            do: {:ok, x}
def cast("move" = x),                do: {:ok, x}
def cast("raise" = x),               do: {:ok, x}
def cast("lower" = x),               do: {:ok, x}
def cast("transferAllRights" = x),   do: {:ok, x}
def cast("transferCustody" = x),     do: {:ok, x}
def cast("transfer-all-rights"),     do: {:ok, "transferAllRights"}
def cast("transfer-custody"),        do: {:ok, "transferCustody"}
def cast(x), do: {:error, message: "unknown action id #{inspect(x)}"}

@impl true
def dump(x), do: cast(x)

@impl true
def load(x), do: cast(x)
end
